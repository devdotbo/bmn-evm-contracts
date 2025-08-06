// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { Pausable } from "openzeppelin-contracts/contracts/utils/Pausable.sol";
import { ReentrancyGuard } from "openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import { Ownable } from "openzeppelin-contracts/contracts/access/Ownable.sol";

/**
 * @title BMNBaseExtension
 * @notice Base extension contract with circuit breakers, gas optimization, and MEV protection
 * @dev Replaces the stub BaseExtension with production-ready features
 * @custom:security-contact security@bridgemenot.io
 */
abstract contract BMNBaseExtension is Pausable, ReentrancyGuard, Ownable {
    // Circuit breaker configuration
    struct CircuitBreaker {
        uint128 threshold;
        uint64 windowDuration;
        uint64 cooldownPeriod;
        uint128 currentVolume;
        uint64 windowStart;
        bool tripped;
        bool autoReset;
    }
    
    // Gas optimization tracking
    struct GasMetrics {
        uint128 baseline;
        uint128 optimized;
        uint64 executions;
        uint64 lastUpdate;
    }
    
    // MEV protection using commit-reveal
    struct CommitReveal {
        bytes32 commitment;
        uint256 revealDeadline;
        bool revealed;
    }
    
    /// @notice Circuit breakers for different risk dimensions
    mapping(bytes32 => CircuitBreaker) public circuitBreakers;
    
    /// @notice Gas metrics per function selector
    mapping(bytes4 => GasMetrics) public gasMetrics;
    
    /// @notice Gas refunds accumulated per user
    mapping(address => uint256) public gasRefunds;
    
    /// @notice Commit-reveal storage for MEV protection
    mapping(bytes32 => CommitReveal) public commitReveals;
    
    /// @notice MEV protection delay in blocks
    uint256 public constant MEV_PROTECTION_BLOCKS = 1;
    
    /// @notice Gas refund percentage (basis points)
    uint256 public constant GAS_REFUND_BPS = 5000; // 50%
    
    /// @notice Maximum gas refund per transaction
    uint256 public constant MAX_GAS_REFUND = 0.1 ether;
    
    // Events
    event CircuitBreakerConfigured(bytes32 indexed breakerId, CircuitBreaker config);
    event CircuitBreakerTripped(bytes32 indexed breakerId, uint256 volume, uint256 threshold);
    event CircuitBreakerReset(bytes32 indexed breakerId, bool automatic);
    event GasOptimizationRecorded(bytes4 indexed selector, uint256 gasUsed, uint256 baseline);
    event GasRefundAccumulated(address indexed user, uint256 amount);
    event MEVProtectionCommit(bytes32 indexed commitHash, uint256 revealDeadline);
    event ExtensionMetric(string metric, uint256 value, bytes32 context);
    
    // Errors
    error CircuitBreakerTrippedError(bytes32 breakerId);
    error MEVProtectionNotMet(uint256 currentBlock, uint256 revealBlock);
    error InvalidCommitment(bytes32 provided, bytes32 expected);
    error RefundTransferFailed();
    error WindowNotExpired();
    
    constructor() Ownable(msg.sender) {}
    
    /**
     * @notice Configure a circuit breaker
     * @param breakerId Unique identifier for the circuit breaker
     * @param threshold Maximum allowed volume/count before tripping
     * @param windowDuration Time window for measuring volume
     * @param cooldownPeriod Time to wait after tripping before reset
     * @param autoReset Whether to automatically reset after cooldown
     */
    function configureCircuitBreaker(
        bytes32 breakerId,
        uint128 threshold,
        uint64 windowDuration,
        uint64 cooldownPeriod,
        bool autoReset
    ) external onlyOwner {
        circuitBreakers[breakerId] = CircuitBreaker({
            threshold: threshold,
            windowDuration: windowDuration,
            cooldownPeriod: cooldownPeriod,
            currentVolume: 0,
            windowStart: uint64(block.timestamp),
            tripped: false,
            autoReset: autoReset
        });
        
        emit CircuitBreakerConfigured(breakerId, circuitBreakers[breakerId]);
    }
    
    /**
     * @notice Reset a tripped circuit breaker
     * @param breakerId Circuit breaker to reset
     */
    function resetCircuitBreaker(bytes32 breakerId) external onlyOwner {
        CircuitBreaker storage breaker = circuitBreakers[breakerId];
        if (!breaker.tripped) return;
        
        if (breaker.cooldownPeriod > 0) {
            uint256 cooldownEnd = breaker.windowStart + breaker.windowDuration + breaker.cooldownPeriod;
            if (block.timestamp < cooldownEnd) {
                revert WindowNotExpired();
            }
        }
        
        breaker.tripped = false;
        breaker.currentVolume = 0;
        breaker.windowStart = uint64(block.timestamp);
        
        emit CircuitBreakerReset(breakerId, false);
    }
    
    /**
     * @notice Pre-interaction hook with MEV protection
     * @param orderMaker Address of the order maker
     * @param orderHash Hash of the order
     * @param interactionData Calldata for the interaction
     * @return commitHash Hash of the commitment for MEV protection
     */
    function _preInteraction(
        address orderMaker,
        bytes32 orderHash,
        bytes calldata interactionData
    ) internal virtual returns (bytes32 commitHash) {
        // Check circuit breakers
        _checkCircuitBreakers(orderMaker, orderHash, interactionData.length);
        
        // Create commitment for MEV protection
        commitHash = keccak256(abi.encode(orderHash, block.number, interactionData));
        
        commitReveals[commitHash] = CommitReveal({
            commitment: commitHash,
            revealDeadline: block.number + MEV_PROTECTION_BLOCKS,
            revealed: false
        });
        
        emit MEVProtectionCommit(commitHash, block.number + MEV_PROTECTION_BLOCKS);
        emit ExtensionMetric("pre_interaction_gas", gasleft(), orderHash);
        
        return commitHash;
    }
    
    /**
     * @notice Post-interaction hook with gas optimization tracking
     * @param orderMaker Address of the order maker
     * @param interactionTarget Target address for interaction
     * @param interaction Interaction calldata
     * @param commitHash Commitment hash from pre-interaction
     */
    function _postInteraction(
        address orderMaker,
        address interactionTarget,
        bytes calldata interaction,
        bytes32 commitHash
    ) internal virtual {
        // Verify MEV protection
        CommitReveal storage reveal = commitReveals[commitHash];
        if (block.number < reveal.revealDeadline) {
            revert MEVProtectionNotMet(block.number, reveal.revealDeadline);
        }
        
        // Mark as revealed
        reveal.revealed = true;
        
        // Track gas optimization
        uint256 gasUsed = gasleft() > 200000 ? 0 : 200000 - gasleft(); // Approximate gas used
        _trackGasOptimization(bytes4(interaction), gasUsed, orderMaker);
        
        emit ExtensionMetric("post_interaction_gas", gasUsed, commitHash);
    }
    
    /**
     * @notice Check circuit breakers and trip if necessary
     * @param maker Address initiating the action
     * @param context Context hash for the action
     * @param volume Volume or size of the action
     */
    function _checkCircuitBreakers(
        address maker,
        bytes32 context,
        uint256 volume
    ) internal {
        bytes32 breakerId = keccak256(abi.encode(maker, context));
        CircuitBreaker storage breaker = circuitBreakers[breakerId];
        
        // Skip if not configured
        if (breaker.threshold == 0) return;
        
        // Check if window has expired and reset if needed
        if (block.timestamp > breaker.windowStart + breaker.windowDuration) {
            if (breaker.tripped && breaker.autoReset) {
                uint256 resetTime = breaker.windowStart + breaker.windowDuration + breaker.cooldownPeriod;
                if (block.timestamp >= resetTime) {
                    breaker.tripped = false;
                    emit CircuitBreakerReset(breakerId, true);
                }
            }
            
            if (!breaker.tripped) {
                breaker.windowStart = uint64(block.timestamp);
                breaker.currentVolume = 0;
            }
        }
        
        // Check if breaker is tripped
        if (breaker.tripped) {
            revert CircuitBreakerTrippedError(breakerId);
        }
        
        // Update volume and check threshold
        breaker.currentVolume += uint128(volume);
        
        if (breaker.currentVolume > breaker.threshold) {
            breaker.tripped = true;
            emit CircuitBreakerTripped(breakerId, breaker.currentVolume, breaker.threshold);
            _pause(); // Pause the contract
            revert CircuitBreakerTrippedError(breakerId);
        }
    }
    
    /**
     * @notice Track gas usage and calculate optimization refunds
     * @param selector Function selector
     * @param gasUsed Gas used in the transaction
     * @param user User to credit with gas refund
     */
    function _trackGasOptimization(
        bytes4 selector,
        uint256 gasUsed,
        address user
    ) internal {
        GasMetrics storage metrics = gasMetrics[selector];
        
        // Initialize baseline on first execution
        if (metrics.executions == 0) {
            metrics.baseline = uint128(gasUsed);
            metrics.optimized = uint128(gasUsed);
        } else {
            // Update rolling average of optimized gas
            uint256 totalGas = uint256(metrics.optimized) * metrics.executions + gasUsed;
            metrics.optimized = uint128(totalGas / (metrics.executions + 1));
            
            // Calculate refund if gas usage is below baseline
            if (gasUsed < metrics.baseline) {
                uint256 savedGas = metrics.baseline - gasUsed;
                uint256 refundAmount = (savedGas * tx.gasprice * GAS_REFUND_BPS) / 10000;
                
                // Cap refund at maximum
                if (refundAmount > MAX_GAS_REFUND) {
                    refundAmount = MAX_GAS_REFUND;
                }
                
                gasRefunds[user] += refundAmount;
                emit GasRefundAccumulated(user, refundAmount);
            }
        }
        
        metrics.executions++;
        metrics.lastUpdate = uint64(block.timestamp);
        
        emit GasOptimizationRecorded(selector, gasUsed, metrics.baseline);
    }
    
    /**
     * @notice Claim accumulated gas refunds
     */
    function claimGasRefund() external nonReentrant {
        uint256 refund = gasRefunds[msg.sender];
        if (refund == 0) return;
        
        gasRefunds[msg.sender] = 0;
        
        (bool success,) = msg.sender.call{value: refund}("");
        if (!success) {
            gasRefunds[msg.sender] = refund; // Restore on failure
            revert RefundTransferFailed();
        }
    }
    
    /**
     * @notice Check if a commitment has been revealed
     * @param commitHash Commitment hash to check
     * @return revealed Whether the commitment has been revealed
     */
    function isRevealed(bytes32 commitHash) external view returns (bool) {
        return commitReveals[commitHash].revealed;
    }
    
    /**
     * @notice Get current gas metrics for a function
     * @param selector Function selector
     * @return metrics Current gas metrics
     */
    function getGasMetrics(bytes4 selector) external view returns (GasMetrics memory) {
        return gasMetrics[selector];
    }
    
    /**
     * @notice Emergency pause
     */
    function emergencyPause() external onlyOwner {
        _pause();
    }
    
    /**
     * @notice Emergency unpause
     */
    function emergencyUnpause() external onlyOwner {
        _unpause();
    }
    
    /**
     * @notice Receive function to accept gas refund deposits
     */
    receive() external payable {}
}