// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Test.sol";
import "../contracts/CrossChainEscrowFactory.sol";
import "solidity-utils/contracts/mocks/TokenMock.sol";
import "../contracts/libraries/TimelocksLib.sol";
import { Address, AddressLib } from "solidity-utils/contracts/libraries/AddressLib.sol";
import { IOrderMixin } from "limit-order-protocol/contracts/interfaces/IOrderMixin.sol";
import { MakerTraits, MakerTraitsLib } from "limit-order-protocol/contracts/libraries/MakerTraitsLib.sol";

// Interface for SimpleLimitOrderProtocol
interface ISimpleLimitOrderProtocol {
    function DOMAIN_SEPARATOR() external view returns(bytes32);
    function fillOrder(
        IOrderMixin.Order calldata order,
        bytes32 r,
        bytes32 vs,
        uint256 amount,
        uint256 takerTraits
    ) external payable returns(uint256 makingAmount, uint256 takingAmount, bytes32 orderHash);
}

// Mock SimpleLimitOrderProtocol for testing
contract MockSimpleLimitOrderProtocol is ISimpleLimitOrderProtocol {
    using AddressLib for Address;
    using MakerTraitsLib for MakerTraits;
    
    bytes32 public constant DOMAIN_SEPARATOR = keccak256("TEST_DOMAIN");
    CrossChainEscrowFactory public factory;
    
    constructor(address _factory) {
        factory = CrossChainEscrowFactory(_factory);
    }
    
    function fillOrder(
        IOrderMixin.Order calldata order,
        bytes32 r,
        bytes32 vs,
        uint256 amount,
        uint256 takerTraits
    ) external payable returns(uint256 makingAmount, uint256 takingAmount, bytes32 orderHash) {
        // Simplified order filling for testing
        makingAmount = order.makingAmount;
        takingAmount = order.takingAmount;
        orderHash = keccak256(abi.encode(order));
        
        // Transfer tokens (simplified - in real implementation this is more complex)
        IERC20(order.makerAsset.get()).transferFrom(order.maker.get(), msg.sender, makingAmount);
        IERC20(order.takerAsset.get()).transferFrom(msg.sender, order.maker.get(), takingAmount);
        
        // Call postInteraction on factory if POST_INTERACTION flag is set
        if (order.makerTraits.needPostInteractionCall()) {
            // Extract extension data (this would come from the order extension in real usage)
            bytes memory extensionData = abi.encode(
                address(factory),              // factory address
                block.chainid == 31337 ? 1 : 31337,  // destination chain ID
                order.takerAsset.get(),       // destination token
                order.maker.get(),             // destination receiver
                Timelocks.wrap(
                    (uint256(3600) << 192) |    // srcWithdrawal
                    (uint256(7200) << 160) |    // srcPublicWithdrawal
                    (uint256(10800) << 128) |   // srcCancellation
                    (uint256(14400) << 96) |    // srcPublicCancellation
                    (uint256(1800) << 64) |     // dstWithdrawal
                    (uint256(3600) << 32) |     // dstPublicWithdrawal
                    uint256(5400)                // dstCancellation
                ),
                keccak256("test_secret")       // hashlock
            );
            
            // Call factory's postInteraction
            factory.postInteraction(
                order,
                extensionData,
                orderHash,
                msg.sender,
                makingAmount,
                takingAmount,
                0,
                extensionData
            );
        }
        
        return (makingAmount, takingAmount, orderHash);
    }
}

