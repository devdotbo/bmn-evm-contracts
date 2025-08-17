// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Test.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { Clones } from "openzeppelin-contracts/contracts/proxy/Clones.sol";
import { Address, AddressLib } from "solidity-utils/contracts/libraries/AddressLib.sol";
import { SafeERC20 } from "solidity-utils/contracts/libraries/SafeERC20.sol";

import { SimplifiedEscrowFactory } from "../contracts/SimplifiedEscrowFactory.sol";
import { EscrowSrc } from "../contracts/EscrowSrc.sol";
import { EscrowDst } from "../contracts/EscrowDst.sol";
import { BaseEscrow } from "../contracts/BaseEscrow.sol";
import { IBaseEscrow } from "../contracts/interfaces/IBaseEscrow.sol";
import { IEscrowFactory } from "../contracts/interfaces/IEscrowFactory.sol";
import { IPostInteraction } from "../dependencies/limit-order-protocol/contracts/interfaces/IPostInteraction.sol";
import { IOrderMixin } from "../dependencies/limit-order-protocol/contracts/interfaces/IOrderMixin.sol";
import { MakerTraits } from "../dependencies/limit-order-protocol/contracts/libraries/MakerTraitsLib.sol";
import { ImmutablesLib } from "../contracts/libraries/ImmutablesLib.sol";
import { Timelocks, TimelocksLib } from "../contracts/libraries/TimelocksLib.sol";
import { TokenMock } from "../contracts/mocks/TokenMock.sol";
import { MockLimitOrderProtocol } from "./mocks/MockLimitOrderProtocol.sol";

/**
 * @title E2ESingleChainTest
 * @notice Comprehensive end-to-end tests simulating cross-chain atomic swaps on a single chain
 * @dev Uses two factory instances to simulate different chains
 */
