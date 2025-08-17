// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Test.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { ECDSA } from "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import { Address, AddressLib } from "solidity-utils/contracts/libraries/AddressLib.sol";

import { EscrowDst } from "../contracts/EscrowDst.sol";
import { IEscrowDst } from "../contracts/interfaces/IEscrowDst.sol";
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
 * @title MockEscrowDstForTesting
 * @notice Extended EscrowDst with public access to internal functions for testing
 */
contract MockEscrowDstForTesting is EscrowDst {
    using ImmutablesLib for IBaseEscrow.Immutables;
    
    // Flag to control validation mode
    bool public useSimpleValidation = false;
    bytes32 public expectedImmutablesHash;
    
    constructor(uint32 rescueDelay, IERC20 accessToken) EscrowDst(rescueDelay, accessToken) {}
    
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
            // Simple validation for testing - bypass CREATE2 checks
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
    
    /**
     * @dev Public wrapper for accessing DOMAIN_SEPARATOR
     */
    function DOMAIN_SEPARATOR() external view returns (bytes32) {
        return _domainSeparator();
    }
}

/**
 * @title EscrowDstTest
 * @notice Comprehensive test suite for EscrowDst contract
 * @dev Tests all 10 specific test cases for destination escrow with focus on secret reveal and safety deposits
 */
