// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Test.sol";
import "../../contracts/extensions/BMNBaseExtension.sol";
import "../../contracts/extensions/BMNResolverExtension.sol";
import "../../contracts/mocks/TokenMock.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

/**
 * @title BMN Extensions Test Suite
 * @notice Comprehensive tests for BMN extension system
 * @dev Tests circuit breakers, gas optimization, MEV protection, and resolver management
 */
contract BMNExtensionsTest is Test {
    // Test implementation of extensions
    TestBaseExtension public baseExt;
    TestResolverExtension public resolverExt;
    TokenMock public bmnToken;
    
    address public owner = address(0x1);
    address public alice = address(0x2);
    address public bob = address(0x3);
    address public charlie = address(0x4);
    
    uint256 constant MIN_STAKE = 10000e18;
    uint256 constant MAX_STAKE = 1000000e18;
    
    event CircuitBreakerTripped(bytes32 indexed breakerId, uint256 volume, uint256 threshold);
    event ResolverRegistered(address indexed resolver, uint256 stakedAmount);
    event ResolverSlashed(address indexed resolver, uint256 amount, string reason);
    
    function setUp() public {
        vm.startPrank(owner);
        
        // Deploy BMN token
        bmnToken = new TokenMock("BMN Token", "BMN");
        
        // Deploy extensions
        baseExt = new TestBaseExtension();
        resolverExt = new TestResolverExtension(IERC20(address(bmnToken)));
        
        // Fund test accounts
        bmnToken.mint(alice, MAX_STAKE * 2);
        bmnToken.mint(bob, MAX_STAKE * 2);
        bmnToken.mint(charlie, MAX_STAKE * 2);
        
        // Fund contract for gas refunds
        vm.deal(address(baseExt), 10 ether);
        vm.deal(address(resolverExt), 10 ether);
        
        vm.stopPrank();
    }
    
    // Circuit Breaker Tests
    
    function testCircuitBreakerConfiguration() public {
        vm.startPrank(owner);
        
        bytes32 breakerId = keccak256("test_breaker");
        baseExt.configureCircuitBreaker(
            breakerId,
            1000, // threshold
            3600, // 1 hour window
            600,  // 10 min cooldown
            true  // auto reset
        );
        
        (uint128 threshold, uint64 window, uint64 cooldown,,,, bool autoReset) = 
            baseExt.circuitBreakers(breakerId);
        
        assertEq(threshold, 1000);
        assertEq(window, 3600);
        assertEq(cooldown, 600);
        assertTrue(autoReset);
        
        vm.stopPrank();
    }
    
    function testCircuitBreakerTripping() public {
        vm.startPrank(owner);
        
        bytes32 breakerId = keccak256(abi.encode(alice, bytes32("context")));
        baseExt.configureCircuitBreaker(breakerId, 100, 3600, 600, false);
        
        vm.stopPrank();
        
        // Should trip after exceeding threshold
        vm.expectRevert(abi.encodeWithSelector(
            BMNBaseExtension.CircuitBreakerTripped.selector,
            breakerId
        ));
        baseExt.testCheckBreakers(alice, bytes32("context"), 101);
    }
    
    function testCircuitBreakerAutoReset() public {
        vm.startPrank(owner);
        
        bytes32 breakerId = keccak256(abi.encode(alice, bytes32("context")));
        baseExt.configureCircuitBreaker(breakerId, 100, 60, 60, true);
        
        vm.stopPrank();
        
        // Trip the breaker
        vm.expectRevert();
        baseExt.testCheckBreakers(alice, bytes32("context"), 101);
        
        // Fast forward past cooldown
        vm.warp(block.timestamp + 121);
        
        // Should work again after auto-reset
        baseExt.testCheckBreakers(alice, bytes32("context"), 50);
    }
    
    // MEV Protection Tests
    
    function testMEVProtectionCommitReveal() public {
        bytes32 orderHash = keccak256("order");
        bytes memory data = abi.encode("interaction");
        
        // Create commitment
        bytes32 commitHash = baseExt.testPreInteraction(alice, orderHash, data);
        
        // Should fail if revealing too early
        vm.expectRevert(abi.encodeWithSelector(
            BMNBaseExtension.MEVProtectionNotMet.selector,
            block.number,
            block.number + 1
        ));
        baseExt.testPostInteraction(alice, address(0), data, commitHash);
        
        // Advance block
        vm.roll(block.number + 1);
        
        // Should succeed after MEV delay
        baseExt.testPostInteraction(alice, address(0), data, commitHash);
        assertTrue(baseExt.isRevealed(commitHash));
    }
    
    // Gas Optimization Tests
    
    function testGasOptimizationTracking() public {
        bytes4 selector = bytes4(keccak256("testFunction()"));
        
        // First execution sets baseline
        baseExt.testTrackGas(selector, 100000, alice);
        
        BMNBaseExtension.GasMetrics memory metrics = baseExt.getGasMetrics(selector);
        assertEq(metrics.baseline, 100000);
        assertEq(metrics.executions, 1);
        
        // Optimized execution should generate refund
        baseExt.testTrackGas(selector, 80000, alice);
        
        uint256 refund = baseExt.gasRefunds(alice);
        assertGt(refund, 0);
    }
    
    function testGasRefundClaim() public {
        bytes4 selector = bytes4(keccak256("testFunction()"));
        
        // Generate refunds
        baseExt.testTrackGas(selector, 100000, alice);
        baseExt.testTrackGas(selector, 80000, alice);
        
        uint256 refundAmount = baseExt.gasRefunds(alice);
        uint256 aliceBalanceBefore = alice.balance;
        
        // Claim refund
        vm.prank(alice);
        baseExt.claimGasRefund();
        
        assertEq(alice.balance, aliceBalanceBefore + refundAmount);
        assertEq(baseExt.gasRefunds(alice), 0);
    }
    
    // Resolver Management Tests
    
    function testResolverRegistration() public {
        vm.startPrank(alice);
        bmnToken.approve(address(resolverExt), MIN_STAKE);
        
        vm.expectEmit(true, false, false, true);
        emit ResolverRegistered(alice, MIN_STAKE);
        
        resolverExt.registerResolver(MIN_STAKE);
        
        (uint128 reputation, uint128 stake,,,,,, bool isWhitelisted) = 
            resolverExt.resolverProfiles(alice);
        
        assertEq(reputation, 10000); // Perfect starting reputation
        assertEq(stake, MIN_STAKE);
        assertTrue(isWhitelisted);
        
        vm.stopPrank();
    }
    
    function testResolverStakeIncrease() public {
        // Register first
        vm.startPrank(alice);
        bmnToken.approve(address(resolverExt), MIN_STAKE * 2);
        resolverExt.registerResolver(MIN_STAKE);
        
        // Increase stake
        resolverExt.increaseStake(MIN_STAKE);
        
        (, uint128 stake,,,,,, ) = resolverExt.resolverProfiles(alice);
        assertEq(stake, MIN_STAKE * 2);
        
        vm.stopPrank();
    }
    
    function testResolverSlashing() public {
        // Register resolver
        vm.startPrank(alice);
        bmnToken.approve(address(resolverExt), MIN_STAKE);
        resolverExt.registerResolver(MIN_STAKE);
        vm.stopPrank();
        
        // Record failed swap (triggers slashing)
        resolverExt.testRecordPerformance(alice, false, 10, 1000e18, 1e18);
        
        (, uint128 stake,, uint64 failed,,,,) = resolverExt.resolverProfiles(alice);
        assertEq(failed, 1);
        assertLt(stake, MIN_STAKE); // Stake reduced by slash
    }
    
    function testResolverReputationUpdate() public {
        // Register resolver
        vm.startPrank(alice);
        bmnToken.approve(address(resolverExt), MIN_STAKE);
        resolverExt.registerResolver(MIN_STAKE);
        vm.stopPrank();
        
        // Record successful swaps
        for (uint i = 0; i < 10; i++) {
            resolverExt.testRecordPerformance(alice, true, 5, 1000e18, 1e18);
        }
        
        (uint128 reputation,, uint64 successful,,,,,) = resolverExt.resolverProfiles(alice);
        assertEq(successful, 10);
        assertEq(reputation, 10000); // Should maintain perfect reputation
        
        // Record some failures
        for (uint i = 0; i < 3; i++) {
            resolverExt.testRecordPerformance(alice, false, 10, 1000e18, 1e18);
        }
        
        (reputation,,,,,,,) = resolverExt.resolverProfiles(alice);
        assertLt(reputation, 10000); // Reputation should decrease
    }
    
    function testResolverRanking() public {
        // Register multiple resolvers
        address[] memory resolvers = new address[](3);
        resolvers[0] = alice;
        resolvers[1] = bob;
        resolvers[2] = charlie;
        
        for (uint i = 0; i < resolvers.length; i++) {
            vm.startPrank(resolvers[i]);
            bmnToken.approve(address(resolverExt), MIN_STAKE);
            resolverExt.registerResolver(MIN_STAKE);
            vm.stopPrank();
        }
        
        // Give different performance records
        resolverExt.testRecordPerformance(alice, true, 5, 10000e18, 10e18);
        resolverExt.testRecordPerformance(bob, true, 3, 20000e18, 20e18);
        resolverExt.testRecordPerformance(charlie, false, 10, 5000e18, 5e18);
        
        // Check ranking
        address[] memory topResolvers = resolverExt.getTopResolvers(3);
        assertEq(topResolvers.length, 3);
        // Bob should rank higher due to better metrics
    }
    
    function testInactiveResolverHandling() public {
        // Register resolver
        vm.startPrank(alice);
        bmnToken.approve(address(resolverExt), MIN_STAKE);
        resolverExt.registerResolver(MIN_STAKE);
        vm.stopPrank();
        
        // Fast forward past grace period
        vm.warp(block.timestamp + 8 days);
        
        // Check for inactive resolvers
        resolverExt.checkInactiveResolvers();
        
        (,,,,,, bool isActive,) = resolverExt.resolverProfiles(alice);
        assertFalse(isActive); // Should be deactivated
    }
    
    // Pause/Unpause Tests
    
    function testEmergencyPause() public {
        vm.prank(owner);
        baseExt.emergencyPause();
        
        // Should not allow operations when paused
        vm.expectRevert("Pausable: paused");
        vm.prank(alice);
        bmnToken.approve(address(resolverExt), MIN_STAKE);
    }
    
    // Fuzz Tests
    
    function testFuzzCircuitBreaker(
        uint128 threshold,
        uint64 window,
        uint256 volume
    ) public {
        vm.assume(threshold > 0 && threshold < type(uint128).max);
        vm.assume(window > 0 && window < 365 days);
        vm.assume(volume < type(uint128).max);
        
        vm.startPrank(owner);
        bytes32 breakerId = keccak256(abi.encode(alice, bytes32("fuzz")));
        baseExt.configureCircuitBreaker(breakerId, threshold, window, 0, false);
        vm.stopPrank();
        
        if (volume > threshold) {
            vm.expectRevert();
            baseExt.testCheckBreakers(alice, bytes32("fuzz"), volume);
        } else {
            baseExt.testCheckBreakers(alice, bytes32("fuzz"), volume);
        }
    }
    
    function testFuzzResolverStake(uint256 stakeAmount) public {
        vm.assume(stakeAmount > 0 && stakeAmount < bmnToken.balanceOf(alice));
        
        vm.startPrank(alice);
        bmnToken.approve(address(resolverExt), stakeAmount);
        
        if (stakeAmount < MIN_STAKE) {
            vm.expectRevert();
            resolverExt.registerResolver(stakeAmount);
        } else if (stakeAmount > MAX_STAKE) {
            vm.expectRevert();
            resolverExt.registerResolver(stakeAmount);
        } else {
            resolverExt.registerResolver(stakeAmount);
            (, uint128 stake,,,,,, ) = resolverExt.resolverProfiles(alice);
            assertEq(stake, stakeAmount);
        }
        
        vm.stopPrank();
    }
}

// Test implementations that expose internal functions
contract TestBaseExtension is BMNBaseExtension {
    function testCheckBreakers(address maker, bytes32 context, uint256 volume) external {
        _checkCircuitBreakers(maker, context, volume);
    }
    
    function testPreInteraction(
        address orderMaker,
        bytes32 orderHash,
        bytes calldata data
    ) external returns (bytes32) {
        return _preInteraction(orderMaker, orderHash, data);
    }
    
    function testPostInteraction(
        address orderMaker,
        address target,
        bytes calldata interaction,
        bytes32 commitHash
    ) external {
        _postInteraction(orderMaker, target, interaction, commitHash);
    }
    
    function testTrackGas(bytes4 selector, uint256 gasUsed, address user) external {
        _trackGasOptimization(selector, gasUsed, user);
    }
}

contract TestResolverExtension is BMNResolverExtension {
    constructor(IERC20 token) BMNResolverExtension(token) {}
    
    function testRecordPerformance(
        address resolver,
        bool success,
        uint32 responseTime,
        uint256 volume,
        uint256 fees
    ) external {
        recordResolverPerformance(resolver, success, responseTime, volume, fees);
    }
}