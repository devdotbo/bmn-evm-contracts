// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Test.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { ECDSA } from "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import { Address, AddressLib } from "solidity-utils/contracts/libraries/AddressLib.sol";

import { EscrowSrc } from "../contracts/EscrowSrc.sol";
import { IEscrowSrc } from "../contracts/interfaces/IEscrowSrc.sol";
import { IBaseEscrow } from "../contracts/interfaces/IBaseEscrow.sol";
import { BaseEscrow } from "../contracts/BaseEscrow.sol";
import { ImmutablesLib } from "../contracts/libraries/ImmutablesLib.sol";
import { Timelocks, TimelocksLib } from "../contracts/libraries/TimelocksLib.sol";
import { TokenMock } from "../contracts/mocks/TokenMock.sol";
import { ProxyHashLib } from "../contracts/libraries/ProxyHashLib.sol";
import { IResolverValidation } from "../contracts/interfaces/IResolverValidation.sol";

/**
 * @title MockFactory
 * @notice Mock factory contract for testing that implements resolver validation
 */
contract MockFactory is IResolverValidation {
    mapping(address => bool) public whitelistedResolvers;
    
    function setWhitelistedResolver(address resolver, bool whitelisted) external {
        whitelistedResolvers[resolver] = whitelisted;
    }
    
    function isWhitelistedResolver(address resolver) external view returns (bool) {
        return whitelistedResolvers[resolver];
    }
}

/**
 * @title MockEscrowSrcForTesting
 * @notice Extended EscrowSrc with public access to internal functions for testing
 */
contract MockEscrowSrcForTesting is EscrowSrc {
    using ImmutablesLib for IBaseEscrow.Immutables;
    
    // Flag to control validation mode
    bool public useSimpleValidation = false;
    bytes32 public expectedImmutablesHash;
    
    constructor(uint32 rescueDelay, IERC20 accessToken) EscrowSrc(rescueDelay, accessToken) {}
    
    /**
     * @dev Set the expected immutables hash for validation testing
     */
    function setExpectedImmutablesHash(bytes32 hash) external {
        expectedImmutablesHash = hash;
    }
    
    /**
     * @dev Override to use simple hash validation for tests
     */
    function setSimpleValidation(bool _useSimple) external {
        useSimpleValidation = _useSimple;
    }
    
    /**
     * @dev Override validation to support testing mode
     */
    function _validateImmutables(IBaseEscrow.Immutables calldata immutables) internal view override {
        if (useSimpleValidation) {
            // Simple validation for testing
            bytes32 actualHash = immutables.hashMem();
            if (actualHash != expectedImmutablesHash) {
                revert InvalidImmutables();
            }
        } else {
            // Use parent validation (CREATE2)
            super._validateImmutables(immutables);
        }
    }
    
    /**
     * @dev Public wrapper for testing internal _domainNameAndVersion
     */
    function domainNameAndVersion() external pure returns (string memory, string memory) {
        return _domainNameAndVersion();
    }
    
    /**
     * @dev Public wrapper for testing _hashPublicAction
     */
    function hashPublicAction(bytes32 orderHash, address caller, string memory action) external view returns (bytes32) {
        return _hashPublicAction(orderHash, caller, action);
    }
    
    /**
     * @dev Public wrapper for testing _recover
     */
    function recover(bytes32 digest, bytes calldata sig) external pure returns (address) {
        return _recover(digest, sig);
    }
}

/**
 * @title EscrowSrcTest
 * @notice Comprehensive test suite for EscrowSrc contract
 * @dev Tests all 13 specific test cases with focus on timelock boundaries and state transitions
 */
