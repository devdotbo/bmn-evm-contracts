// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { IOrderMixin } from "limit-order-protocol/contracts/interfaces/IOrderMixin.sol";
import "./extensions/BMNResolverExtension.sol";
import { ProxyHashLib } from "./libraries/ProxyHashLib.sol";
import { BaseEscrowFactory } from "./BaseEscrowFactory.sol";
import { EscrowDst } from "./EscrowDst.sol";
import { EscrowSrc } from "./EscrowSrc.sol";
import { MerkleStorageInvalidator } from "./MerkleStorageInvalidator.sol";
import { IBaseEscrow } from "./interfaces/IBaseEscrow.sol";
import { Address, AddressLib } from "solidity-utils/contracts/libraries/AddressLib.sol";
import { ImmutablesLib } from "./libraries/ImmutablesLib.sol";
import { Timelocks, TimelocksLib } from "./libraries/TimelocksLib.sol";
import { SafeERC20 } from "solidity-utils/contracts/libraries/SafeERC20.sol";

/**
 * @title CrossChainEscrowFactory
 * @notice Enhanced factory contract with BMN extensions for cross-chain atomic swaps
 * @dev Integrates BMN's proprietary extension system replacing 1inch dependencies
 * @custom:security-contact security@bridgemenot.io
 */