contract EscrowDstTest is Test {
    using ImmutablesLib for IBaseEscrow.Immutables;
    using TimelocksLib for Timelocks;
    using AddressLib for Address;
    
    // Constants matching context from previous agents
    uint32 constant RESCUE_DELAY = 604800; // 7 days in seconds (as per Agent 1)
    uint256 constant DEPLOYED_AT_OFFSET = 224; // Timelocks packed in bits 224-255 (as per Agent 2)
    bytes32 constant CORRECT_SECRET = keccak256("correct_secret");
    bytes32 constant WRONG_SECRET = keccak256("wrong_secret");
    
    // Test contracts
    MockEscrowDstForTesting public escrow;
    MockFactory public factory;
    TokenMock public token;
    TokenMock public accessToken;
    
    // Test accounts
    address constant MAKER = address(0x5678);
    address constant TAKER = address(0x9ABC);  // Taker is the resolver on destination chain
    address constant ANYONE = address(0x1111);
    
    // Resolver account with known private key for EIP-712 signatures
    uint256 constant RESOLVER_PRIVATE_KEY = 0x12345678;
    address RESOLVER;
    
    // Test immutables
    IBaseEscrow.Immutables public testImmutables;
    
    // Destination chain timelock timestamps (relative to deployment)
    uint32 constant DST_WITHDRAWAL_START = 100;          // Maker can withdraw (revealing secret)
    uint32 constant DST_PUBLIC_WITHDRAWAL_START = 200;   // Public withdrawal (with access token)
    uint32 constant DST_CANCELLATION_START = 300;        // Taker can cancel and get safety deposit back
    
    // Events - critical for cross-chain communication
    event EscrowWithdrawal(bytes32 secret);  // Contains revealed secret!
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
        escrow = new MockEscrowDstForTesting(RESCUE_DELAY, IERC20(address(accessToken)));
        
        // Set up timelocks with destination chain stages
        uint256 deployTimestamp = block.timestamp;
        uint256 packedTimelocks = uint256(uint32(deployTimestamp)) << DEPLOYED_AT_OFFSET;
        
        // Pack destination timelocks - note stages 4-6 for destination chain
        packedTimelocks |= uint256(uint32(DST_WITHDRAWAL_START)) << 128;         // Stage 4: DstWithdrawal
        packedTimelocks |= uint256(uint32(DST_PUBLIC_WITHDRAWAL_START)) << 160;   // Stage 5: DstPublicWithdrawal
        packedTimelocks |= uint256(uint32(DST_CANCELLATION_START)) << 192;        // Stage 6: DstCancellation
        
        // Set up immutables
        testImmutables = IBaseEscrow.Immutables({
            orderHash: keccak256("order"),
            hashlock: keccak256(abi.encode(CORRECT_SECRET)),
            maker: Address.wrap(uint160(MAKER)),
            taker: Address.wrap(uint160(TAKER)),  // Taker is resolver on destination
            token: Address.wrap(uint160(address(token))),
            amount: 1000 ether,
            safetyDeposit: 0.1 ether,  // Safety deposit to prevent griefing
            timelocks: Timelocks.wrap(packedTimelocks),
            parameters: ""
        });
        
        // Fund escrow with tokens and ETH for safety deposit
        // On destination chain, resolver (taker) locks tokens for maker
        token.mint(address(escrow), testImmutables.amount);
        vm.deal(address(escrow), testImmutables.safetyDeposit);
        
        // Give access tokens to test accounts for public functions
        accessToken.mint(RESOLVER, 1000 ether);
        accessToken.mint(ANYONE, 1000 ether);
        
        // Set up escrow with expected immutables hash for validation
        bytes32 immutablesHash = testImmutables.hashMem();  // Using ImmutablesLib.hashMem() as per Agent 1
        escrow.setExpectedImmutablesHash(immutablesHash);
        escrow.setSimpleValidation(true);  // Enable simple validation to bypass CREATE2 checks
    }
    
    /**
     * @notice Test 1: Maker withdraws revealing secret
     * @dev Critical test - secret reveal enables source chain withdrawal
     * NOTE: On DST, only taker can call withdraw, but tokens go to maker
     */
    function testWithdrawByMaker() public {
        // Warp to withdrawal window
        vm.warp(block.timestamp + DST_WITHDRAWAL_START + 1);
        
        // Record initial balances
        uint256 makerTokenBefore = token.balanceOf(MAKER);
        uint256 takerEthBefore = TAKER.balance;
        
        // Withdraw as TAKER (only taker can call withdraw on DST)
        vm.prank(TAKER);
        
        // CRITICAL: Expect WithdrawalDst event with revealed secret
        vm.expectEmit(true, false, false, true);
        emit EscrowWithdrawal(CORRECT_SECRET);
        
        uint256 gasStart = gasleft();
        escrow.withdraw(CORRECT_SECRET, testImmutables);
        uint256 gasUsed = gasStart - gasleft();
        
        // Verify token transfer to maker
        assertEq(token.balanceOf(MAKER), makerTokenBefore + testImmutables.amount, "Maker should receive tokens");
        assertEq(token.balanceOf(address(escrow)), 0, "Escrow should have no tokens");
        
        // Verify safety deposit goes to caller (taker who called withdraw)
        assertEq(TAKER.balance, takerEthBefore + testImmutables.safetyDeposit, "Taker (caller) should receive safety deposit");
        
        // Document cross-chain implications
        console.log("Secret revealed in event for source chain withdrawal");
        console.log("Withdraw gas used:", gasUsed);
    }
    
    /**
     * @notice Test 2: Non-maker withdraw fails (only taker modifier)
     * @dev On destination chain, only taker (resolver) can call withdraw
     */
    function testWithdrawByNonMaker() public {
        // Warp to withdrawal window
        vm.warp(block.timestamp + DST_WITHDRAWAL_START + 1);
        
        // Try to withdraw as anyone (not taker)
        vm.prank(ANYONE);
        vm.expectRevert(IBaseEscrow.InvalidCaller.selector);
        escrow.withdraw(CORRECT_SECRET, testImmutables);
        
        // Verify tokens still in escrow
        assertEq(token.balanceOf(address(escrow)), testImmutables.amount, "Tokens should remain in escrow");
    }
    
    /**
     * @notice Test 3: Withdrawal fails before window
     * @dev Tests timelock enforcement for cross-chain synchronization
     */
    function testWithdrawBeforeWindow() public {
        // Stay at current time (before withdrawal window)
        assertTrue(block.timestamp < testImmutables.timelocks.get(TimelocksLib.Stage.DstWithdrawal), "Should be before withdrawal window");
        
        // Try to withdraw as taker
        vm.prank(TAKER);
        vm.expectRevert(IBaseEscrow.InvalidTime.selector);
        escrow.withdraw(CORRECT_SECRET, testImmutables);
        
        // Verify tokens still in escrow
        assertEq(token.balanceOf(address(escrow)), testImmutables.amount, "Tokens should remain in escrow");
    }
    
    /**
     * @notice Test 4: Withdrawal fails after cancellation time
     * @dev Tests upper bound of withdrawal window
     */
    function testWithdrawAfterCancellation() public {
        // Warp past cancellation time
        vm.warp(block.timestamp + DST_CANCELLATION_START + 1);
        
        // Try to withdraw as taker
        vm.prank(TAKER);
        vm.expectRevert(IBaseEscrow.InvalidTime.selector);
        escrow.withdraw(CORRECT_SECRET, testImmutables);
        
        // Verify tokens still in escrow
        assertEq(token.balanceOf(address(escrow)), testImmutables.amount, "Tokens should remain in escrow");
    }
    
    /**
     * @notice Test 5: Taker cancels and gets safety deposit back
     * @dev Critical: Safety deposit incentivizes resolver participation
     */
    function testCancelByTaker() public {
        // Warp to cancellation window
        vm.warp(block.timestamp + DST_CANCELLATION_START + 1);
        
        // Record initial balances
        uint256 takerTokenBefore = token.balanceOf(TAKER);
        uint256 takerEthBefore = TAKER.balance;
        
        // Cancel as taker
        vm.prank(TAKER);
        vm.expectEmit(false, false, false, true);
        emit EscrowCancelled();
        
        uint256 gasStart = gasleft();
        escrow.cancel(testImmutables);
        uint256 gasUsed = gasStart - gasleft();
        
        // Verify tokens returned to taker (resolver gets their tokens back)
        assertEq(token.balanceOf(TAKER), takerTokenBefore + testImmutables.amount, "Taker should get tokens back");
        assertEq(token.balanceOf(address(escrow)), 0, "Escrow should have no tokens");
        
        // CRITICAL: Verify safety deposit returned to taker
        assertEq(TAKER.balance, takerEthBefore + testImmutables.safetyDeposit, "Taker should get safety deposit back");
        
        // Document safety deposit mechanics
        console.log("Safety deposit returned to taker on cancel:", testImmutables.safetyDeposit);
        console.log("Cancel gas used:", gasUsed);
    }
    
    /**
     * @notice Test 6: Non-taker cancel fails
     * @dev Only taker can cancel on destination chain
     */
    function testCancelByNonTaker() public {
        // Warp to cancellation window
        vm.warp(block.timestamp + DST_CANCELLATION_START + 1);
        
        // Try to cancel as maker (not allowed on destination)
        vm.prank(MAKER);
        vm.expectRevert(IBaseEscrow.InvalidCaller.selector);
        escrow.cancel(testImmutables);
        
        // Try to cancel as anyone
        vm.prank(ANYONE);
        vm.expectRevert(IBaseEscrow.InvalidCaller.selector);
        escrow.cancel(testImmutables);
        
        // Verify tokens still in escrow
        assertEq(token.balanceOf(address(escrow)), testImmutables.amount, "Tokens should remain in escrow");
    }
    
    /**
     * @notice Test 7: Public cancel after timeout with access token
     * @dev Tests public cancellation mechanism for stuck funds
     */
    function testPublicCancelAfterTimeout() public {
        // Warp to cancellation window
        vm.warp(block.timestamp + DST_CANCELLATION_START + 1);
        
        // Record initial balances
        uint256 anyoneEthBefore = ANYONE.balance;
        
        // For public cancel with signature, we need a whitelisted resolver to sign
        // The taker is the resolver on destination chain
        bytes32 actionHash = escrow.hashPublicAction(testImmutables.orderHash, ANYONE, "DST_PUBLIC_CANCEL");
        
        // We'll whitelist the actual signer (derived from our test key)
        address actualSigner = vm.addr(RESOLVER_PRIVATE_KEY);
        factory.setWhitelistedResolver(actualSigner, true);
        
        // Update immutables to use the actual signer as taker
        IBaseEscrow.Immutables memory modifiedImmutables = testImmutables;
        modifiedImmutables.taker = Address.wrap(uint160(actualSigner));
        
        // Recompute hash and set it
        bytes32 newHash = modifiedImmutables.hashMem();
        escrow.setExpectedImmutablesHash(newHash);
        
        // Sign with resolver's key
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(RESOLVER_PRIVATE_KEY, actionHash);
        bytes memory signature = abi.encodePacked(r, s, v);
        
        // Public cancel as anyone with resolver signature
        vm.prank(ANYONE);
        vm.expectEmit(false, false, false, true);
        emit EscrowCancelled();
        escrow.publicCancelSigned(modifiedImmutables, signature);
        
        // Verify tokens returned to the modified taker (actualSigner)
        assertEq(token.balanceOf(actualSigner), testImmutables.amount, "Taker should get tokens back");
        
        // Verify safety deposit goes to caller (ANYONE)
        assertEq(ANYONE.balance, anyoneEthBefore + testImmutables.safetyDeposit, "Caller should get safety deposit");
    }
    
    /**
     * @notice Test 8: Safety deposit return mechanics
     * @dev Verifies correct amounts and recipients for safety deposits
     */
    function testSafetyDepositReturn() public {
        // Test withdrawal scenario - safety deposit to withdrawer
        vm.warp(block.timestamp + DST_WITHDRAWAL_START + 1);
        
        uint256 withdrawerEthBefore = TAKER.balance;
        vm.prank(TAKER);
        escrow.withdraw(CORRECT_SECRET, testImmutables);
        
        assertEq(TAKER.balance, withdrawerEthBefore + testImmutables.safetyDeposit, 
            "Withdrawer should receive safety deposit");
        
        // Deploy new escrow for cancel test
        setUp();
        
        // Test cancellation scenario - safety deposit to canceller
        vm.warp(block.timestamp + DST_CANCELLATION_START + 1);
        
        uint256 cancellerEthBefore = TAKER.balance;
        vm.prank(TAKER);
        escrow.cancel(testImmutables);
        
        assertEq(TAKER.balance, cancellerEthBefore + testImmutables.safetyDeposit, 
            "Canceller should receive safety deposit");
        
        // Document safety deposit formula
        console.log("Safety deposit amount:", testImmutables.safetyDeposit);
        console.log("Safety deposit prevents griefing by incentivizing completion");
    }
    
    /**
     * @notice Test 9: WithdrawalDst event contains secret
     * @dev CRITICAL: Secret in event enables cross-chain atomic swap
     */
    function testSecretEventEmission() public {
        // Warp to withdrawal window
        vm.warp(block.timestamp + DST_WITHDRAWAL_START + 1);
        
        // Set up event monitoring
        vm.recordLogs();
        
        // Withdraw revealing secret
        vm.prank(TAKER);
        escrow.withdraw(CORRECT_SECRET, testImmutables);
        
        // Check emitted events
        Vm.Log[] memory logs = vm.getRecordedLogs();
        
        // Find WithdrawalDst event
        bool foundEvent = false;
        bytes32 emittedSecret;
        
        for (uint i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == keccak256("EscrowWithdrawal(bytes32)")) {
                foundEvent = true;
                // Secret is in data, not indexed
                emittedSecret = abi.decode(logs[i].data, (bytes32));
                break;
            }
        }
        
        assertTrue(foundEvent, "WithdrawalDst event should be emitted");
        assertEq(emittedSecret, CORRECT_SECRET, "Event should contain correct secret");
        
        // Document cross-chain implications
        console.log("Secret revealed in event enables source chain withdrawal");
        console.log("This is the critical atomicity mechanism");
    }
    
    /**
     * @notice Test 10: Cannot withdraw or cancel twice (state machine)
     * @dev Tests that escrow state transitions are final
     */
    function testDoubleAction() public {
        // Test double withdrawal
        vm.warp(block.timestamp + DST_WITHDRAWAL_START + 1);
        
        // First withdrawal succeeds
        vm.prank(TAKER);
        escrow.withdraw(CORRECT_SECRET, testImmutables);
        
        // Second withdrawal should fail (no funds)
        vm.prank(TAKER);
        // Will revert with transfer failure since escrow is empty
        vm.expectRevert();
        escrow.withdraw(CORRECT_SECRET, testImmutables);
        
        // Deploy new escrow for cancel test
        setUp();
        
        // Test double cancellation
        vm.warp(block.timestamp + DST_CANCELLATION_START + 1);
        
        // First cancel succeeds
        vm.prank(TAKER);
        escrow.cancel(testImmutables);
        
        // Second cancel should fail (no funds)
        vm.prank(TAKER);
        // Will revert with transfer failure since escrow is empty
        vm.expectRevert();
        escrow.cancel(testImmutables);
        
        console.log("State transitions are final - no double actions possible");
    }
    
    /**
     * @notice Additional test: Public withdrawal with access token
     * @dev Tests access-controlled public withdrawal mechanism
     */
    function testPublicWithdrawWithAccessToken() public {
        // Warp to public withdrawal window
        vm.warp(block.timestamp + DST_PUBLIC_WITHDRAWAL_START + 1);
        
        // Public withdraw with access token
        vm.prank(ANYONE);
        vm.expectEmit(true, false, false, true);
        emit EscrowWithdrawal(CORRECT_SECRET);
        
        escrow.publicWithdraw(CORRECT_SECRET, testImmutables);
        
        // Verify tokens went to maker
        assertEq(token.balanceOf(MAKER), testImmutables.amount, "Maker should receive tokens");
        
        // Verify safety deposit went to caller
        assertEq(ANYONE.balance, testImmutables.safetyDeposit, "Caller should receive safety deposit");
    }
    
    /**
     * @notice Additional test: Wrong secret validation
     * @dev Ensures hashlock security mechanism works
     */
    function testWithdrawWrongSecret() public {
        // Warp to withdrawal window
        vm.warp(block.timestamp + DST_WITHDRAWAL_START + 1);
        
        // Try to withdraw with wrong secret
        vm.prank(TAKER);
        vm.expectRevert(IBaseEscrow.InvalidSecret.selector);
        escrow.withdraw(WRONG_SECRET, testImmutables);
        
        // Verify funds remain locked
        assertEq(token.balanceOf(address(escrow)), testImmutables.amount, "Tokens should remain locked");
    }
    
    /**
     * @notice Additional test: EIP-712 domain verification
     * @dev Verifies domain name and version as per Agent 2 context
     */
    function testEIP712Domain() public {
        (string memory name, string memory version) = escrow.domainNameAndVersion();
        assertEq(name, "BMN-Escrow", "Domain name should be BMN-Escrow");
        assertEq(version, "2.3", "Domain version should be 2.3");
    }
}