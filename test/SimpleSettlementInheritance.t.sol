// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { Test } from "forge-std/Test.sol";
import { SimplifiedEscrowFactory } from "../contracts/SimplifiedEscrowFactory.sol";
import { TokenMock } from "../contracts/mocks/TokenMock.sol";
import { MockLimitOrderProtocol } from "./mocks/MockLimitOrderProtocol.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { IOrderMixin } from "../dependencies/limit-order-protocol/contracts/interfaces/IOrderMixin.sol";
import { MakerTraits } from "../dependencies/limit-order-protocol/contracts/libraries/MakerTraitsLib.sol";
import { Address, AddressLib } from "solidity-utils/contracts/libraries/AddressLib.sol";

contract SimpleSettlementInheritanceTest is Test {
    using AddressLib for Address;

    SimplifiedEscrowFactory factory;
    MockLimitOrderProtocol limitOrderProtocol;
    TokenMock srcToken;
    TokenMock dstToken;
    
    address constant ALICE = address(0xa11ce);
    address constant BOB = address(0xb0b);
    
    function setUp() public {
        // Deploy mock limit order protocol first
        limitOrderProtocol = new MockLimitOrderProtocol();
        
        // Deploy factory with SimpleSettlement inheritance
        factory = new SimplifiedEscrowFactory(
            address(limitOrderProtocol),  // limit order protocol
            address(this),  // owner
            7 days,         // rescueDelay
            IERC20(address(0)),  // no access token
            address(0)      // no WETH needed
        );
        
        // Deploy mock tokens
        srcToken = new TokenMock("Source Token", "SRC", 18);
        dstToken = new TokenMock("Destination Token", "DST", 18);
        
        // Mint tokens
        srcToken.mint(ALICE, 1000 ether);
        dstToken.mint(BOB, 1000 ether);
    }
    
    function testSimpleSettlementInheritance() public {
        // Verify factory inherits from SimpleSettlement
        // SimpleSettlement has the external postInteraction that calls internal _postInteraction
        
        // The factory should have the owner() function from Ownable (via SimpleSettlement)
        assertEq(factory.owner(), address(this), "Owner should be set correctly");
        
        // Verify the factory can be called via the postInteraction interface
        // This would normally be called by the limit order protocol
        
        // Prepare a mock order
        IOrderMixin.Order memory order = IOrderMixin.Order({
            salt: uint256(keccak256("test_order")),
            maker: Address.wrap(uint160(ALICE)),
            receiver: Address.wrap(uint160(address(0))),
            makerAsset: Address.wrap(uint160(address(srcToken))),
            takerAsset: Address.wrap(uint160(address(dstToken))),
            makingAmount: 100 ether,
            takingAmount: 50 ether,
            makerTraits: MakerTraits.wrap(0)
        });
        
        // Prepare extraData for postInteraction
        bytes32 hashlock = keccak256("test_secret");
        uint256 dstChainId = 137; // Polygon
        address dstTokenAddr = address(dstToken);
        uint256 deposits = (uint256(0.1 ether) << 128) | 0.05 ether; // dstDeposit | srcDeposit
        uint256 timelocks = (uint256(block.timestamp + 2 hours) << 128) | (block.timestamp + 1 hours);
        
        bytes memory extraData = abi.encode(
            hashlock,
            dstChainId,
            dstTokenAddr,
            deposits,
            timelocks
        );
        
        // Setup approvals and whitelist
        vm.prank(ALICE);
        srcToken.approve(address(factory), type(uint256).max);
        
        vm.prank(BOB);
        srcToken.approve(address(factory), type(uint256).max);
        
        // Add Bob as resolver
        factory.addResolver(BOB);
        
        // Transfer some tokens to Bob (resolver) to simulate limit order protocol transfer
        vm.prank(ALICE);
        srcToken.transfer(BOB, 100 ether);
        
        // Now test that postInteraction can be called (normally done by limit order protocol)
        // We'll simulate the limit order protocol calling postInteraction
        vm.prank(address(limitOrderProtocol));
        factory.postInteraction(
            order,
            "",  // extension
            keccak256("order_hash"),
            BOB,  // taker (resolver)
            100 ether,  // makingAmount
            50 ether,   // takingAmount
            0,          // remainingMakingAmount
            extraData
        );
        
        // Verify escrow was created
        assertTrue(factory.escrows(hashlock) != address(0), "Escrow should be created");
    }
    
    function testOnlyLimitOrderProtocolCanCallPostInteraction() public {
        // Prepare a mock order
        IOrderMixin.Order memory order = IOrderMixin.Order({
            salt: uint256(keccak256("test_order")),
            maker: Address.wrap(uint160(ALICE)),
            receiver: Address.wrap(uint160(address(0))),
            makerAsset: Address.wrap(uint160(address(srcToken))),
            takerAsset: Address.wrap(uint160(address(dstToken))),
            makingAmount: 100 ether,
            takingAmount: 50 ether,
            makerTraits: MakerTraits.wrap(0)
        });
        
        bytes32 hashlock = keccak256("test_secret");
        bytes memory extraData = abi.encode(
            hashlock,
            137,  // dstChainId
            address(dstToken),
            (uint256(0.1 ether) << 128) | 0.05 ether,
            (uint256(block.timestamp + 2 hours) << 128) | (block.timestamp + 1 hours)
        );
        
        // Attempt to call postInteraction from a non-protocol address should revert
        vm.expectRevert(abi.encodeWithSignature("OnlyLimitOrderProtocol()"));
        factory.postInteraction(
            order,
            "",
            keccak256("order_hash"),
            BOB,
            100 ether,
            50 ether,
            0,
            extraData
        );
    }
}