contract EscrowSrcTest is Test {
    using ImmutablesLib for IBaseEscrow.Immutables;
    using TimelocksLib for Timelocks;
    using AddressLib for Address;
    
    // Constants
    uint32 constant RESCUE_DELAY = 604800; // 7 days in seconds
    uint256 constant DEPLOYED_AT_OFFSET = 224;
    bytes32 constant CORRECT_SECRET = keccak256("correct_secret");
    bytes32 constant WRONG_SECRET = keccak256("wrong_secret");
    
    // Test contracts
    MockEscrowSrcForTesting public escrow;
    MockFactory public factory;
    TokenMock public token;
    TokenMock public accessToken;
    
    // Test accounts
    address constant MAKER = address(0x5678);
    address constant TAKER = address(0x9ABC);
    address constant ANYONE = address(0x1111);
    
    // Resolver account with known private key for EIP-712 signatures
    uint256 constant RESOLVER_PRIVATE_KEY = 0x12345678;
    address RESOLVER;
    
    // Test immutables
    IBaseEscrow.Immutables public testImmutables;
    
    // Timelock timestamps (relative to deployment)
    uint32 constant SRC_WITHDRAWAL_START = 100;          // Taker can withdraw
    uint32 constant SRC_PUBLIC_WITHDRAWAL_START = 200;   // Anyone can trigger withdrawal
    uint32 constant SRC_CANCELLATION_START = 300;        // Maker can cancel
    uint32 constant SRC_PUBLIC_CANCELLATION_START = 400; // Anyone can cancel
    
    // Events
    event EscrowWithdrawal(bytes32 secret);
    event EscrowCancelled();
    
    function setUp() public {
        // Calculate resolver address from private key
        RESOLVER = vm.addr(RESOLVER_PRIVATE_KEY);
        
        // Deploy tokens
        token = new TokenMock("Test Token", "TEST", 18);
        accessToken = new TokenMock("Access Token", "ACCESS", 18);
        
        // Deploy mock factory
        factory = new MockFactory();
        factory.setWhitelistedResolver(RESOLVER, true);
        
        // Deploy escrow (as factory)
        vm.prank(address(factory));
        escrow = new MockEscrowSrcForTesting(RESCUE_DELAY, IERC20(address(accessToken)));
        
        // Set up timelocks with specific stages
        uint256 deployTimestamp = block.timestamp;
        uint256 packedTimelocks = uint256(uint32(deployTimestamp)) << DEPLOYED_AT_OFFSET;
        
        // Pack timelocks - stages represent seconds from deployment
        packedTimelocks |= uint256(uint32(SRC_WITHDRAWAL_START)) << 0;           // Stage 0: SrcWithdrawal
        packedTimelocks |= uint256(uint32(SRC_PUBLIC_WITHDRAWAL_START)) << 32;   // Stage 1: SrcPublicWithdrawal
        packedTimelocks |= uint256(uint32(SRC_CANCELLATION_START)) << 64;        // Stage 2: SrcCancellation
        packedTimelocks |= uint256(uint32(SRC_PUBLIC_CANCELLATION_START)) << 96;  // Stage 3: SrcPublicCancellation
        
        // Set up immutables
        testImmutables = IBaseEscrow.Immutables({
            orderHash: keccak256("order"),
            hashlock: keccak256(abi.encode(CORRECT_SECRET)),
            maker: Address.wrap(uint160(MAKER)),
            taker: Address.wrap(uint160(TAKER)),
            token: Address.wrap(uint160(address(token))),
            amount: 1000 ether,
            safetyDeposit: 0.1 ether,
            timelocks: Timelocks.wrap(packedTimelocks),
            parameters: ""
        });
        
        // Fund escrow with tokens and ETH for safety deposit
        token.mint(address(escrow), testImmutables.amount);
        vm.deal(address(escrow), testImmutables.safetyDeposit);
        
        // Give access tokens to test accounts
        accessToken.mint(RESOLVER, 1000 ether);
        accessToken.mint(ANYONE, 1000 ether);
        
        // Set up escrow with expected immutables hash for validation
        bytes32 immutablesHash = testImmutables.hashMem();
        escrow.setExpectedImmutablesHash(immutablesHash);
        escrow.setSimpleValidation(true);  // Enable simple validation for testing
    }
    
    /**
     * @notice Test 1: Taker withdraws with correct secret during withdrawal window
     */
    function testWithdrawValidSecret() public {
        // Warp to withdrawal window
        vm.warp(block.timestamp + SRC_WITHDRAWAL_START + 1);
        
        // Record initial balances
        uint256 takerTokenBefore = token.balanceOf(TAKER);
        uint256 takerEthBefore = TAKER.balance;
        
        // Withdraw as taker with correct secret
        vm.prank(TAKER);
        vm.expectEmit(true, false, false, true);
        emit EscrowWithdrawal(CORRECT_SECRET);
        
        uint256 gasStart = gasleft();
        escrow.withdraw(CORRECT_SECRET, testImmutables);
        uint256 gasUsed = gasStart - gasleft();
        
        // Verify token transfer
        assertEq(token.balanceOf(TAKER), takerTokenBefore + testImmutables.amount, "Taker should receive tokens");
        assertEq(token.balanceOf(address(escrow)), 0, "Escrow should have no tokens");
        
        // Verify safety deposit refund
        assertEq(TAKER.balance, takerEthBefore + testImmutables.safetyDeposit, "Taker should receive safety deposit");
        
        // Document gas usage (Note: Mock implementation uses more gas than production)
        console.log("Withdraw gas used:", gasUsed);
    }
    
    /**
     * @notice Test 2: Withdrawal fails with invalid secret
     */
    function testWithdrawInvalidSecret() public {
        // Warp to withdrawal window
        vm.warp(block.timestamp + SRC_WITHDRAWAL_START + 1);
        
        // Try to withdraw with wrong secret
        vm.prank(TAKER);
        vm.expectRevert(IBaseEscrow.InvalidSecret.selector);
        escrow.withdraw(WRONG_SECRET, testImmutables);
        
        // Verify tokens still in escrow
        assertEq(token.balanceOf(address(escrow)), testImmutables.amount, "Tokens should remain in escrow");
    }
    
    /**
     * @notice Test 3: Withdrawal fails before withdrawal window
     */
    function testWithdrawBeforeWindow() public {
        // Stay at current time (before withdrawal window)
        assertTrue(block.timestamp < testImmutables.timelocks.get(TimelocksLib.Stage.SrcWithdrawal), "Should be before withdrawal window");
        
        // Try to withdraw too early
        vm.prank(TAKER);
        vm.expectRevert(IBaseEscrow.InvalidTime.selector);
        escrow.withdraw(CORRECT_SECRET, testImmutables);
        
        // Test exact boundary (1 second before allowed)
        vm.warp(block.timestamp + SRC_WITHDRAWAL_START - 1);
        vm.prank(TAKER);
        vm.expectRevert(IBaseEscrow.InvalidTime.selector);
        escrow.withdraw(CORRECT_SECRET, testImmutables);
    }
    
    /**
     * @notice Test 4: Withdrawal fails after cancellation time
     */
    function testWithdrawAfterWindow() public {
        // Warp to after cancellation starts
        vm.warp(block.timestamp + SRC_CANCELLATION_START + 1);
        
        // Try to withdraw after window
        vm.prank(TAKER);
        vm.expectRevert(IBaseEscrow.InvalidTime.selector);
        escrow.withdraw(CORRECT_SECRET, testImmutables);
        
        // Test exact boundary (at cancellation time)
        vm.warp(block.timestamp + SRC_CANCELLATION_START);
        vm.prank(TAKER);
        vm.expectRevert(IBaseEscrow.InvalidTime.selector);
        escrow.withdraw(CORRECT_SECRET, testImmutables);
    }
    
    /**
     * @notice Test 5: Anyone can trigger withdrawal during public window
     */
    function testPublicWithdrawDuringPublicWindow() public {
        // Warp to public withdrawal window
        vm.warp(block.timestamp + SRC_PUBLIC_WITHDRAWAL_START + 1);
        
        // Give access token to ANYONE
        vm.prank(ANYONE);
        accessToken.approve(address(escrow), type(uint256).max);
        
        // Record initial balances
        uint256 takerTokenBefore = token.balanceOf(TAKER);
        uint256 anyoneEthBefore = ANYONE.balance;
        
        // Public withdraw by anyone with access token
        vm.prank(ANYONE);
        vm.expectEmit(true, false, false, true);
        emit EscrowWithdrawal(CORRECT_SECRET);
        escrow.publicWithdraw(CORRECT_SECRET, testImmutables);
        
        // Verify taker receives tokens
        assertEq(token.balanceOf(TAKER), takerTokenBefore + testImmutables.amount, "Taker should receive tokens");
        
        // Verify caller receives safety deposit
        assertEq(ANYONE.balance, anyoneEthBefore + testImmutables.safetyDeposit, "Caller should receive safety deposit");
    }
    
    /**
     * @notice Test 6: Public withdrawal fails outside public window
     */
    function testPublicWithdrawNotInWindow() public {
        // Test before public window (during private window)
        vm.warp(block.timestamp + SRC_WITHDRAWAL_START + 1);
        
        vm.prank(ANYONE);
        accessToken.approve(address(escrow), type(uint256).max);
        
        vm.prank(ANYONE);
        vm.expectRevert(IBaseEscrow.InvalidTime.selector);
        escrow.publicWithdraw(CORRECT_SECRET, testImmutables);
        
        // Test after cancellation starts
        vm.warp(block.timestamp + SRC_CANCELLATION_START + 1);
        
        vm.prank(ANYONE);
        vm.expectRevert(IBaseEscrow.InvalidTime.selector);
        escrow.publicWithdraw(CORRECT_SECRET, testImmutables);
    }
    
    /**
     * @notice Test 7: Maker can cancel during cancellation window
     */
    function testCancelByMaker() public {
        // Note: In EscrowSrc, cancel is actually restricted to TAKER, not MAKER
        // This is because onlyTaker modifier is used in the cancel function
        
        // Warp to cancellation window
        vm.warp(block.timestamp + SRC_CANCELLATION_START + 1);
        
        // Record initial balances
        uint256 makerTokenBefore = token.balanceOf(MAKER);
        uint256 takerEthBefore = TAKER.balance;
        
        // Cancel as taker (who has permission in EscrowSrc)
        vm.prank(TAKER);
        vm.expectEmit(false, false, false, true);
        emit EscrowCancelled();
        
        uint256 gasStart = gasleft();
        escrow.cancel(testImmutables);
        uint256 gasUsed = gasStart - gasleft();
        
        // Verify maker receives tokens back
        assertEq(token.balanceOf(MAKER), makerTokenBefore + testImmutables.amount, "Maker should receive tokens back");
        assertEq(token.balanceOf(address(escrow)), 0, "Escrow should have no tokens");
        
        // Verify caller (taker) receives safety deposit
        assertEq(TAKER.balance, takerEthBefore + testImmutables.safetyDeposit, "Taker should receive safety deposit");
        
        // Document gas usage
        console.log("Cancel gas used:", gasUsed);
    }
    
    /**
     * @notice Test 8: Non-maker (actually non-taker) cannot cancel during private window
     */
    function testCancelByNonMaker() public {
        // Warp to private cancellation window
        vm.warp(block.timestamp + SRC_CANCELLATION_START + 1);
        
        // Try to cancel as maker (who doesn't have permission)
        vm.prank(MAKER);
        vm.expectRevert(IBaseEscrow.InvalidCaller.selector);
        escrow.cancel(testImmutables);
        
        // Try to cancel as anyone else
        vm.prank(ANYONE);
        vm.expectRevert(IBaseEscrow.InvalidCaller.selector);
        escrow.cancel(testImmutables);
    }
    
    /**
     * @notice Test 9: Anyone can cancel after public cancellation time
     */
    function testPublicCancelAfterTimeout() public {
        // Warp to public cancellation window
        vm.warp(block.timestamp + SRC_PUBLIC_CANCELLATION_START + 1);
        
        // Give access token to ANYONE
        vm.prank(ANYONE);
        accessToken.approve(address(escrow), type(uint256).max);
        
        // Record initial balances
        uint256 makerTokenBefore = token.balanceOf(MAKER);
        uint256 anyoneEthBefore = ANYONE.balance;
        
        // Public cancel by anyone
        vm.prank(ANYONE);
        vm.expectEmit(false, false, false, true);
        emit EscrowCancelled();
        escrow.publicCancel(testImmutables);
        
        // Verify maker receives tokens back
        assertEq(token.balanceOf(MAKER), makerTokenBefore + testImmutables.amount, "Maker should receive tokens back");
        
        // Verify caller receives safety deposit
        assertEq(ANYONE.balance, anyoneEthBefore + testImmutables.safetyDeposit, "Caller should receive safety deposit");
    }
    
    /**
     * @notice Test 10: Cannot withdraw twice (reentrancy protection)
     */
    function testDoubleWithdraw() public {
        // Warp to withdrawal window
        vm.warp(block.timestamp + SRC_WITHDRAWAL_START + 1);
        
        // First withdrawal succeeds
        vm.prank(TAKER);
        escrow.withdraw(CORRECT_SECRET, testImmutables);
        
        // Second withdrawal should fail (tokens already withdrawn)
        vm.prank(TAKER);
        vm.expectRevert(); // Will revert on token transfer since balance is 0
        escrow.withdraw(CORRECT_SECRET, testImmutables);
    }
    
    /**
     * @notice Test 11: Cannot withdraw after cancellation
     */
    function testWithdrawAfterCancel() public {
        // Warp to cancellation window
        vm.warp(block.timestamp + SRC_CANCELLATION_START + 1);
        
        // Cancel first
        vm.prank(TAKER);
        escrow.cancel(testImmutables);
        
        // Try to withdraw (should fail - no tokens left)
        vm.warp(block.timestamp - 100); // Go back to withdrawal window
        vm.prank(TAKER);
        vm.expectRevert(); // Will revert on token transfer since balance is 0
        escrow.withdraw(CORRECT_SECRET, testImmutables);
    }
    
    /**
     * @notice Test 12: EIP-712 signed withdrawal by resolver
     */
    function testEIP712SignedWithdraw() public {
        // Warp to public withdrawal window
        vm.warp(block.timestamp + SRC_PUBLIC_WITHDRAWAL_START + 1);
        
        // Create EIP-712 signature
        bytes32 actionHash = escrow.hashPublicAction(
            testImmutables.orderHash,
            ANYONE,
            "SRC_PUBLIC_WITHDRAW"
        );
        
        // Use a known private key for testing
        vm.startPrank(RESOLVER);
        uint256 resolverKey = RESOLVER_PRIVATE_KEY;
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(resolverKey, actionHash);
        bytes memory signature = abi.encodePacked(r, s, v);
        vm.stopPrank();
        
        // Record initial balances
        uint256 takerTokenBefore = token.balanceOf(TAKER);
        uint256 anyoneEthBefore = ANYONE.balance;
        
        // Execute signed withdrawal
        vm.prank(ANYONE);
        vm.expectEmit(true, false, false, true);
        emit EscrowWithdrawal(CORRECT_SECRET);
        escrow.publicWithdrawSigned(CORRECT_SECRET, testImmutables, signature);
        
        // Verify taker receives tokens
        assertEq(token.balanceOf(TAKER), takerTokenBefore + testImmutables.amount, "Taker should receive tokens");
        
        // Verify caller receives safety deposit
        assertEq(ANYONE.balance, anyoneEthBefore + testImmutables.safetyDeposit, "Caller should receive safety deposit");
    }
    
    /**
     * @notice Test 13: EIP-712 signed cancellation by resolver
     */
    function testEIP712SignedCancel() public {
        // Warp to public cancellation window
        vm.warp(block.timestamp + SRC_PUBLIC_CANCELLATION_START + 1);
        
        // Create EIP-712 signature
        bytes32 actionHash = escrow.hashPublicAction(
            testImmutables.orderHash,
            ANYONE,
            "SRC_PUBLIC_CANCEL"
        );
        
        // Use a known private key for testing
        vm.startPrank(RESOLVER);
        uint256 resolverKey = RESOLVER_PRIVATE_KEY;
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(resolverKey, actionHash);
        bytes memory signature = abi.encodePacked(r, s, v);
        vm.stopPrank();
        
        // Record initial balances
        uint256 makerTokenBefore = token.balanceOf(MAKER);
        uint256 anyoneEthBefore = ANYONE.balance;
        
        // Execute signed cancellation
        vm.prank(ANYONE);
        vm.expectEmit(false, false, false, true);
        emit EscrowCancelled();
        escrow.publicCancelSigned(testImmutables, signature);
        
        // Verify maker receives tokens back
        assertEq(token.balanceOf(MAKER), makerTokenBefore + testImmutables.amount, "Maker should receive tokens back");
        
        // Verify caller receives safety deposit
        assertEq(ANYONE.balance, anyoneEthBefore + testImmutables.safetyDeposit, "Caller should receive safety deposit");
    }
    
    /**
     * @notice Additional test: Verify exact timelock boundaries (off by 1 second)
     */
    function testExactTimelockBoundaries() public {
        // Test withdrawal starts exactly at boundary
        vm.warp(block.timestamp + SRC_WITHDRAWAL_START);
        vm.prank(TAKER);
        escrow.withdraw(CORRECT_SECRET, testImmutables);
        
        // Reset for next test
        setUp();
        
        // Test public withdrawal starts exactly at boundary
        vm.warp(block.timestamp + SRC_PUBLIC_WITHDRAWAL_START);
        vm.prank(ANYONE);
        accessToken.approve(address(escrow), type(uint256).max);
        vm.prank(ANYONE);
        escrow.publicWithdraw(CORRECT_SECRET, testImmutables);
        
        // Reset for next test
        setUp();
        
        // Test cancellation boundary - one second before should fail
        vm.warp(block.timestamp + SRC_CANCELLATION_START - 1);
        vm.prank(TAKER);
        vm.expectRevert(IBaseEscrow.InvalidTime.selector);
        escrow.cancel(testImmutables);
        
        // Exactly at boundary should work
        vm.warp(block.timestamp + SRC_CANCELLATION_START);
        vm.prank(TAKER);
        escrow.cancel(testImmutables);
    }
    
    /**
     * @notice Additional test: WithdrawTo function with custom target
     */
    function testWithdrawToCustomTarget() public {
        // Warp to withdrawal window
        vm.warp(block.timestamp + SRC_WITHDRAWAL_START + 1);
        
        address customTarget = address(0x2222);
        
        // Record initial balances
        uint256 targetTokenBefore = token.balanceOf(customTarget);
        uint256 takerEthBefore = TAKER.balance;
        
        // WithdrawTo as taker
        vm.prank(TAKER);
        vm.expectEmit(true, false, false, true);
        emit EscrowWithdrawal(CORRECT_SECRET);
        escrow.withdrawTo(CORRECT_SECRET, customTarget, testImmutables);
        
        // Verify custom target receives tokens
        assertEq(token.balanceOf(customTarget), targetTokenBefore + testImmutables.amount, "Custom target should receive tokens");
        
        // Verify taker (caller) still receives safety deposit
        assertEq(TAKER.balance, takerEthBefore + testImmutables.safetyDeposit, "Taker should receive safety deposit");
    }
    
    /**
     * @notice Test gas measurements for all operations
     */
    function testGasMeasurements() public {
        // Measure withdraw gas
        vm.warp(block.timestamp + SRC_WITHDRAWAL_START + 1);
        vm.prank(TAKER);
        uint256 gasStart = gasleft();
        escrow.withdraw(CORRECT_SECRET, testImmutables);
        uint256 withdrawGas = gasStart - gasleft();
        console.log("Withdraw gas:", withdrawGas);
        
        // Reset and measure cancel gas
        setUp();
        vm.warp(block.timestamp + SRC_CANCELLATION_START + 1);
        vm.prank(TAKER);
        gasStart = gasleft();
        escrow.cancel(testImmutables);
        uint256 cancelGas = gasStart - gasleft();
        console.log("Cancel gas:", cancelGas);
        
        // Reset and measure public operations
        setUp();
        vm.warp(block.timestamp + SRC_PUBLIC_WITHDRAWAL_START + 1);
        vm.prank(ANYONE);
        accessToken.approve(address(escrow), type(uint256).max);
        vm.prank(ANYONE);
        gasStart = gasleft();
        escrow.publicWithdraw(CORRECT_SECRET, testImmutables);
        uint256 publicWithdrawGas = gasStart - gasleft();
        console.log("Public withdraw gas:", publicWithdrawGas);
        
        // Document findings
        console.log("--- Gas Measurements Summary ---");
        console.log("Withdraw:", withdrawGas);
        console.log("Cancel:", cancelGas);
        console.log("Public Withdraw:", publicWithdrawGas);
    }
}