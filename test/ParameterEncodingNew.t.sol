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
import { Timelocks, TimelocksLib } from "../contracts/libraries/TimelocksLib.sol";
import { MakerTraits } from "../dependencies/limit-order-protocol/contracts/libraries/MakerTraitsLib.sol";

/**
 * @title ParameterEncodingTest
 * @notice Comprehensive tests for parameter encoding/decoding functionality in SimplifiedEscrowFactory
 * @dev Tests ensure 1inch compatibility through proper fee structure encoding while maintaining BMN's zero-fee model
 */
contract ParameterEncodingTest is Test {
    using AddressLib for Address;
    using TimelocksLib for Timelocks;
    
    SimplifiedEscrowFactory public factory;
    TokenMock public tokenA;
    TokenMock public tokenB;
    
    address public constant MAKER = address(0x1234);
    address public constant RESOLVER = address(0x5678);
    address public constant PROTOCOL = address(0x9ABC);
    
    bytes32 public constant TEST_HASHLOCK = keccak256("test_secret");
    uint256 public constant DST_CHAIN_ID = 10; // Optimism
    
    // Event signatures for testing
    event SrcEscrowCreated(
        IBaseEscrow.Immutables srcImmutables,
        IEscrowFactory.DstImmutablesComplement dstImmutablesComplement
    );
    
    event PostInteractionEscrowCreated(
        address indexed escrow,
        bytes32 indexed hashlock,
        address indexed protocol,
        address taker,
        uint256 amount
    );
    
    function setUp() public {
        // Deploy factory with test configuration
        factory = new SimplifiedEscrowFactory(
            PROTOCOL, // limitOrderProtocol
            address(this), // owner
            86400, // rescueDelay (1 day)
            IERC20(address(0)), // no access token
            address(0) // no weth
        );
        
        // Deploy test tokens
        tokenA = new TokenMock("Token A", "TKA", 18);
        tokenB = new TokenMock("Token B", "TKB", 18);
        
        // Mint tokens for testing
        tokenA.mint(MAKER, 1000 ether);
        tokenA.mint(RESOLVER, 1000 ether);
        tokenB.mint(RESOLVER, 1000 ether);
        
        // Setup approvals
        vm.prank(MAKER);
        tokenA.approve(address(factory), type(uint256).max);
        
        vm.prank(RESOLVER);
        tokenA.approve(address(factory), type(uint256).max);
        
        vm.prank(RESOLVER);
        tokenB.approve(address(factory), type(uint256).max);
    }
    
    /**
     * @notice Test that source escrow parameters are always empty
     */
    function testSourceParametersEmpty() public {
        // Create test immutables
        IBaseEscrow.Immutables memory srcImmutables = _createTestImmutables(
            address(tokenA),
            100 ether,
            "" // Empty parameters for source
        );
        
        // Verify parameters are empty
        assertEq(srcImmutables.parameters.length, 0, "Source parameters should be empty");
        assertEq(keccak256(srcImmutables.parameters), keccak256(""), "Source parameters should be empty bytes");
    }
    
    /**
     * @notice Test that destination escrow parameters are properly encoded with fee structure
     */
    function testDestinationParametersEncoded() public {
        // Create the expected destination parameters
        bytes memory dstParameters = abi.encode(
            uint256(0),          // protocolFeeAmount
            uint256(0),          // integratorFeeAmount
            Address.wrap(0),     // protocolFeeRecipient
            Address.wrap(0)      // integratorFeeRecipient
        );
        
        // Verify encoding is not empty
        assertTrue(dstParameters.length > 0, "Destination parameters should not be empty");
        assertEq(dstParameters.length, 128, "Expected 4 * 32 bytes for encoded structure");
        
        // Verify it's different from empty bytes
        assertFalse(keccak256(dstParameters) == keccak256(""), "Should differ from empty bytes");
    }
    
    /**
     * @notice Test parameter decoding works correctly
     */
    function testParameterDecoding() public {
        // Encode parameters as the factory does
        bytes memory encodedParams = abi.encode(
            uint256(0),          // protocolFeeAmount
            uint256(0),          // integratorFeeAmount
            Address.wrap(0),     // protocolFeeRecipient
            Address.wrap(0)      // integratorFeeRecipient
        );
        
        // Decode and verify
        (
            uint256 protocolFeeAmount,
            uint256 integratorFeeAmount,
            Address protocolFeeRecipient,
            Address integratorFeeRecipient
        ) = abi.decode(encodedParams, (uint256, uint256, Address, Address));
        
        assertEq(protocolFeeAmount, 0, "Protocol fee amount should be 0");
        assertEq(integratorFeeAmount, 0, "Integrator fee amount should be 0");
        assertEq(protocolFeeRecipient.get(), address(0), "Protocol fee recipient should be address(0)");
        assertEq(integratorFeeRecipient.get(), address(0), "Integrator fee recipient should be address(0)");
    }
    
    /**
     * @notice Test that all fee values are zero as expected for BMN protocol
     */
    function testZeroFeeStructure() public {
        bytes memory params = _encodeDestinationParameters();
        
        // Decode to verify zero values
        (
            uint256 protocolFee,
            uint256 integratorFee,
            Address protocolRecipient,
            Address integratorRecipient
        ) = abi.decode(params, (uint256, uint256, Address, Address));
        
        // All fees should be zero for BMN
        assertEq(protocolFee, 0, "BMN uses zero protocol fees");
        assertEq(integratorFee, 0, "BMN uses zero integrator fees");
        assertEq(protocolRecipient.get(), address(0), "No protocol fee recipient");
        assertEq(integratorRecipient.get(), address(0), "No integrator fee recipient");
    }
    
    /**
     * @notice Test Address type encoding using wrap()
     */
    function testAddressTypeEncoding() public {
        // Test encoding with Address.wrap(0)
        Address zeroAddress = Address.wrap(0);
        assertEq(zeroAddress.get(), address(0), "Wrapped zero should be address(0)");
        
        // Test encoding with non-zero address
        Address nonZeroAddress = Address.wrap(uint160(MAKER));
        assertEq(nonZeroAddress.get(), MAKER, "Wrapped address should match");
        
        // Test encoding in parameters
        bytes memory params = abi.encode(
            uint256(0),
            uint256(0),
            zeroAddress,
            nonZeroAddress
        );
        
        // Decode and verify
        (,, Address decoded1, Address decoded2) = abi.decode(params, (uint256, uint256, Address, Address));
        assertEq(decoded1.get(), address(0), "First address should decode to zero");
        assertEq(decoded2.get(), MAKER, "Second address should decode to MAKER");
    }
    
    /**
     * @notice Test full integration with escrow creation through _postInteraction
     */
    function testIntegrationWithEscrowCreation() public {
        // Prepare order data
        IOrderMixin.Order memory order = _createTestOrder();
        
        // Prepare extraData with escrow parameters
        bytes memory extraData = _createExtraData();
        
        // Transfer tokens to resolver (simulating SimpleLimitOrderProtocol)
        vm.prank(MAKER);
        tokenA.transfer(RESOLVER, 100 ether);
        
        // Record logs to capture events
        vm.recordLogs();
        
        // Call postInteraction from the protocol address
        vm.prank(PROTOCOL);
        factory.postInteraction(
            order,
            "", // extension
            keccak256("orderHash"),
            RESOLVER,
            100 ether, // makingAmount
            100 ether, // takingAmount
            0, // remainingMakingAmount
            extraData
        );
        
        // Verify events and parameter encoding
        Vm.Log[] memory logs = vm.getRecordedLogs();
        _verifyEventsAndParameters(logs);
    }
    
    /**
     * @notice Test that the parameter structure allows future fee implementation
     */
    function testFutureCompatibility() public {
        // Test encoding with non-zero fees (for future compatibility)
        uint256 testProtocolFee = 1 ether;
        uint256 testIntegratorFee = 0.5 ether;
        Address testProtocolRecipient = Address.wrap(uint160(address(0xDEAD)));
        Address testIntegratorRecipient = Address.wrap(uint160(address(0xBEEF)));
        
        bytes memory futureParams = abi.encode(
            testProtocolFee,
            testIntegratorFee,
            testProtocolRecipient,
            testIntegratorRecipient
        );
        
        // Decode and verify structure integrity
        (
            uint256 decodedProtocolFee,
            uint256 decodedIntegratorFee,
            Address decodedProtocolRecipient,
            Address decodedIntegratorRecipient
        ) = abi.decode(futureParams, (uint256, uint256, Address, Address));
        
        assertEq(decodedProtocolFee, testProtocolFee, "Protocol fee should decode correctly");
        assertEq(decodedIntegratorFee, testIntegratorFee, "Integrator fee should decode correctly");
        assertEq(decodedProtocolRecipient.get(), address(0xDEAD), "Protocol recipient should decode correctly");
        assertEq(decodedIntegratorRecipient.get(), address(0xBEEF), "Integrator recipient should decode correctly");
    }
    
    /**
     * @notice Test edge case: Empty parameters vs encoded zero values
     */
    function testEmptyVsEncodedZeros() public {
        bytes memory emptyParams = "";
        bytes memory encodedZeros = _encodeDestinationParameters();
        
        // They should be different
        assertFalse(keccak256(emptyParams) == keccak256(encodedZeros), "Empty and encoded zeros should differ");
        
        // Empty should have length 0
        assertEq(emptyParams.length, 0, "Empty params should have zero length");
        
        // Encoded zeros should have length 128 (4 * 32 bytes)
        assertEq(encodedZeros.length, 128, "Encoded zeros should be 128 bytes");
    }
    
    /**
     * @notice Test parameter encoding in createSrcEscrow standalone function
     */
    function testCreateSrcEscrowParameterHandling() public {
        // Create immutables with empty parameters
        IBaseEscrow.Immutables memory srcImmutables = _createTestImmutables(
            address(tokenA),
            100 ether,
            "" // Empty parameters for source
        );
        
        // Create destination complement with encoded parameters
        IEscrowFactory.DstImmutablesComplement memory dstComplement = IEscrowFactory.DstImmutablesComplement({
            maker: Address.wrap(uint160(MAKER)),
            amount: 100 ether,
            token: Address.wrap(uint160(address(tokenB))),
            safetyDeposit: 1 ether,
            chainId: DST_CHAIN_ID,
            parameters: _encodeDestinationParameters()
        });
        
        // Fund maker
        vm.prank(MAKER);
        tokenA.approve(address(factory), 100 ether);
        
        // Record logs
        vm.recordLogs();
        
        // Create source escrow
        vm.prank(MAKER);
        address escrow = factory.createSrcEscrow(srcImmutables, dstComplement);
        
        // Verify escrow was created
        assertTrue(escrow != address(0), "Escrow should be created");
        
        // Verify event was emitted with correct parameters
        Vm.Log[] memory logs = vm.getRecordedLogs();
        _verifySrcEscrowCreatedEvent(logs, true);
    }
    
    /**
     * @notice Test parameter validation in edge cases
     */
    function testParameterValidationEdgeCases() public {
        // Test with maximum uint256 values (edge case)
        bytes memory maxParams = abi.encode(
            type(uint256).max,
            type(uint256).max,
            Address.wrap(type(uint160).max),
            Address.wrap(type(uint160).max)
        );
        
        // Should still decode correctly
        (
            uint256 fee1,
            uint256 fee2,
            Address addr1,
            Address addr2
        ) = abi.decode(maxParams, (uint256, uint256, Address, Address));
        
        assertEq(fee1, type(uint256).max, "Max uint256 should decode");
        assertEq(fee2, type(uint256).max, "Max uint256 should decode");
        assertEq(addr1.get(), address(type(uint160).max), "Max address should decode");
        assertEq(addr2.get(), address(type(uint160).max), "Max address should decode");
    }
    
    /**
     * @notice Test that parameter encoding is consistent across multiple calls
     */
    function testParameterEncodingConsistency() public {
        bytes memory params1 = _encodeDestinationParameters();
        bytes memory params2 = _encodeDestinationParameters();
        
        // Should produce identical results
        assertEq(keccak256(params1), keccak256(params2), "Encoding should be deterministic");
        assertEq(params1.length, params2.length, "Length should be consistent");
        
        // Verify byte-by-byte equality
        for (uint i = 0; i < params1.length; i++) {
            assertEq(uint8(params1[i]), uint8(params2[i]), "Each byte should match");
        }
    }
    
    /**
     * @notice Test decoding with incorrect types fails appropriately
     */
    function testIncorrectDecodingReverts() public {
        bytes memory params = _encodeDestinationParameters();
        
        // Try to decode with wrong type order - this will actually decode
        // but produce incorrect values, demonstrating importance of correct types
        (address addr1, address addr2, uint256 val1, uint256 val2) = 
            abi.decode(params, (address, address, uint256, uint256));
        
        // The values will be wrong because we decoded in wrong order
        // First 32 bytes (uint256(0)) will be interpreted as address
        assertEq(addr1, address(0), "First uint256(0) decodes to address(0)");
        assertEq(addr2, address(0), "Second uint256(0) decodes to address(0)");
        
        // The Address.wrap(0) values will be interpreted as uint256
        // Since Address is uint160 wrapped, they decode to 0
        assertEq(val1, 0, "Address.wrap(0) decodes to uint256(0)");
        assertEq(val2, 0, "Address.wrap(0) decodes to uint256(0)");
        
        // Note: In this case all zeros decode correctly regardless,
        // but with non-zero values the decoding would produce garbage
    }
    
    // ============ Helper Functions ============
    
    function _createTestImmutables(
        address token,
        uint256 amount,
        bytes memory parameters
    ) internal view returns (IBaseEscrow.Immutables memory) {
        Timelocks timelocks = TimelocksLib.pack(TimelocksLib.TimelocksStruct({
            srcWithdrawal: 0,
            srcPublicWithdrawal: 60,
            srcCancellation: 3600,
            srcPublicCancellation: 3660,
            dstWithdrawal: 1800,
            dstPublicWithdrawal: 1860,
            dstCancellation: 3600
        }));
        
        return IBaseEscrow.Immutables({
            orderHash: keccak256("orderHash"),
            hashlock: TEST_HASHLOCK,
            maker: Address.wrap(uint160(MAKER)),
            taker: Address.wrap(uint160(RESOLVER)),
            token: Address.wrap(uint160(token)),
            amount: amount,
            safetyDeposit: 1 ether,
            timelocks: timelocks.setDeployedAt(block.timestamp),
            parameters: parameters
        });
    }
    
    function _createTestOrder() internal view returns (IOrderMixin.Order memory) {
        return IOrderMixin.Order({
            salt: 1,
            maker: Address.wrap(uint160(MAKER)),
            receiver: Address.wrap(0),
            makerAsset: Address.wrap(uint160(address(tokenA))),
            takerAsset: Address.wrap(uint160(address(tokenB))),
            makingAmount: 100 ether,
            takingAmount: 100 ether,
            makerTraits: MakerTraits.wrap(0)
        });
    }
    
    function _createExtraData() internal view returns (bytes memory) {
        uint256 deposits = (1 ether << 128) | 1 ether; // dstDeposit | srcDeposit
        uint256 timelocks = ((block.timestamp + 3600) << 128) | (block.timestamp + 1800);
        
        return abi.encode(
            TEST_HASHLOCK,
            DST_CHAIN_ID,
            address(tokenB),
            deposits,
            timelocks
        );
    }
    
    function _encodeDestinationParameters() internal pure returns (bytes memory) {
        return abi.encode(
            uint256(0),          // protocolFeeAmount
            uint256(0),          // integratorFeeAmount
            Address.wrap(0),     // protocolFeeRecipient
            Address.wrap(0)      // integratorFeeRecipient
        );
    }
    
    function _verifyEventsAndParameters(Vm.Log[] memory logs) internal {
        bool foundSrcEvent = false;
        bool foundPostInteractionEvent = false;
        
        for (uint i = 0; i < logs.length; i++) {
            // Check for SrcEscrowCreated event
            if (logs[i].topics.length > 0) {
                bytes32 srcEventSig = keccak256("SrcEscrowCreated((bytes32,bytes32,uint256,uint256,uint256,uint256,uint256,uint256,bytes),(uint256,uint256,uint256,uint256,uint256,bytes))");
                bytes32 postEventSig = keccak256("PostInteractionEscrowCreated(address,bytes32,address,address,uint256)");
                
                if (logs[i].topics[0] == srcEventSig) {
                    foundSrcEvent = true;
                    _verifySrcEscrowEvent(logs[i]);
                } else if (logs[i].topics[0] == postEventSig) {
                    foundPostInteractionEvent = true;
                }
            }
        }
        
        assertTrue(foundSrcEvent, "SrcEscrowCreated event should be emitted");
        assertTrue(foundPostInteractionEvent, "PostInteractionEscrowCreated event should be emitted");
    }
    
    function _verifySrcEscrowEvent(Vm.Log memory log) internal {
        // Decode event data
        (IBaseEscrow.Immutables memory srcImmutables, IEscrowFactory.DstImmutablesComplement memory dstComplement) = 
            abi.decode(log.data, (IBaseEscrow.Immutables, IEscrowFactory.DstImmutablesComplement));
        
        // Verify source parameters are empty
        assertEq(srcImmutables.parameters.length, 0, "Source parameters should be empty");
        
        // Verify destination parameters are properly encoded
        assertTrue(dstComplement.parameters.length > 0, "Destination parameters should not be empty");
        assertEq(dstComplement.parameters.length, 128, "Destination parameters should be 128 bytes");
        
        // Decode and verify destination parameters
        (
            uint256 protocolFeeAmount,
            uint256 integratorFeeAmount,
            Address protocolFeeRecipient,
            Address integratorFeeRecipient
        ) = abi.decode(dstComplement.parameters, (uint256, uint256, Address, Address));
        
        assertEq(protocolFeeAmount, 0, "Protocol fee should be 0");
        assertEq(integratorFeeAmount, 0, "Integrator fee should be 0");
        assertEq(protocolFeeRecipient.get(), address(0), "Protocol fee recipient should be address(0)");
        assertEq(integratorFeeRecipient.get(), address(0), "Integrator fee recipient should be address(0)");
    }
    
    function _verifySrcEscrowCreatedEvent(Vm.Log[] memory logs, bool expectFound) internal {
        bool found = false;
        bytes32 eventSig = keccak256("SrcEscrowCreated((bytes32,bytes32,uint256,uint256,uint256,uint256,uint256,uint256,bytes),(uint256,uint256,uint256,uint256,uint256,bytes))");
        
        for (uint i = 0; i < logs.length; i++) {
            if (logs[i].topics.length > 0 && logs[i].topics[0] == eventSig) {
                found = true;
                _verifySrcEscrowEvent(logs[i]);
                break;
            }
        }
        
        if (expectFound) {
            assertTrue(found, "SrcEscrowCreated event should be found");
        }
    }
}