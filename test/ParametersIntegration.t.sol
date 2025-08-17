// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { Test, Vm } from "forge-std/Test.sol";
import { SimplifiedEscrowFactory } from "../contracts/SimplifiedEscrowFactory.sol";
import { IEscrowFactory } from "../contracts/interfaces/IEscrowFactory.sol";
import { IBaseEscrow } from "../contracts/interfaces/IBaseEscrow.sol";
import { TokenMock } from "../contracts/mocks/TokenMock.sol";
import { Address, AddressLib } from "solidity-utils/contracts/libraries/AddressLib.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { IOrderMixin } from "../dependencies/limit-order-protocol/contracts/interfaces/IOrderMixin.sol";
import { Timelocks } from "../contracts/libraries/TimelocksLib.sol";
import { MakerTraits } from "../dependencies/limit-order-protocol/contracts/libraries/MakerTraitsLib.sol";

/**
 * @title ParametersIntegrationTest
 * @notice Integration test to verify parameters encoding in actual _postInteraction flow
 */
contract ParametersIntegrationTest is Test {
    using AddressLib for Address;
    
    SimplifiedEscrowFactory public factory;
    TokenMock public token;
    address public maker = address(0x1234);
    address public resolver = address(0x5678);
    
    function setUp() public {
        // Deploy factory with minimal settings
        factory = new SimplifiedEscrowFactory(
            address(this), // limitOrderProtocol (this contract acts as it)
            address(this), // owner
            86400, // rescueDelay
            IERC20(address(0)), // no access token
            address(0) // no weth
        );
        
        // Deploy mock token
        token = new TokenMock("Test", "TST", 18);
        token.mint(maker, 1000 ether);
        token.mint(resolver, 1000 ether);
        
        // Setup approvals
        vm.prank(maker);
        token.approve(address(factory), type(uint256).max);
        vm.prank(resolver);
        token.approve(address(factory), type(uint256).max);
    }
    
    function testParametersEncodingInPostInteraction() public {
        // Create order data
        IOrderMixin.Order memory order = IOrderMixin.Order({
            salt: 1,
            maker: Address.wrap(uint160(maker)),
            receiver: Address.wrap(0),
            makerAsset: Address.wrap(uint160(address(token))),
            takerAsset: Address.wrap(uint160(address(token))),
            makingAmount: 100 ether,
            takingAmount: 100 ether,
            makerTraits: MakerTraits.wrap(0)
        });
        
        // Create extraData with escrow parameters
        bytes32 hashlock = keccak256("secret");
        uint256 dstChainId = 10; // Optimism
        address dstToken = address(token);
        uint256 deposits = (1 ether << 128) | 1 ether; // dstDeposit | srcDeposit
        uint256 timelocks = ((block.timestamp + 3600) << 128) | (block.timestamp + 1800); // srcCancellation | dstWithdrawal
        
        bytes memory extraData = abi.encode(
            hashlock,
            dstChainId,
            dstToken,
            deposits,
            timelocks
        );
        
        // Transfer tokens to resolver (simulating SimpleLimitOrderProtocol)
        vm.prank(maker);
        token.transfer(resolver, 100 ether);
        
        // Record logs to verify parameters encoding
        vm.recordLogs();
        
        // Call _postInteraction through the public interface
        // This simulates SimpleLimitOrderProtocol calling postInteraction
        // Note: postInteraction can only be called by the limit order protocol
        // In our test setup, this contract is the limit order protocol
        factory.postInteraction(
            order,
            "", // extension
            keccak256("orderHash"),
            resolver,
            100 ether,
            100 ether,
            0,
            extraData
        );
        
        // Get the logs
        Vm.Log[] memory logs = vm.getRecordedLogs();
        
        // Find the SrcEscrowCreated event
        bool foundEvent = false;
        assertTrue(logs.length > 0, "Should have emitted events");
        
        // Try with the correct event signature including types
        bytes32 expectedEventSig = keccak256("SrcEscrowCreated((bytes32,bytes32,uint256,uint256,uint256,uint256,uint256,uint256,bytes),(uint256,uint256,uint256,uint256,uint256,bytes))");
        
        for (uint i = 0; i < logs.length; i++) {
            // Check if this is the SrcEscrowCreated event (non-indexed event, so all data is in logs[i].data)
            // Since SrcEscrowCreated has no indexed parameters, topics[0] is the event signature
            if (logs[i].topics.length > 0 && logs[i].topics[0] == expectedEventSig) {
                foundEvent = true;
                
                // Decode the event data
                (IBaseEscrow.Immutables memory srcImmutables, IEscrowFactory.DstImmutablesComplement memory dstComplement) = 
                    abi.decode(logs[i].data, (IBaseEscrow.Immutables, IEscrowFactory.DstImmutablesComplement));
                
                // Verify source parameters are empty
                assertEq(srcImmutables.parameters.length, 0, "Source parameters should be empty");
                
                // Verify destination parameters are properly encoded
                assertTrue(dstComplement.parameters.length > 0, "Destination parameters should not be empty");
                
                // Decode the destination parameters to verify structure
                (
                    uint256 protocolFeeAmount,
                    uint256 integratorFeeAmount,
                    Address protocolFeeRecipient,
                    Address integratorFeeRecipient
                ) = abi.decode(dstComplement.parameters, (uint256, uint256, Address, Address));
                
                // Verify all values are zero as expected
                assertEq(protocolFeeAmount, 0, "Protocol fee should be 0");
                assertEq(integratorFeeAmount, 0, "Integrator fee should be 0");
                assertEq(protocolFeeRecipient.get(), address(0), "Protocol fee recipient should be address(0)");
                assertEq(integratorFeeRecipient.get(), address(0), "Integrator fee recipient should be address(0)");
                
                break;
            }
        }
        
        assertTrue(foundEvent, "SrcEscrowCreated event should be emitted");
    }
    
    function testDecodingDstParameters() public {
        // Create the encoded parameters as the factory would
        bytes memory dstParameters = abi.encode(
            uint256(0),  // protocolFeeAmount
            uint256(0),  // integratorFeeAmount
            Address.wrap(0),  // protocolFeeRecipient
            Address.wrap(0)   // integratorFeeRecipient
        );
        
        // Verify we can decode them properly
        (
            uint256 protocolFeeAmount,
            uint256 integratorFeeAmount,
            Address protocolFeeRecipient,
            Address integratorFeeRecipient
        ) = abi.decode(dstParameters, (uint256, uint256, Address, Address));
        
        assertEq(protocolFeeAmount, 0, "Protocol fee should be 0");
        assertEq(integratorFeeAmount, 0, "Integrator fee should be 0");
        assertEq(protocolFeeRecipient.get(), address(0), "Protocol fee recipient should be address(0)");
        assertEq(integratorFeeRecipient.get(), address(0), "Integrator fee recipient should be address(0)");
        
        // Verify it's different from empty bytes
        assertTrue(dstParameters.length > 0, "Encoded parameters should not be empty");
        assertFalse(keccak256(dstParameters) == keccak256(""), "Encoded parameters should differ from empty string");
    }
    
    // Minimal postInteraction function to make this contract act as SimpleLimitOrderProtocol
    function postInteraction(
        IOrderMixin.Order calldata order,
        bytes calldata extension,
        bytes32 orderHash,
        address taker,
        uint256 makingAmount,
        uint256 takingAmount,
        uint256 remainingMakingAmount,
        bytes calldata interactionData
    ) external {
        // Forward to factory's postInteraction
        factory.postInteraction(
            order,
            extension,
            orderHash,
            taker,
            makingAmount,
            takingAmount,
            remainingMakingAmount,
            interactionData
        );
    }
}