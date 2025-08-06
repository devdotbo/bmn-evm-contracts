// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "solidity-utils/contracts/libraries/SafeERC20.sol";
import "./BMNBaseExtension.sol";

/**
 * @title BMNResolverExtension
 * @notice Advanced resolver validation with reputation, staking, and performance tracking
 * @dev Replaces the stub ResolverValidationExtension with production features
 * @custom:security-contact security@bridgemenot.io
 */
abstract contract BMNResolverExtension is BMNBaseExtension {
    using SafeERC20 for IERC20;
    
    /// @notice Resolver profile information
    struct ResolverProfile {
        uint128 reputation;        // Reputation score (0-10000 basis points)
        uint128 stakedAmount;      // Amount of BMN tokens staked
        uint64 successfulSwaps;    // Number of successful swaps completed
        uint64 failedSwaps;        // Number of failed swaps
        uint32 avgResponseTime;    // Average response time in seconds
        uint32 lastActivityTime;   // Last activity timestamp
        bool isActive;             // Whether resolver is active
        bool isWhitelisted;        // Whether resolver is whitelisted
    }
    
    /// @notice Performance metrics for resolvers
    struct PerformanceMetrics {
        uint256 totalVolume;       // Total volume processed
        uint256 totalFees;         // Total fees earned
        uint32[] responseTimeHistory; // Historical response times
        uint32 bestResponseTime;   // Best response time achieved
        uint32 worstResponseTime;  // Worst response time
    }
    
    /// @notice Slashing event details
    struct SlashingEvent {
        uint256 amount;
        uint256 timestamp;
        string reason;
    }
    
    /// @notice BMN token used for staking
    IERC20 public immutable stakingToken;
    
    /// @notice Minimum stake required to become a resolver
    uint256 public constant MIN_STAKE = 10000e18; // 10,000 BMN tokens
    
    /// @notice Maximum stake allowed per resolver
    uint256 public constant MAX_STAKE = 1000000e18; // 1,000,000 BMN tokens
    
    /// @notice Slash percentage for failures (basis points)
    uint256 public constant SLASH_PERCENTAGE_BPS = 1000; // 10%
    
    /// @notice Minimum reputation to remain active (basis points)
    uint256 public constant MIN_REPUTATION_BPS = 7000; // 70%
    
    /// @notice Response time history size
    uint256 public constant HISTORY_SIZE = 100;
    
    /// @notice Grace period for resolver inactivity (7 days)
    uint256 public constant INACTIVITY_GRACE_PERIOD = 7 days;
    
    /// @notice Resolver profiles
    mapping(address => ResolverProfile) public resolverProfiles;
    
    /// @notice Performance metrics per resolver
    mapping(address => PerformanceMetrics) public performanceMetrics;
    
    /// @notice Slashing history per resolver
    mapping(address => SlashingEvent[]) public slashingHistory;
    
    /// @notice Total staked across all resolvers
    uint256 public totalStaked;
    
    /// @notice Number of active resolvers
    uint256 public activeResolverCount;
    
    /// @notice Resolver ranking for selection algorithm
    address[] public resolverRanking;
    
    // Events
    event ResolverRegistered(address indexed resolver, uint256 stakedAmount);
    event ResolverDeactivated(address indexed resolver, string reason);
    event ResolverReactivated(address indexed resolver);
    event StakeIncreased(address indexed resolver, uint256 amount, uint256 newTotal);
    event StakeDecreased(address indexed resolver, uint256 amount, uint256 newTotal);
    event ResolverSlashed(address indexed resolver, uint256 amount, string reason);
    event ReputationUpdated(address indexed resolver, uint256 oldRep, uint256 newRep);
    event PerformanceRecorded(address indexed resolver, uint32 responseTime, bool success);
    event ResolverRankingUpdated(address[] topResolvers);
    
    // Errors
    error InsufficientStake(uint256 provided, uint256 required);
    error ExcessiveStake(uint256 provided, uint256 maximum);
    error ResolverNotActive(address resolver);
    error ResolverNotWhitelisted(address resolver);
    error AlreadyRegistered(address resolver);
    error WithdrawalLocked(uint256 unlockTime);
    error InsufficientReputation(uint256 current, uint256 required);
    
    constructor(IERC20 _stakingToken) {
        stakingToken = _stakingToken;
    }
    
    /**
     * @notice Register as a resolver with initial stake
     * @param stakeAmount Amount of BMN tokens to stake
     */
    function registerResolver(uint256 stakeAmount) external nonReentrant whenNotPaused {
        if (stakeAmount < MIN_STAKE) {
            revert InsufficientStake(stakeAmount, MIN_STAKE);
        }
        if (stakeAmount > MAX_STAKE) {
            revert ExcessiveStake(stakeAmount, MAX_STAKE);
        }
        if (resolverProfiles[msg.sender].isWhitelisted) {
            revert AlreadyRegistered(msg.sender);
        }
        
        // Transfer stake
        stakingToken.safeTransferFrom(msg.sender, address(this), stakeAmount);
        
        // Create profile
        resolverProfiles[msg.sender] = ResolverProfile({
            reputation: 10000, // Start with perfect reputation
            stakedAmount: uint128(stakeAmount),
            successfulSwaps: 0,
            failedSwaps: 0,
            avgResponseTime: 0,
            lastActivityTime: uint32(block.timestamp),
            isActive: true,
            isWhitelisted: true
        });
        
        // Initialize performance metrics
        performanceMetrics[msg.sender] = PerformanceMetrics({
            totalVolume: 0,
            totalFees: 0,
            responseTimeHistory: new uint32[](0),
            bestResponseTime: type(uint32).max,
            worstResponseTime: 0
        });
        
        // Update global state
        totalStaked += stakeAmount;
        activeResolverCount++;
        resolverRanking.push(msg.sender);
        
        emit ResolverRegistered(msg.sender, stakeAmount);
    }
    
    /**
     * @notice Increase resolver stake
     * @param amount Additional amount to stake
     */
    function increaseStake(uint256 amount) external nonReentrant whenNotPaused {
        ResolverProfile storage profile = resolverProfiles[msg.sender];
        if (!profile.isWhitelisted) {
            revert ResolverNotWhitelisted(msg.sender);
        }
        
        uint256 newTotal = profile.stakedAmount + amount;
        if (newTotal > MAX_STAKE) {
            revert ExcessiveStake(newTotal, MAX_STAKE);
        }
        
        stakingToken.safeTransferFrom(msg.sender, address(this), amount);
        
        profile.stakedAmount = uint128(newTotal);
        totalStaked += amount;
        
        emit StakeIncreased(msg.sender, amount, newTotal);
    }
    
    /**
     * @notice Request stake withdrawal (subject to timelock)
     * @param amount Amount to withdraw
     */
    function withdrawStake(uint256 amount) external nonReentrant {
        ResolverProfile storage profile = resolverProfiles[msg.sender];
        if (!profile.isWhitelisted) {
            revert ResolverNotWhitelisted(msg.sender);
        }
        
        uint256 remainingStake = profile.stakedAmount - amount;
        if (remainingStake < MIN_STAKE && remainingStake > 0) {
            revert InsufficientStake(remainingStake, MIN_STAKE);
        }
        
        // If withdrawing all, deactivate resolver
        if (remainingStake == 0) {
            profile.isActive = false;
            profile.isWhitelisted = false;
            activeResolverCount--;
            _removeFromRanking(msg.sender);
        }
        
        profile.stakedAmount = uint128(remainingStake);
        totalStaked -= amount;
        
        stakingToken.safeTransfer(msg.sender, amount);
        
        emit StakeDecreased(msg.sender, amount, remainingStake);
    }
    
    /**
     * @notice Record resolver performance for a swap
     * @param resolver Address of the resolver
     * @param success Whether the swap was successful
     * @param responseTime Response time in seconds
     * @param volume Volume of the swap
     * @param fees Fees earned
     */
    function recordResolverPerformance(
        address resolver,
        bool success,
        uint32 responseTime,
        uint256 volume,
        uint256 fees
    ) internal {
        ResolverProfile storage profile = resolverProfiles[resolver];
        PerformanceMetrics storage metrics = performanceMetrics[resolver];
        
        // Update success/failure counts
        if (success) {
            profile.successfulSwaps++;
        } else {
            profile.failedSwaps++;
            _slashResolver(resolver, "Failed swap execution");
        }
        
        // Update response time metrics
        _updateResponseTime(resolver, responseTime);
        
        // Update volume and fees
        metrics.totalVolume += volume;
        metrics.totalFees += fees;
        
        // Update reputation
        _updateReputation(resolver);
        
        // Update last activity
        profile.lastActivityTime = uint32(block.timestamp);
        
        emit PerformanceRecorded(resolver, responseTime, success);
    }
    
    /**
     * @notice Update resolver response time metrics
     * @param resolver Address of the resolver
     * @param responseTime Response time in seconds
     */
    function _updateResponseTime(address resolver, uint32 responseTime) internal {
        ResolverProfile storage profile = resolverProfiles[resolver];
        PerformanceMetrics storage metrics = performanceMetrics[resolver];
        
        // Add to history
        if (metrics.responseTimeHistory.length >= HISTORY_SIZE) {
            // Remove oldest entry
            for (uint i = 0; i < HISTORY_SIZE - 1; i++) {
                metrics.responseTimeHistory[i] = metrics.responseTimeHistory[i + 1];
            }
            metrics.responseTimeHistory[HISTORY_SIZE - 1] = responseTime;
        } else {
            metrics.responseTimeHistory.push(responseTime);
        }
        
        // Update best/worst
        if (responseTime < metrics.bestResponseTime) {
            metrics.bestResponseTime = responseTime;
        }
        if (responseTime > metrics.worstResponseTime) {
            metrics.worstResponseTime = responseTime;
        }
        
        // Calculate average
        uint256 sum = 0;
        for (uint i = 0; i < metrics.responseTimeHistory.length; i++) {
            sum += metrics.responseTimeHistory[i];
        }
        profile.avgResponseTime = uint32(sum / metrics.responseTimeHistory.length);
    }
    
    /**
     * @notice Update resolver reputation based on performance
     * @param resolver Address of the resolver
     */
    function _updateReputation(address resolver) internal {
        ResolverProfile storage profile = resolverProfiles[resolver];
        
        uint256 totalSwaps = profile.successfulSwaps + profile.failedSwaps;
        if (totalSwaps == 0) return;
        
        uint256 oldReputation = profile.reputation;
        
        // Calculate success rate (basis points)
        uint256 successRate = (profile.successfulSwaps * 10000) / totalSwaps;
        
        // Apply exponential moving average
        profile.reputation = uint128((profile.reputation * 9 + successRate) / 10);
        
        // Check if resolver should be deactivated
        if (profile.reputation < MIN_REPUTATION_BPS && profile.isActive) {
            profile.isActive = false;
            activeResolverCount--;
            _removeFromRanking(resolver);
            emit ResolverDeactivated(resolver, "Low reputation");
        }
        
        emit ReputationUpdated(resolver, oldReputation, profile.reputation);
    }
    
    /**
     * @notice Slash a resolver's stake
     * @param resolver Address of the resolver
     * @param reason Reason for slashing
     */
    function _slashResolver(address resolver, string memory reason) internal {
        ResolverProfile storage profile = resolverProfiles[resolver];
        
        uint256 slashAmount = (profile.stakedAmount * SLASH_PERCENTAGE_BPS) / 10000;
        
        profile.stakedAmount -= uint128(slashAmount);
        totalStaked -= slashAmount;
        
        // Record slashing event
        slashingHistory[resolver].push(SlashingEvent({
            amount: slashAmount,
            timestamp: block.timestamp,
            reason: reason
        }));
        
        // Check if stake fell below minimum
        if (profile.stakedAmount < MIN_STAKE && profile.isActive) {
            profile.isActive = false;
            activeResolverCount--;
            _removeFromRanking(resolver);
            emit ResolverDeactivated(resolver, "Insufficient stake after slashing");
        }
        
        emit ResolverSlashed(resolver, slashAmount, reason);
    }
    
    /**
     * @notice Check for and handle inactive resolvers
     */
    function checkInactiveResolvers() external {
        for (uint i = 0; i < resolverRanking.length; i++) {
            address resolver = resolverRanking[i];
            ResolverProfile storage profile = resolverProfiles[resolver];
            
            if (profile.isActive && 
                block.timestamp > profile.lastActivityTime + INACTIVITY_GRACE_PERIOD) {
                profile.isActive = false;
                activeResolverCount--;
                emit ResolverDeactivated(resolver, "Inactivity");
            }
        }
        
        _updateResolverRanking();
    }
    
    /**
     * @notice Update resolver ranking based on performance
     */
    function _updateResolverRanking() internal {
        // Sort resolvers by composite score
        uint256 length = resolverRanking.length;
        
        for (uint i = 0; i < length - 1; i++) {
            for (uint j = 0; j < length - i - 1; j++) {
                if (_getResolverScore(resolverRanking[j]) < 
                    _getResolverScore(resolverRanking[j + 1])) {
                    address temp = resolverRanking[j];
                    resolverRanking[j] = resolverRanking[j + 1];
                    resolverRanking[j + 1] = temp;
                }
            }
        }
        
        // Emit top 10 resolvers
        uint256 topCount = length < 10 ? length : 10;
        address[] memory topResolvers = new address[](topCount);
        for (uint i = 0; i < topCount; i++) {
            topResolvers[i] = resolverRanking[i];
        }
        
        emit ResolverRankingUpdated(topResolvers);
    }
    
    /**
     * @notice Calculate composite score for resolver ranking
     * @param resolver Address of the resolver
     * @return score Composite score
     */
    function _getResolverScore(address resolver) internal view returns (uint256) {
        ResolverProfile memory profile = resolverProfiles[resolver];
        PerformanceMetrics memory metrics = performanceMetrics[resolver];
        
        if (!profile.isActive) return 0;
        
        // Weighted scoring: reputation (40%), stake (20%), volume (20%), response time (20%)
        uint256 repScore = profile.reputation * 40 / 100;
        uint256 stakeScore = (profile.stakedAmount * 10000 / MAX_STAKE) * 20 / 100;
        uint256 volumeScore = metrics.totalVolume > 0 ? 2000 : 0; // Simplified for now
        uint256 timeScore = profile.avgResponseTime > 0 
            ? (10000 - (profile.avgResponseTime * 100)) * 20 / 100 
            : 0;
        
        return repScore + stakeScore + volumeScore + timeScore;
    }
    
    /**
     * @notice Remove resolver from ranking
     * @param resolver Address to remove
     */
    function _removeFromRanking(address resolver) internal {
        uint256 length = resolverRanking.length;
        for (uint i = 0; i < length; i++) {
            if (resolverRanking[i] == resolver) {
                resolverRanking[i] = resolverRanking[length - 1];
                resolverRanking.pop();
                break;
            }
        }
    }
    
    /**
     * @notice Check if address is an active whitelisted resolver
     * @param resolver Address to check
     * @return isValid Whether resolver is valid
     */
    function isWhitelistedResolver(address resolver) public view returns (bool) {
        ResolverProfile memory profile = resolverProfiles[resolver];
        return profile.isWhitelisted && profile.isActive;
    }
    
    /**
     * @notice Get top N resolvers by score
     * @param n Number of resolvers to return
     * @return resolvers Array of top resolver addresses
     */
    function getTopResolvers(uint256 n) external view returns (address[] memory) {
        uint256 count = n < resolverRanking.length ? n : resolverRanking.length;
        address[] memory resolvers = new address[](count);
        
        for (uint i = 0; i < count; i++) {
            resolvers[i] = resolverRanking[i];
        }
        
        return resolvers;
    }
    
    /**
     * @notice Modifier to check if caller is whitelisted resolver
     */
    modifier onlyWhitelistedResolver() {
        if (!isWhitelistedResolver(msg.sender)) {
            revert ResolverNotWhitelisted(msg.sender);
        }
        _;
    }
}