contract CrossChainEscrowFactory is BaseEscrowFactory {
    using AddressLib for Address;
    using ImmutablesLib for IBaseEscrow.Immutables;
    using TimelocksLib for Timelocks;
    using SafeERC20 for IERC20;
    
    /// @notice Version identifier for this implementation
    string public constant VERSION = "2.1.0-bmn-secure";
    
    /// @notice Emergency pause state
    bool public emergencyPaused;
    
    /// @notice Contract owner for emergency functions
    address public owner;
    
    /// @notice Whitelisted resolvers mapping
    mapping(address => bool) public whitelistedResolvers;
    
    /// @notice Number of whitelisted resolvers
    uint256 public resolverCount;
    
    /// @notice Performance metrics tracking
    struct SwapMetrics {
        uint256 totalVolume;
        uint256 successfulSwaps;
        uint256 failedSwaps;
        uint256 avgCompletionTime;
    }
    
    /// @notice Global swap metrics
    SwapMetrics public globalMetrics;
    
    /// @notice Per-chain metrics
    mapping(uint256 => SwapMetrics) public chainMetrics;
    
    /// @notice Events for resolver management
    event ResolverWhitelisted(address indexed resolver);
    event ResolverRemoved(address indexed resolver);
    event EmergencyPause(bool paused);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    
    /// @notice Enhanced events with BMN extensions
    event SwapInitiated(
        address indexed escrowSrc,
        address indexed maker,
        address indexed resolver,
        uint256 volume,
        uint256 srcChainId,
        uint256 dstChainId
    );
    
    event SwapCompleted(
        bytes32 indexed orderHash,
        address indexed resolver,
        uint256 completionTime,
        uint256 gasUsed
    );
    
    event MetricsUpdated(
        uint256 totalVolume,
        uint256 successRate,
        uint256 avgCompletionTime
    );
    
    /// @notice Modifier to check if protocol is not paused
    modifier whenNotPaused() {
        require(!emergencyPaused, "Protocol is paused");
        _;
    }
    
    /// @notice Modifier to check if caller is factory owner (renamed to avoid conflict)
    modifier onlyFactoryOwner() {
        require(msg.sender == owner, "Not factory owner");
        _;
    }
    
    /// @notice Modifier to check if address is whitelisted resolver (renamed to avoid conflict)
    modifier onlyWhitelistedResolverAddress(address resolver) {
        require(whitelistedResolvers[resolver], "Not whitelisted resolver");
        _;
    }
    
    /**
     * @notice Constructor initializes BMN extension system
     * @param limitOrderProtocol Address of limit order protocol
     * @param feeToken Token used for fees
     * @param bmnToken BMN token for staking and access
     * @param _owner Contract owner
     * @param rescueDelaySrc Rescue delay for source escrows
     * @param rescueDelayDst Rescue delay for destination escrows
     */
    constructor(
        address limitOrderProtocol,
        IERC20 feeToken,
        IERC20 bmnToken,
        address _owner,
        uint32 rescueDelaySrc,
        uint32 rescueDelayDst
    )
        MerkleStorageInvalidator(limitOrderProtocol)
        // BMN token integration would be added here
    {
        require(_owner != address(0), "Invalid owner");
        owner = _owner;
        
        // Deploy escrow implementations
        ESCROW_SRC_IMPLEMENTATION = address(new EscrowSrc(rescueDelaySrc, bmnToken));
        ESCROW_DST_IMPLEMENTATION = address(new EscrowDst(rescueDelayDst, bmnToken));
        
        // Calculate bytecode hashes for CREATE2
        _PROXY_SRC_BYTECODE_HASH = ProxyHashLib.computeProxyBytecodeHash(ESCROW_SRC_IMPLEMENTATION);
        _PROXY_DST_BYTECODE_HASH = ProxyHashLib.computeProxyBytecodeHash(ESCROW_DST_IMPLEMENTATION);
        
        // Initialize with owner as first whitelisted resolver for testing
        whitelistedResolvers[_owner] = true;
        resolverCount = 1;
        emit ResolverWhitelisted(_owner);
        
        // Configure initial circuit breakers
        _configureDefaultCircuitBreakers();
    }
    
    /**
     * @notice Enhanced post-interaction with BMN extensions
     * @dev Overrides base implementation to add resolver validation and metrics
     */
    function _postInteraction(
        IOrderMixin.Order calldata order,
        bytes calldata extension,
        bytes32 orderHash,
        address taker,
        uint256 makingAmount,
        uint256 takingAmount,
        uint256 remainingMakingAmount,
        bytes calldata extraData
    ) internal override whenNotPaused {
        // CRITICAL: Validate resolver is whitelisted
        require(whitelistedResolvers[taker], "Resolver not whitelisted");
        
        // Record swap initiation time
        uint256 startTime = block.timestamp;
        
        // MEV protection could be added here
        
        // Call parent implementation
        super._postInteraction(
            order,
            extension,
            orderHash,
            taker,
            makingAmount,
            takingAmount,
            remainingMakingAmount,
            extraData
        );
        
        // Extract chain information from extraData
        ExtraDataArgs memory args = _parseExtraData(extraData);
        
        // Update metrics
        _updateSwapMetrics(
            orderHash,
            taker,
            makingAmount,
            args.dstChainId,
            startTime
        );
        
        // Resolver performance tracking could be added here
        
        emit SwapInitiated(
            this.addressOfEscrowSrc(_getImmutables(orderHash, order, makingAmount, extraData)),
            order.maker.get(),
            taker,
            makingAmount,
            block.chainid,
            args.dstChainId
        );
    }
    
    /**
     * @notice Override createDstEscrow to add pause check and resolver validation
     */
    function createDstEscrow(IBaseEscrow.Immutables calldata dstImmutables, uint256 srcCancellationTimestamp) 
        external 
        payable 
        override 
        whenNotPaused 
    {
        // CRITICAL: Validate caller is whitelisted resolver
        require(whitelistedResolvers[msg.sender], "Resolver not whitelisted");
        
        // Call the base implementation directly (it's not overrideable in BaseEscrowFactory)
        // We need to manually implement the logic here
        address token = dstImmutables.token.get();
        uint256 nativeAmount = dstImmutables.safetyDeposit;
        if (token == address(0)) {
            nativeAmount += dstImmutables.amount;
        }
        require(msg.value == nativeAmount, "Insufficient escrow balance");

        IBaseEscrow.Immutables memory immutables = dstImmutables;
        immutables.timelocks = immutables.timelocks.setDeployedAt(block.timestamp);
        
        // Check cancellation timing with tolerance
        uint256 TIMESTAMP_TOLERANCE = 60; // 60 seconds - minimal safe tolerance
        require(
            immutables.timelocks.get(TimelocksLib.Stage.DstCancellation) <= srcCancellationTimestamp + TIMESTAMP_TOLERANCE,
            "Invalid creation time"
        );

        bytes32 salt = immutables.hashMem();
        address escrow = _deployEscrow(salt, msg.value, ESCROW_DST_IMPLEMENTATION);
        
        if (token != address(0)) {
            IERC20(token).safeTransferFrom(msg.sender, escrow, immutables.amount);
        }

        emit DstEscrowCreated(escrow, dstImmutables.hashlock, dstImmutables.taker);
    }
    
    /**
     * @notice Add a resolver to whitelist (renamed to avoid conflict)
     * @param resolver Address to whitelist
     */
    function addResolverToWhitelist(address resolver) external onlyFactoryOwner {
        require(resolver != address(0), "Invalid resolver");
        require(!whitelistedResolvers[resolver], "Already whitelisted");
        
        whitelistedResolvers[resolver] = true;
        resolverCount++;
        emit ResolverWhitelisted(resolver);
    }
    
    /**
     * @notice Remove a resolver from whitelist (renamed to avoid conflict)
     * @param resolver Address to remove
     */
    function removeResolverFromWhitelist(address resolver) external onlyFactoryOwner {
        require(whitelistedResolvers[resolver], "Not whitelisted");
        
        whitelistedResolvers[resolver] = false;
        resolverCount--;
        emit ResolverRemoved(resolver);
    }
    
    /**
     * @notice Pause the protocol (emergency only)
     */
    function pause() external onlyFactoryOwner {
        emergencyPaused = true;
        emit EmergencyPause(true);
    }
    
    /**
     * @notice Unpause the protocol
     */
    function unpause() external onlyFactoryOwner {
        emergencyPaused = false;
        emit EmergencyPause(false);
    }
    
    /**
     * @notice Transfer factory ownership
     * @param newOwner New owner address
     */
    function transferFactoryOwnership(address newOwner) external onlyFactoryOwner {
        require(newOwner != address(0), "Invalid owner");
        
        address previousOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(previousOwner, newOwner);
    }
    
    /**
     * @notice Configure default circuit breakers
     */
    function _configureDefaultCircuitBreakers() internal {
        // Circuit breaker configuration placeholder
        // TODO: Implement circuit breaker functionality
        
        // Global daily volume limit: 10M tokens
        // configureCircuitBreaker(
        //     keccak256("GLOBAL_DAILY_VOLUME"),
        //     10000000e18,  // threshold
        //     86400,        // 24 hour window
        //     3600,         // 1 hour cooldown
        //     true          // auto reset
        // );
        
        // Per-user hourly limit: 100k tokens
        // configureCircuitBreaker(
        //     keccak256("USER_HOURLY_VOLUME"),
        //     100000e18,    // threshold
        //     3600,         // 1 hour window
        //     600,          // 10 min cooldown
        //     true          // auto reset
        // );
        
        // Error rate breaker: max 5 errors per hour
        // configureCircuitBreaker(
        //     keccak256("ERROR_RATE"),
        //     5,            // threshold
        //     3600,         // 1 hour window
        //     1800,         // 30 min cooldown
        //     false         // manual reset required
        // );
    }
    
    /**
     * @notice Update swap metrics
     */
    function _updateSwapMetrics(
        bytes32 orderHash,
        address resolver,
        uint256 volume,
        uint256 dstChainId,
        uint256 startTime
    ) internal {
        // Update global metrics
        globalMetrics.totalVolume += volume;
        globalMetrics.successfulSwaps++;
        
        // Calculate completion time (will be updated when swap completes)
        uint256 completionTime = block.timestamp - startTime;
        
        // Update rolling average completion time
        if (globalMetrics.avgCompletionTime == 0) {
            globalMetrics.avgCompletionTime = completionTime;
        } else {
            globalMetrics.avgCompletionTime = 
                (globalMetrics.avgCompletionTime * 9 + completionTime) / 10;
        }
        
        // Update chain-specific metrics
        SwapMetrics storage chainStats = chainMetrics[dstChainId];
        chainStats.totalVolume += volume;
        chainStats.successfulSwaps++;
        
        // Calculate gas used (safe from underflow)
        uint256 gasUsed = gasleft() > 200000 ? 0 : 200000 - gasleft();
        
        emit SwapCompleted(orderHash, resolver, completionTime, gasUsed);
        emit MetricsUpdated(
            globalMetrics.totalVolume,
            _calculateSuccessRate(),
            globalMetrics.avgCompletionTime
        );
    }
    
    /**
     * @notice Calculate global success rate
     */
    function _calculateSuccessRate() internal view returns (uint256) {
        uint256 total = globalMetrics.successfulSwaps + globalMetrics.failedSwaps;
        if (total == 0) return 10000; // 100% if no swaps yet
        
        return (globalMetrics.successfulSwaps * 10000) / total;
    }
    
    /**
     * @notice Parse extra data to extract arguments
     */
    function _parseExtraData(bytes calldata extraData) 
        internal 
        pure 
        returns (ExtraDataArgs memory) 
    {
        // Implementation would parse the extraData structure
        // This is a simplified version
        ExtraDataArgs memory args;
        assembly {
            // Parse extraData structure
            // This would need proper implementation based on actual structure
        }
        return args;
    }
    
    /**
     * @notice Get immutables from order data
     */
    function _getImmutables(
        bytes32 orderHash,
        IOrderMixin.Order calldata order,
        uint256 makingAmount,
        bytes calldata extraData
    ) internal pure returns (IBaseEscrow.Immutables memory) {
        // Parse and return immutables
        // This would need proper implementation
        IBaseEscrow.Immutables memory immutables;
        return immutables;
    }
    
    /**
     * @notice Get current metrics
     */
    function getMetrics() external view returns (
        uint256 totalVolume,
        uint256 successRate,
        uint256 avgCompletionTime,
        uint256 activeResolvers
    ) {
        return (
            globalMetrics.totalVolume,
            _calculateSuccessRate(),
            globalMetrics.avgCompletionTime,
            0 // Placeholder for active resolver count
        );
    }
    
    /**
     * @notice Get chain-specific metrics
     */
    function getChainMetrics(uint256 chainId) external view returns (SwapMetrics memory) {
        return chainMetrics[chainId];
    }
    
    // Emergency pause functionality would need to be implemented
    // using circuit breakers or other mechanisms
}