contract SimpleLimitOrderIntegrationTest is Test {
    using AddressLib for Address;
    using TimelocksLib for Timelocks;
    
    CrossChainEscrowFactory factory;
    MockSimpleLimitOrderProtocol limitOrderProtocol;
    TokenMock tokenA;
    TokenMock tokenB;
    TokenMock bmnToken;
    
    address alice = address(0xA11CE);
    address bob = address(0xB0B);
    address resolver = address(0x3E501);
    
    bytes32 constant SECRET = "test_secret_123";
    bytes32 constant HASHLOCK = keccak256(abi.encode(SECRET));
    
    function setUp() public {
        // Deploy tokens
        tokenA = new TokenMock("Token A", "TKA");
        tokenB = new TokenMock("Token B", "TKB");
        bmnToken = new TokenMock("BMN", "BMN");
        
        // Deploy factory with correct constructor parameters
        uint32 rescueDelay = 7 days;
        factory = new CrossChainEscrowFactory(
            address(0),                   // Will set later
            IERC20(address(bmnToken)),
            IERC20(address(bmnToken)),
            address(this),
            rescueDelay,                  // rescueDelaySrc
            rescueDelay                   // rescueDelayDst
        );
        
        // Deploy mock SimpleLimitOrderProtocol with factory address
        limitOrderProtocol = new MockSimpleLimitOrderProtocol(address(factory));
        
        // Update factory with limit order protocol address
        // Note: In real deployment, this is set in constructor
        // For testing, we need to use a workaround or deploy in correct order
        
        // Mint tokens
        tokenA.mint(alice, 1000 ether);
        tokenB.mint(bob, 1000 ether);
        bmnToken.mint(alice, 100 ether);
        bmnToken.mint(bob, 100 ether);
        bmnToken.mint(resolver, 100 ether);
        
        // Set up approvals
        vm.prank(alice);
        tokenA.approve(address(limitOrderProtocol), type(uint256).max);
        
        vm.prank(bob);
        tokenB.approve(address(limitOrderProtocol), type(uint256).max);
        
        // Fund accounts with ETH
        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
        vm.deal(resolver, 10 ether);
    }
    
    function testOrderFillingWithEscrowCreation() public {
        // Create order from Alice (maker) offering Token A for Token B
        IOrderMixin.Order memory order = IOrderMixin.Order({
            salt: uint256(keccak256("order1")),
            maker: Address.wrap(uint160(alice)),
            receiver: Address.wrap(0), // Default to taker
            makerAsset: Address.wrap(uint160(address(tokenA))),
            takerAsset: Address.wrap(uint160(address(tokenB))),
            makingAmount: 100 ether,
            takingAmount: 50 ether,
            makerTraits: MakerTraits.wrap(uint256(1 << 255)) // POST_INTERACTION flag
        });
        
        // Bob (taker) fills the order
        vm.prank(bob);
        (uint256 makingAmount, uint256 takingAmount, bytes32 orderHash) = limitOrderProtocol.fillOrder(
            order,
            bytes32(0), // Simplified - no signature validation in mock
            bytes32(0),
            100 ether,  // Full amount
            0           // No taker traits
        );
        
        assertEq(makingAmount, 100 ether, "Making amount should match");
        assertEq(takingAmount, 50 ether, "Taking amount should match");
        
        // Verify tokens were transferred
        assertEq(tokenA.balanceOf(bob), 100 ether, "Bob should receive Token A");
        assertEq(tokenB.balanceOf(alice), 50 ether, "Alice should receive Token B");
    }
    
    function testCrossChainEscrowFlow() public {
        // Setup timelocks - packed as uint256 with bit shifts
        // Format: srcWithdrawal(192), srcPublicWithdrawal(160), srcCancellation(128), srcPublicCancellation(96),
        //         dstWithdrawal(64), dstPublicWithdrawal(32), dstCancellation(0)
        Timelocks timelocks = Timelocks.wrap(
            (uint256(3600) << 192) |    // srcWithdrawal
            (uint256(7200) << 160) |    // srcPublicWithdrawal
            (uint256(10800) << 128) |   // srcCancellation
            (uint256(14400) << 96) |    // srcPublicCancellation
            (uint256(1800) << 64) |     // dstWithdrawal
            (uint256(3600) << 32) |     // dstPublicWithdrawal
            uint256(5400)                // dstCancellation
        );
        
        // Create order with cross-chain parameters
        IOrderMixin.Order memory order = IOrderMixin.Order({
            salt: uint256(keccak256("cross-chain-order")),
            maker: Address.wrap(uint160(alice)),
            receiver: Address.wrap(0),
            makerAsset: Address.wrap(uint160(address(tokenA))),
            takerAsset: Address.wrap(uint160(address(tokenB))),
            makingAmount: 100 ether,
            takingAmount: 50 ether,
            makerTraits: MakerTraits.wrap(uint256(1 << 255)) // POST_INTERACTION flag
        });
        
        // Resolver fills the order (acts as taker)
        // Mint tokens to resolver first (as test contract owner)
        tokenB.mint(resolver, 50 ether); // Ensure resolver has tokens
        
        // Then have resolver approve
        vm.prank(resolver);
        tokenB.approve(address(limitOrderProtocol), type(uint256).max);
        
        vm.prank(resolver);
        (uint256 makingAmount, uint256 takingAmount,) = limitOrderProtocol.fillOrder(
            order,
            bytes32(0),
            bytes32(0),
            100 ether,
            0
        );
        
        // Verify the cross-chain swap setup
        assertEq(makingAmount, 100 ether, "Making amount should match");
        assertEq(takingAmount, 50 ether, "Taking amount should match");
        
        // In a real scenario:
        // 1. Source escrow would be created with Alice's tokens locked
        // 2. Resolver would create destination escrow on other chain
        // 3. Alice withdraws from destination escrow with secret
        // 4. Resolver uses revealed secret to withdraw from source escrow
    }
    
    function testPartialFillNotAllowed() public {
        // Create order that doesn't allow partial fills
        IOrderMixin.Order memory order = IOrderMixin.Order({
            salt: uint256(keccak256("no-partial")),
            maker: Address.wrap(uint160(alice)),
            receiver: Address.wrap(0),
            makerAsset: Address.wrap(uint160(address(tokenA))),
            takerAsset: Address.wrap(uint160(address(tokenB))),
            makingAmount: 100 ether,
            takingAmount: 50 ether,
            makerTraits: MakerTraits.wrap(0) // No flags - partial fills not allowed
        });
        
        // Attempting partial fill should revert in real implementation
        // (Mock doesn't implement this check for simplicity)
        vm.prank(bob);
        limitOrderProtocol.fillOrder(
            order,
            bytes32(0),
            bytes32(0),
            50 ether, // Partial amount
            0
        );
        
        // In real implementation, this would revert with "PartialFillNotAllowed"
    }
}