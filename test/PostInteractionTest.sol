// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Test.sol";
import "../contracts/SimplifiedEscrowFactory.sol";
import "./mocks/MockLimitOrderProtocol.sol";
import { BMNToken } from "../contracts/BMNToken.sol";
import "../contracts/mocks/TokenMock.sol";
import { IOrderMixin } from "../dependencies/limit-order-protocol/contracts/interfaces/IOrderMixin.sol";
import { Address } from "solidity-utils/contracts/libraries/AddressLib.sol";
import { MakerTraits } from "../dependencies/limit-order-protocol/contracts/libraries/MakerTraitsLib.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

/**
 * @title PostInteractionTest
 * @notice Tests specifically for the postInteraction integration
 */
contract PostInteractionTest is Test {
    SimplifiedEscrowFactory factory;
    MockLimitOrderProtocol limitOrderProtocol;
    BMNToken bmnToken;
    TokenMock otherToken;
    
    address alice = makeAddr("alice");
    address resolver = makeAddr("resolver");
    address owner = makeAddr("owner");
    
    bytes32 secret = keccak256("test_secret_123");
    bytes32 hashlock = keccak256(abi.encode(secret));
    
    uint256 constant SWAP_AMOUNT = 10e18;
    uint256 constant INITIAL_BALANCE = 1000e18;
    
    event PostInteractionEscrowCreated(
        address indexed escrow,
        bytes32 indexed hashlock,
        address indexed protocol,
        address taker,
        uint256 amount
    );
    
    function setUp() public {
        // Deploy tokens
        bmnToken = new BMNToken(address(this));
        otherToken = new TokenMock("Other Token", "OTHER", 18);
        
        // Deploy escrow implementations (using address(1) as placeholders since we won't use withdraw/cancel)
        factory = new SimplifiedEscrowFactory(
            address(1), // Placeholder src implementation
            address(1), // Placeholder dst implementation
            owner
        );
        
        // Deploy mock limit order protocol
        limitOrderProtocol = new MockLimitOrderProtocol();
        
        // Setup whitelist
        vm.startPrank(owner);
        factory.addResolver(resolver);
        vm.stopPrank();
        
        // Fund accounts
        bmnToken.transfer(alice, INITIAL_BALANCE);
        bmnToken.transfer(resolver, INITIAL_BALANCE);
        otherToken.mint(alice, INITIAL_BALANCE);
        otherToken.mint(resolver, INITIAL_BALANCE);
    }
    
    function testPostInteractionCreatesEscrow() public {
        // 1. Alice approves limit order protocol
        vm.startPrank(alice);
        bmnToken.approve(address(limitOrderProtocol), SWAP_AMOUNT);
        vm.stopPrank();
        
        // 2. Create Alice's order
        IOrderMixin.Order memory aliceOrder = IOrderMixin.Order({
            salt: 12345,
            maker: Address.wrap(uint160(alice)),
            receiver: Address.wrap(uint160(alice)),
            makerAsset: Address.wrap(uint160(address(bmnToken))),
            takerAsset: Address.wrap(uint160(address(otherToken))),
            makingAmount: SWAP_AMOUNT,
            takingAmount: SWAP_AMOUNT,
            makerTraits: MakerTraits.wrap(0)
        });
        
        // 3. Prepare extension data for escrow creation
        bytes memory extensionData = abi.encode(
            hashlock,
            1, // Destination chain ID
            address(otherToken),
            0, // No safety deposits
            (uint256(block.timestamp + 3600) << 128) | uint256(block.timestamp + 300)
        );
        
        // 4. Resolver fills Alice's order
        vm.startPrank(resolver);
        otherToken.approve(address(limitOrderProtocol), SWAP_AMOUNT);
        bmnToken.approve(address(factory), SWAP_AMOUNT); // Approve factory to pull tokens
        
        // Record balances before
        uint256 aliceBmnBefore = bmnToken.balanceOf(alice);
        uint256 resolverBmnBefore = bmnToken.balanceOf(resolver);
        
        // Fill the order with post-interaction
        limitOrderProtocol.fillOrderWithPostInteraction(
            aliceOrder,
            "",
            SWAP_AMOUNT,
            0,
            address(factory),
            extensionData
        );
        vm.stopPrank();
        
        // 5. Verify escrow was created
        address srcEscrow = factory.escrows(hashlock);
        assertNotEq(srcEscrow, address(0), "Source escrow should be created");
        
        // 6. Verify token transfers
        // - Alice's BMN went to resolver via limit order
        assertEq(bmnToken.balanceOf(alice), aliceBmnBefore - SWAP_AMOUNT, "Alice should have sent BMN");
        // - Resolver's BMN balance unchanged (received from Alice, sent to escrow)
        assertEq(bmnToken.balanceOf(resolver), resolverBmnBefore, "Resolver balance should be unchanged");
        // - Escrow has the BMN tokens
        assertEq(bmnToken.balanceOf(srcEscrow), SWAP_AMOUNT, "Escrow should have BMN tokens");
    }
    
    function testPostInteractionRequiresResolverApproval() public {
        // Setup order
        vm.startPrank(alice);
        bmnToken.approve(address(limitOrderProtocol), SWAP_AMOUNT);
        vm.stopPrank();
        
        IOrderMixin.Order memory order = IOrderMixin.Order({
            salt: 12345,
            maker: Address.wrap(uint160(alice)),
            receiver: Address.wrap(uint160(alice)),
            makerAsset: Address.wrap(uint160(address(bmnToken))),
            takerAsset: Address.wrap(uint160(address(otherToken))),
            makingAmount: SWAP_AMOUNT,
            takingAmount: SWAP_AMOUNT,
            makerTraits: MakerTraits.wrap(0)
        });
        
        bytes memory extensionData = abi.encode(hashlock, 1, address(otherToken), 0, 0);
        
        vm.startPrank(resolver);
        otherToken.approve(address(limitOrderProtocol), SWAP_AMOUNT);
        // NOT approving factory for BMN tokens
        
        // Should revert when factory tries to pull tokens from resolver
        vm.expectRevert();
        limitOrderProtocol.fillOrderWithPostInteraction(
            order,
            "",
            SWAP_AMOUNT,
            0,
            address(factory),
            extensionData
        );
        vm.stopPrank();
    }
    
    function testPostInteractionWithMultipleOrders() public {
        // Test that multiple orders with different hashlocks work correctly
        bytes32 hashlock1 = keccak256("secret1");
        bytes32 hashlock2 = keccak256("secret2");
        
        // Fund alice with extra tokens for second order
        bmnToken.transfer(alice, SWAP_AMOUNT);
        
        // Setup first order
        vm.startPrank(alice);
        bmnToken.approve(address(limitOrderProtocol), SWAP_AMOUNT * 2);
        vm.stopPrank();
        
        vm.startPrank(resolver);
        otherToken.approve(address(limitOrderProtocol), SWAP_AMOUNT * 2);
        bmnToken.approve(address(factory), SWAP_AMOUNT * 2);
        
        // Fill first order
        IOrderMixin.Order memory order1 = IOrderMixin.Order({
            salt: 1,
            maker: Address.wrap(uint160(alice)),
            receiver: Address.wrap(uint160(alice)),
            makerAsset: Address.wrap(uint160(address(bmnToken))),
            takerAsset: Address.wrap(uint160(address(otherToken))),
            makingAmount: SWAP_AMOUNT,
            takingAmount: SWAP_AMOUNT,
            makerTraits: MakerTraits.wrap(0)
        });
        
        bytes memory extensionData1 = abi.encode(
            hashlock1, 
            1, 
            address(otherToken), 
            0, // No safety deposits
            (uint256(block.timestamp + 3600) << 128) | uint256(block.timestamp + 300) // Proper timelocks
        );
        
        limitOrderProtocol.fillOrderWithPostInteraction(
            order1,
            "",
            SWAP_AMOUNT,
            0,
            address(factory),
            extensionData1
        );
        
        // Fill second order
        IOrderMixin.Order memory order2 = IOrderMixin.Order({
            salt: 2,
            maker: Address.wrap(uint160(alice)),
            receiver: Address.wrap(uint160(alice)),
            makerAsset: Address.wrap(uint160(address(bmnToken))),
            takerAsset: Address.wrap(uint160(address(otherToken))),
            makingAmount: SWAP_AMOUNT,
            takingAmount: SWAP_AMOUNT,
            makerTraits: MakerTraits.wrap(0)
        });
        
        bytes memory extensionData2 = abi.encode(
            hashlock2, 
            1, 
            address(otherToken), 
            0, // No safety deposits
            (uint256(block.timestamp + 3600) << 128) | uint256(block.timestamp + 300) // Proper timelocks
        );
        
        limitOrderProtocol.fillOrderWithPostInteraction(
            order2,
            "",
            SWAP_AMOUNT,
            0,
            address(factory),
            extensionData2
        );
        
        vm.stopPrank();
        
        // Verify both escrows were created
        address escrow1 = factory.escrows(hashlock1);
        address escrow2 = factory.escrows(hashlock2);
        
        assertNotEq(escrow1, address(0), "First escrow should be created");
        assertNotEq(escrow2, address(0), "Second escrow should be created");
        assertNotEq(escrow1, escrow2, "Escrows should be different");
        
        // Verify each escrow has correct tokens
        assertEq(bmnToken.balanceOf(escrow1), SWAP_AMOUNT, "First escrow should have tokens");
        assertEq(bmnToken.balanceOf(escrow2), SWAP_AMOUNT, "Second escrow should have tokens");
    }
}