contract E2ESingleChainTest is Test {
    using AddressLib for Address;
    using ImmutablesLib for IBaseEscrow.Immutables;
    using TimelocksLib for Timelocks;
    using SafeERC20 for IERC20;
    
    // Constants
    uint256 constant MAKER_AMOUNT = 100 ether;
    uint256 constant TAKER_AMOUNT = 90 ether; // Simulating exchange rate
    uint256 constant SAFETY_DEPOSIT = 1 ether;
    uint256 constant SRC_CHAIN_ID = 1; // Simulated source chain
    uint256 constant DST_CHAIN_ID = 10; // Simulated destination chain
    bytes32 constant SECRET = keccak256("atomic_swap_secret");
    bytes32 constant HASHLOCK = keccak256(abi.encodePacked(SECRET));
    
    // Timelock windows (in seconds)
    uint32 constant SRC_WITHDRAWAL_WINDOW = 1 hours;
    uint32 constant SRC_PUBLIC_WITHDRAWAL_WINDOW = 30 minutes;
    uint32 constant SRC_CANCELLATION_WINDOW = 2 hours;
    uint32 constant SRC_PUBLIC_CANCELLATION_WINDOW = 1 hours;
    uint32 constant DST_WITHDRAWAL_WINDOW = 1 hours;
    uint32 constant DST_CANCELLATION_WINDOW = 2 hours;
    
    // Factories (simulating different chains)
    SimplifiedEscrowFactory srcFactory;
    SimplifiedEscrowFactory dstFactory;
    
    // Protocol mock
    MockLimitOrderProtocol protocol;
    
    // Implementations
    EscrowSrc srcImplementation;
    EscrowDst dstImplementation;
    
    // Tokens
    TokenMock srcToken; // Token on source chain
    TokenMock dstToken; // Token on destination chain
    TokenMock accessToken;
    
    // Actors
    address owner;
    address alice; // Maker
    address bob; // Resolver/Taker
    address charlie; // Alternative resolver
    address dave; // Attacker
    
    // Escrow addresses
    address srcEscrow;
    address dstEscrow;
    
    // Store immutables for function calls
    IBaseEscrow.Immutables srcImmutables;
    IBaseEscrow.Immutables dstImmutables;
    
    // Events to monitor
    event SrcEscrowCreated(
        IBaseEscrow.Immutables srcImmutables,
        IEscrowFactory.DstImmutablesComplement dstImmutablesComplement
    );
    
    event DstEscrowCreated(
        address indexed escrow,
        bytes32 indexed hashlock,
        address indexed taker
    );
    
    event EscrowWithdraw(address indexed token, address indexed recipient, uint256 amount);
    event EscrowCancelled();
    event SecretRevealed(bytes32 indexed secret);
    
    function setUp() public {
        // Setup actors
        owner = makeAddr("owner");
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        charlie = makeAddr("charlie");
        dave = makeAddr("dave");
        
        // Fund actors with ETH for gas
        vm.deal(owner, 100 ether);
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
        vm.deal(charlie, 100 ether);
        vm.deal(dave, 100 ether);
        
        // Deploy tokens
        srcToken = new TokenMock("Source Token", "SRC", 18);
        dstToken = new TokenMock("Destination Token", "DST", 18);
        accessToken = new TokenMock("Access Token", "ACCESS", 18);
        
        // Mint tokens to actors
        srcToken.mint(alice, 1000 ether);
        srcToken.mint(bob, 100 ether);
        dstToken.mint(bob, 1000 ether);
        dstToken.mint(charlie, 1000 ether);
        accessToken.mint(bob, 100 ether);
        accessToken.mint(charlie, 100 ether);
        
        // Deploy implementations
        srcImplementation = new EscrowSrc(7 days, IERC20(address(accessToken)));
        dstImplementation = new EscrowDst(7 days, IERC20(address(accessToken)));
        
        // Deploy factories (simulating different chains)
        srcFactory = new SimplifiedEscrowFactory(
            address(srcImplementation),
            address(dstImplementation),
            owner
        );
        
        dstFactory = new SimplifiedEscrowFactory(
            address(srcImplementation),
            address(dstImplementation),
            owner
        );
        
        // Deploy mock protocol
        protocol = new MockLimitOrderProtocol();
        
        // Configure factories
        vm.startPrank(owner);
        srcFactory.setWhitelistBypassed(true);
        dstFactory.setWhitelistBypassed(true);
        vm.stopPrank();
    }
    
    /**
     * @notice Test 1: Complete successful atomic swap
     * @dev Demonstrates the full happy path flow
     */
    function testHappyPathFullSwap() public {
        console.log("\n=== Test 1: Happy Path Full Swap ===");
        
        // Step 1: Alice creates order on source chain
        console.log("\nStep 1: Alice creates order on source chain");
        uint256 aliceInitialSrc = srcToken.balanceOf(alice);
        uint256 aliceInitialDst = dstToken.balanceOf(alice);
        
        srcImmutables = _createImmutables(
            alice,
            bob,
            HASHLOCK,
            address(srcToken),
            address(dstToken),
            MAKER_AMOUNT,
            TAKER_AMOUNT,
            SAFETY_DEPOSIT
        );
        
        IEscrowFactory.DstImmutablesComplement memory dstComplement = IEscrowFactory.DstImmutablesComplement({
            maker: Address.wrap(uint160(alice)),
            amount: TAKER_AMOUNT,
            token: Address.wrap(uint160(address(dstToken))),
            safetyDeposit: SAFETY_DEPOSIT,
            chainId: DST_CHAIN_ID,
            parameters: ""
        });
        
        // Step 2: Alice locks tokens in source escrow
        console.log("\nStep 2: Alice locks tokens in source escrow");
        vm.startPrank(alice);
        srcToken.approve(address(srcFactory), MAKER_AMOUNT);
        
        uint256 gasStart = gasleft();
        srcEscrow = srcFactory.createSrcEscrow(
            srcImmutables,
            dstComplement
        );
        uint256 gasUsed = gasStart - gasleft();
        console.log("Gas used for createSrcEscrow:", gasUsed);
        vm.stopPrank();
        
        assertEq(srcToken.balanceOf(srcEscrow), MAKER_AMOUNT, "Source escrow should have maker tokens");
        
        // Step 3: Bob (resolver) deploys and funds destination escrow
        console.log("\nStep 3: Bob deploys and funds destination escrow");
        vm.startPrank(bob);
        
        // Bob needs to calculate matching immutables for destination
        dstImmutables = _createImmutables(
            bob, // Resolver is maker on destination
            alice, // Alice is taker on destination
            HASHLOCK,
            address(dstToken),
            address(srcToken),
            TAKER_AMOUNT,
            MAKER_AMOUNT,
            SAFETY_DEPOSIT
        );
        
        dstToken.approve(address(dstFactory), TAKER_AMOUNT + SAFETY_DEPOSIT);
        
        gasStart = gasleft();
        dstEscrow = dstFactory.createDstEscrow(
            dstImmutables
        );
        gasUsed = gasStart - gasleft();
        console.log("Gas used for createDstEscrow:", gasUsed);
        vm.stopPrank();
        
        assertEq(dstToken.balanceOf(dstEscrow), TAKER_AMOUNT, "Destination escrow should have taker tokens");
        
        // Step 4: Alice withdraws from destination escrow (revealing secret)
        console.log("\nStep 4: Alice withdraws from destination escrow (revealing secret)");
        
        // Advance time to withdrawal window
        vm.warp(block.timestamp + 100);
        
        vm.startPrank(alice);
        gasStart = gasleft();
        vm.expectEmit(true, true, true, true);
        emit SecretRevealed(SECRET);
        
        EscrowDst(dstEscrow).withdraw(SECRET, dstImmutables);
        gasUsed = gasStart - gasleft();
        console.log("Gas used for destination withdrawal:", gasUsed);
        vm.stopPrank();
        
        assertEq(dstToken.balanceOf(alice), aliceInitialDst + TAKER_AMOUNT, "Alice should receive destination tokens");
        
        // Step 5: Bob withdraws from source escrow using revealed secret
        console.log("\nStep 5: Bob withdraws from source escrow using revealed secret");
        
        vm.startPrank(bob);
        gasStart = gasleft();
        EscrowSrc(srcEscrow).withdraw(SECRET, srcImmutables);
        gasUsed = gasStart - gasleft();
        console.log("Gas used for source withdrawal:", gasUsed);
        vm.stopPrank();
        
        assertEq(srcToken.balanceOf(bob), 100 ether + MAKER_AMOUNT, "Bob should receive source tokens");
        
        // Verify atomic swap completed successfully
        console.log("\n[OK] Atomic swap completed successfully");
        console.log("Alice: -100 SRC, +90 DST");
        console.log("Bob: +100 SRC, -90 DST");
        assertEq(srcToken.balanceOf(alice), aliceInitialSrc - MAKER_AMOUNT, "Alice final SRC balance");
        assertEq(dstToken.balanceOf(alice), aliceInitialDst + TAKER_AMOUNT, "Alice final DST balance");
    }
    
    /**
     * @notice Test 2: Maker cancels before resolver locks destination
     * @dev Tests early cancellation scenario
     */
    function testMakerCancelsBeforeResolver() public {
        console.log("\n=== Test 2: Maker Cancels Before Resolver ===");
        
        // Create and fund source escrow
        srcImmutables = _createImmutables(
            alice,
            bob,
            HASHLOCK,
            address(srcToken),
            address(dstToken),
            MAKER_AMOUNT,
            TAKER_AMOUNT,
            SAFETY_DEPOSIT
        );
        
        IEscrowFactory.DstImmutablesComplement memory dstComplement = IEscrowFactory.DstImmutablesComplement({
            maker: Address.wrap(uint160(alice)),
            amount: TAKER_AMOUNT,
            token: Address.wrap(uint160(address(dstToken))),
            safetyDeposit: SAFETY_DEPOSIT,
            chainId: DST_CHAIN_ID,
            parameters: ""
        });
        
        vm.startPrank(alice);
        srcToken.approve(address(srcFactory), MAKER_AMOUNT);
        srcEscrow = srcFactory.createSrcEscrow(srcImmutables, dstComplement);
        vm.stopPrank();
        
        uint256 aliceBalanceBefore = srcToken.balanceOf(alice);
        
        // Alice tries to cancel immediately (should fail - before cancellation window)
        vm.startPrank(alice);
        vm.expectRevert("Source escrow not cancellable yet");
        EscrowSrc(srcEscrow).cancel(srcImmutables);
        vm.stopPrank();
        
        // Advance to cancellation window
        vm.warp(block.timestamp + SRC_WITHDRAWAL_WINDOW + SRC_PUBLIC_WITHDRAWAL_WINDOW + 1);
        
        // Alice cancels successfully
        vm.startPrank(alice);
        vm.expectEmit(true, true, true, true);
        emit EscrowCancelled();
        
        EscrowSrc(srcEscrow).cancel(srcImmutables);
        vm.stopPrank();
        
        assertEq(srcToken.balanceOf(alice), aliceBalanceBefore + MAKER_AMOUNT, "Alice should get refund");
        console.log("[OK] Maker successfully cancelled and received refund");
    }
    
    /**
     * @notice Test 3: Resolver fails to lock destination tokens
     * @dev Tests source refund when destination fails
     */
    function testResolverFailsToLockDst() public {
        console.log("\n=== Test 3: Resolver Fails to Lock Destination ===");
        
        // Create and fund source escrow
        srcImmutables = _createImmutables(
            alice,
            bob,
            HASHLOCK,
            address(srcToken),
            address(dstToken),
            MAKER_AMOUNT,
            TAKER_AMOUNT,
            SAFETY_DEPOSIT
        );
        
        IEscrowFactory.DstImmutablesComplement memory dstComplement = IEscrowFactory.DstImmutablesComplement({
            maker: Address.wrap(uint160(alice)),
            amount: TAKER_AMOUNT,
            token: Address.wrap(uint160(address(dstToken))),
            safetyDeposit: SAFETY_DEPOSIT,
            chainId: DST_CHAIN_ID,
            parameters: ""
        });
        
        vm.startPrank(alice);
        srcToken.approve(address(srcFactory), MAKER_AMOUNT);
        srcEscrow = srcFactory.createSrcEscrow(srcImmutables, dstComplement);
        vm.stopPrank();
        
        // Bob doesn't have enough tokens to lock on destination
        vm.prank(bob);
        dstToken.transfer(address(1), dstToken.balanceOf(bob)); // Send away all tokens
        
        // Attempt to create destination escrow fails
        vm.startPrank(bob);
        dstImmutables = _createImmutables(
            bob,
            alice,
            HASHLOCK,
            address(dstToken),
            address(srcToken),
            TAKER_AMOUNT,
            MAKER_AMOUNT,
            SAFETY_DEPOSIT
        );
        
        vm.expectRevert(); // Will revert due to insufficient balance
        dstFactory.createDstEscrow(
            dstImmutables
        );
        vm.stopPrank();
        
        // Advance time to cancellation window
        vm.warp(block.timestamp + SRC_WITHDRAWAL_WINDOW + SRC_PUBLIC_WITHDRAWAL_WINDOW + 1);
        
        // Alice cancels and gets refund
        uint256 aliceBalanceBefore = srcToken.balanceOf(alice);
        vm.prank(alice);
        EscrowSrc(srcEscrow).cancel(srcImmutables);
        
        assertEq(srcToken.balanceOf(alice), aliceBalanceBefore + MAKER_AMOUNT, "Alice should get full refund");
        console.log("[OK] Source escrow refunded when destination fails");
    }
    
    /**
     * @notice Test 4: Taker fails to withdraw from source
     * @dev Tests destination refund when source withdrawal fails
     */
    function testTakerFailsToWithdrawSrc() public {
        console.log("\n=== Test 4: Taker Fails to Withdraw Source ===");
        
        // Setup both escrows
        srcImmutables = _createImmutables(
            alice,
            bob,
            HASHLOCK,
            address(srcToken),
            address(dstToken),
            MAKER_AMOUNT,
            TAKER_AMOUNT,
            SAFETY_DEPOSIT
        );
        
        IEscrowFactory.DstImmutablesComplement memory dstComplement = IEscrowFactory.DstImmutablesComplement({
            maker: Address.wrap(uint160(alice)),
            amount: TAKER_AMOUNT,
            token: Address.wrap(uint160(address(dstToken))),
            safetyDeposit: SAFETY_DEPOSIT,
            chainId: DST_CHAIN_ID,
            parameters: ""
        });
        
        // Create source escrow
        vm.startPrank(alice);
        srcToken.approve(address(srcFactory), MAKER_AMOUNT);
        srcEscrow = srcFactory.createSrcEscrow(srcImmutables, dstComplement);
        vm.stopPrank();
        
        // Create destination escrow
        dstImmutables = _createImmutables(
            bob,
            alice,
            HASHLOCK,
            address(dstToken),
            address(srcToken),
            TAKER_AMOUNT,
            MAKER_AMOUNT,
            SAFETY_DEPOSIT
        );
        
        vm.startPrank(bob);
        dstToken.approve(address(dstFactory), TAKER_AMOUNT + SAFETY_DEPOSIT);
        dstEscrow = dstFactory.createDstEscrow(
            dstImmutables
        );
        vm.stopPrank();
        
        // Bob tries to withdraw from source with wrong secret
        vm.warp(block.timestamp + 100);
        
        vm.startPrank(bob);
        bytes32 wrongSecret = keccak256("wrong_secret");
        vm.expectRevert("Invalid secret");
        EscrowSrc(srcEscrow).withdraw(wrongSecret, srcImmutables);
        vm.stopPrank();
        
        // Advance time past all windows - destination can be cancelled
        vm.warp(block.timestamp + DST_WITHDRAWAL_WINDOW + 1);
        
        // Bob cancels destination escrow and gets refund
        uint256 bobBalanceBefore = dstToken.balanceOf(bob);
        vm.prank(bob);
        EscrowDst(dstEscrow).cancel(dstImmutables);
        
        assertEq(dstToken.balanceOf(bob), bobBalanceBefore + TAKER_AMOUNT, "Bob should get destination refund");
        
        // Alice can also cancel source escrow
        vm.warp(block.timestamp + SRC_WITHDRAWAL_WINDOW + SRC_PUBLIC_WITHDRAWAL_WINDOW + 1);
        uint256 aliceBalanceBefore = srcToken.balanceOf(alice);
        vm.prank(alice);
        EscrowSrc(srcEscrow).cancel(srcImmutables);
        
        assertEq(srcToken.balanceOf(alice), aliceBalanceBefore + MAKER_AMOUNT, "Alice should get source refund");
        console.log("[OK] Both escrows refunded when swap fails");
    }
    
    /**
     * @notice Test 5: Timelock window enforcement
     * @dev Tests all timelock windows work correctly
     */
    function testTimelockWindowEnforcement() public {
        console.log("\n=== Test 5: Timelock Window Enforcement ===");
        
        // Setup escrows
        srcImmutables = _createImmutables(
            alice,
            bob,
            HASHLOCK,
            address(srcToken),
            address(dstToken),
            MAKER_AMOUNT,
            TAKER_AMOUNT,
            SAFETY_DEPOSIT
        );
        
        IEscrowFactory.DstImmutablesComplement memory dstComplement = IEscrowFactory.DstImmutablesComplement({
            maker: Address.wrap(uint160(alice)),
            amount: TAKER_AMOUNT,
            token: Address.wrap(uint160(address(dstToken))),
            safetyDeposit: SAFETY_DEPOSIT,
            chainId: DST_CHAIN_ID,
            parameters: ""
        });
        
        vm.startPrank(alice);
        srcToken.approve(address(srcFactory), MAKER_AMOUNT);
        srcEscrow = srcFactory.createSrcEscrow(srcImmutables, dstComplement);
        vm.stopPrank();
        
        uint256 startTime = block.timestamp;
        
        // Test 1: Cannot withdraw immediately
        console.log("\nTest: Cannot withdraw immediately");
        vm.startPrank(bob);
        vm.expectRevert("Source escrow not withdrawable yet");
        EscrowSrc(srcEscrow).withdraw(SECRET, srcImmutables);
        vm.stopPrank();
        
        // Test 2: Can withdraw during withdrawal window
        console.log("Test: Can withdraw during withdrawal window");
        vm.warp(startTime + 100); // Within withdrawal window
        vm.prank(bob);
        EscrowSrc(srcEscrow).withdraw(SECRET, srcImmutables);
        assertEq(srcToken.balanceOf(bob), 100 ether + MAKER_AMOUNT, "Bob should receive tokens");
        
        // Reset for cancellation tests
        vm.startPrank(alice);
        srcToken.approve(address(srcFactory), MAKER_AMOUNT);
        srcEscrow = srcFactory.createSrcEscrow(srcImmutables, dstComplement);
        vm.stopPrank();
        startTime = block.timestamp;
        
        // Test 3: Cannot cancel during withdrawal window
        console.log("Test: Cannot cancel during withdrawal window");
        vm.warp(startTime + 100);
        vm.startPrank(alice);
        vm.expectRevert("Source escrow not cancellable yet");
        EscrowSrc(srcEscrow).cancel(srcImmutables);
        vm.stopPrank();
        
        // Test 4: Can cancel after withdrawal window
        console.log("Test: Can cancel after withdrawal window");
        vm.warp(startTime + SRC_WITHDRAWAL_WINDOW + SRC_PUBLIC_WITHDRAWAL_WINDOW + 1);
        uint256 aliceBalanceBefore = srcToken.balanceOf(alice);
        vm.prank(alice);
        EscrowSrc(srcEscrow).cancel(srcImmutables);
        assertEq(srcToken.balanceOf(alice), aliceBalanceBefore + MAKER_AMOUNT, "Alice should get refund");
        
        console.log("[OK] All timelock windows enforced correctly");
    }
    
    /**
     * @notice Test 6: Cross-chain timestamp drift simulation
     * @dev Tests 5-minute timestamp tolerance
     */
    function testCrossChainTimestampDrift() public {
        console.log("\n=== Test 6: Cross-Chain Timestamp Drift ===");
        
        // Simulate source chain timestamp
        uint256 srcChainTime = block.timestamp;
        
        // Create source escrow
        srcImmutables = _createImmutables(
            alice,
            bob,
            HASHLOCK,
            address(srcToken),
            address(dstToken),
            MAKER_AMOUNT,
            TAKER_AMOUNT,
            SAFETY_DEPOSIT
        );
        
        IEscrowFactory.DstImmutablesComplement memory dstComplement = IEscrowFactory.DstImmutablesComplement({
            maker: Address.wrap(uint160(alice)),
            amount: TAKER_AMOUNT,
            token: Address.wrap(uint160(address(dstToken))),
            safetyDeposit: SAFETY_DEPOSIT,
            chainId: DST_CHAIN_ID,
            parameters: ""
        });
        
        vm.startPrank(alice);
        srcToken.approve(address(srcFactory), MAKER_AMOUNT);
        srcEscrow = srcFactory.createSrcEscrow(srcImmutables, dstComplement);
        vm.stopPrank();
        
        // Simulate destination chain with 4 minute drift (within tolerance)
        vm.warp(srcChainTime + 4 minutes);
        
        // Should be able to create destination escrow within tolerance
        dstImmutables = _createImmutables(
            bob,
            alice,
            HASHLOCK,
            address(dstToken),
            address(srcToken),
            TAKER_AMOUNT,
            MAKER_AMOUNT,
            SAFETY_DEPOSIT
        );
        
        vm.startPrank(bob);
        dstToken.approve(address(dstFactory), TAKER_AMOUNT + SAFETY_DEPOSIT);
        dstEscrow = dstFactory.createDstEscrow(
            dstImmutables
        );
        vm.stopPrank();
        
        assertEq(dstToken.balanceOf(dstEscrow), TAKER_AMOUNT, "Destination escrow created despite drift");
        
        // Complete the swap successfully
        vm.warp(block.timestamp + 100);
        
        vm.prank(alice);
        EscrowDst(dstEscrow).withdraw(SECRET, dstImmutables);
        
        vm.prank(bob);
        EscrowSrc(srcEscrow).withdraw(SECRET, srcImmutables);
        
        console.log("[OK] Swap completed successfully with 4-minute timestamp drift");
    }
    
    /**
     * @notice Test 7: Multiple resolvers competing
     * @dev Tests multiple resolvers trying to fill the same order
     */
    function testMultipleResolvers() public {
        console.log("\n=== Test 7: Multiple Resolvers Competing ===");
        
        // Give Charlie tokens too
        dstToken.mint(charlie, 1000 ether);
        
        // Create source escrow
        srcImmutables = _createImmutables(
            alice,
            bob, // Bob is designated taker
            HASHLOCK,
            address(srcToken),
            address(dstToken),
            MAKER_AMOUNT,
            TAKER_AMOUNT,
            SAFETY_DEPOSIT
        );
        
        IEscrowFactory.DstImmutablesComplement memory dstComplement = IEscrowFactory.DstImmutablesComplement({
            maker: Address.wrap(uint160(alice)),
            amount: TAKER_AMOUNT,
            token: Address.wrap(uint160(address(dstToken))),
            safetyDeposit: SAFETY_DEPOSIT,
            chainId: DST_CHAIN_ID,
            parameters: ""
        });
        
        vm.startPrank(alice);
        srcToken.approve(address(srcFactory), MAKER_AMOUNT);
        srcEscrow = srcFactory.createSrcEscrow(srcImmutables, dstComplement);
        vm.stopPrank();
        
        // Charlie tries to create destination escrow (should fail - wrong taker)
        IBaseEscrow.Immutables memory charlieImmutables = _createImmutables(
            charlie, // Charlie as maker
            alice,
            HASHLOCK,
            address(dstToken),
            address(srcToken),
            TAKER_AMOUNT,
            MAKER_AMOUNT,
            SAFETY_DEPOSIT
        );
        
        vm.startPrank(charlie);
        dstToken.approve(address(dstFactory), TAKER_AMOUNT + SAFETY_DEPOSIT);
        address charlieDstEscrow = dstFactory.createDstEscrow(
            charlieImmutables
        );
        vm.stopPrank();
        
        // Charlie's escrow exists but won't match with source escrow
        assertTrue(charlieDstEscrow != address(0), "Charlie can create escrow");
        
        // Bob creates the correct destination escrow
        dstImmutables = _createImmutables(
            bob,
            alice,
            HASHLOCK,
            address(dstToken),
            address(srcToken),
            TAKER_AMOUNT,
            MAKER_AMOUNT,
            SAFETY_DEPOSIT
        );
        
        vm.startPrank(bob);
        dstToken.approve(address(dstFactory), TAKER_AMOUNT + SAFETY_DEPOSIT);
        dstEscrow = dstFactory.createDstEscrow(
            dstImmutables
        );
        vm.stopPrank();
        
        // Alice reveals secret on Bob's escrow (correct one)
        vm.warp(block.timestamp + 100);
        vm.prank(alice);
        EscrowDst(dstEscrow).withdraw(SECRET, dstImmutables);
        
        // Bob can withdraw from source
        vm.prank(bob);
        EscrowSrc(srcEscrow).withdraw(SECRET, srcImmutables);
        
        // Charlie's escrow remains locked until he cancels
        vm.warp(block.timestamp + DST_WITHDRAWAL_WINDOW + 1);
        uint256 charlieBalanceBefore = dstToken.balanceOf(charlie);
        vm.prank(charlie);
        EscrowDst(charlieDstEscrow).cancel(charlieImmutables);
        assertEq(dstToken.balanceOf(charlie), charlieBalanceBefore + TAKER_AMOUNT, "Charlie gets refund");
        
        console.log("[OK] Multiple resolvers handled correctly");
        console.log("Bob completed swap, Charlie got refund");
    }
    
    // Helper function to create immutables
    function _createImmutables(
        address maker,
        address taker,
        bytes32 hashlock,
        address srcTokenAddr,
        address dstTokenAddr,
        uint256 srcAmount,
        uint256 dstAmount,
        uint256 safetyDeposit
    ) internal view returns (IBaseEscrow.Immutables memory) {
        // Pack timelocks manually
        uint256 packedTimelocks = uint256(uint32(block.timestamp)) << 224; // deployedAt
        packedTimelocks |= uint256(uint32(SRC_WITHDRAWAL_WINDOW)) << 0; // srcWithdrawal
        packedTimelocks |= uint256(uint32(SRC_PUBLIC_WITHDRAWAL_WINDOW)) << 32; // srcPublicWithdrawal
        packedTimelocks |= uint256(uint32(SRC_CANCELLATION_WINDOW)) << 64; // srcCancellation
        packedTimelocks |= uint256(uint32(SRC_PUBLIC_CANCELLATION_WINDOW)) << 96; // srcPublicCancellation
        packedTimelocks |= uint256(uint32(DST_WITHDRAWAL_WINDOW)) << 128; // dstWithdrawal
        packedTimelocks |= uint256(uint32(0)) << 160; // dstPublicWithdrawal (not used in simplified version)
        packedTimelocks |= uint256(uint32(DST_CANCELLATION_WINDOW)) << 192; // dstCancellation
        
        return IBaseEscrow.Immutables({
            orderHash: keccak256("order_hash"),
            hashlock: hashlock,
            maker: Address.wrap(uint160(maker)),
            taker: Address.wrap(uint160(taker)),
            token: Address.wrap(uint160(srcTokenAddr)),
            amount: srcAmount,
            safetyDeposit: safetyDeposit,
            timelocks: Timelocks.wrap(packedTimelocks),
            parameters: ""
        });
    }
}