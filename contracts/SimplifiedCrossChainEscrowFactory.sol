// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { IOrderMixin } from "limit-order-protocol/contracts/interfaces/IOrderMixin.sol";
import { ProxyHashLib } from "./libraries/ProxyHashLib.sol";
import { BaseEscrowFactory } from "./BaseEscrowFactory.sol";
import { EscrowDst } from "./EscrowDst.sol";
import { EscrowSrc } from "./EscrowSrc.sol";
import { MerkleStorageInvalidator } from "./MerkleStorageInvalidator.sol";
import { IBaseEscrow } from "./interfaces/IBaseEscrow.sol";
import { Address } from "solidity-utils/contracts/libraries/AddressLib.sol";

/**
 * @title SimplifiedCrossChainEscrowFactory
 * @notice Simplified factory with working resolver validation for cross-chain atomic swaps
 * @dev Uses the functional stub extensions for immediate deployment
 * @custom:security-contact security@bridgemenot.io
 */
contract SimplifiedCrossChainEscrowFactory is BaseEscrowFactory {
    /// @notice Version identifier for this implementation
    string public constant VERSION = "1.2.0-simplified";
    
    /// @notice Track total volume for basic metrics
    uint256 public totalVolume;
    uint256 public totalSwaps;
    
    /// @notice Custom errors
    error ResolverNotWhitelisted(address resolver);
    error InvalidChainId(uint256 chainId);
    
    /// @notice Events
    event SwapInitiated(
        address indexed escrowSrc,
        address indexed maker,
        address indexed resolver,
        uint256 volume,
        uint256 srcChainId,
        uint256 dstChainId
    );
    
    event ResolverWhitelisted(address indexed resolver, address indexed admin);
    event ResolverRemoved(address indexed resolver, address indexed admin);
    
    /**
     * @notice Constructor initializes the factory
     * @param limitOrderProtocol Address of limit order protocol
     * @param feeToken Token used for fees (not used in simplified version)
     * @param accessToken Token for access control
     * @param owner Contract owner
     * @param rescueDelaySrc Rescue delay for source escrows
     * @param rescueDelayDst Rescue delay for destination escrows
     */
    constructor(
        address limitOrderProtocol,
        IERC20 feeToken,
        IERC20 accessToken,
        address owner,
        uint32 rescueDelaySrc,
        uint32 rescueDelayDst
    )
        MerkleStorageInvalidator(limitOrderProtocol)
    {
        // Initialize resolver validation extension
        _initializeResolverExtension();
        
        // Deploy escrow implementations
        ESCROW_SRC_IMPLEMENTATION = address(new EscrowSrc(rescueDelaySrc, accessToken));
        ESCROW_DST_IMPLEMENTATION = address(new EscrowDst(rescueDelayDst, accessToken));
        
        // Calculate bytecode hashes for CREATE2
        _PROXY_SRC_BYTECODE_HASH = ProxyHashLib.computeProxyBytecodeHash(ESCROW_SRC_IMPLEMENTATION);
        _PROXY_DST_BYTECODE_HASH = ProxyHashLib.computeProxyBytecodeHash(ESCROW_DST_IMPLEMENTATION);
        
        // Transfer ownership if needed
        if (owner != msg.sender) {
            _owner = owner;
            admins[owner] = true;
            emit AdminAdded(owner);
        }
        
        // Whitelist the deployer as initial resolver
        // Note: addResolver is internal, so we directly modify state
        resolvers[msg.sender] = ResolverInfo({
            isWhitelisted: true,
            isActive: true,
            addedAt: block.timestamp,
            suspendedUntil: 0,
            totalTransactions: 0,
            failedTransactions: 0,
            addedBy: msg.sender
        });
        resolverList.push(msg.sender);
    }
    
    /**
     * @notice Enhanced post-interaction with resolver validation
     * @dev Overrides base implementation to add resolver validation
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
    ) internal override {
        // Validate resolver
        if (!isWhitelistedResolver(taker)) {
            revert ResolverNotWhitelisted(taker);
        }
        
        // Update metrics
        totalVolume += makingAmount;
        totalSwaps++;
        
        // Call parent implementation for core escrow logic
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
        
        // Record successful transaction for resolver
        _recordResolverTransaction(taker, true);
        
        // Emit simplified event (we don't have all the complex data extraction)
        emit SwapInitiated(
            address(0), // Escrow address will be computed by indexers
            order.maker,
            taker,
            makingAmount,
            block.chainid,
            0 // Destination chain ID would need to be extracted from extraData
        );
    }
    
    /**
     * @notice Create destination escrow with resolver validation
     * @dev Overrides base to add resolver checks
     */
    function createDstEscrow(
        IBaseEscrow.Immutables calldata dstImmutables,
        uint256 srcCancellationTimestamp
    ) external payable override {
        // Validate resolver (taker is the resolver)
        address resolver = dstImmutables.taker.get();
        if (!isWhitelistedResolver(resolver)) {
            revert ResolverNotWhitelisted(resolver);
        }
        
        // Call parent implementation
        super.createDstEscrow(dstImmutables, srcCancellationTimestamp);
        
        // Record successful transaction
        _recordResolverTransaction(resolver, true);
    }
    
    /**
     * @notice Get metrics
     * @return _totalVolume Total volume processed
     * @return _totalSwaps Total number of swaps
     * @return _activeResolvers Number of active resolvers
     */
    function getMetrics() external view returns (
        uint256 _totalVolume,
        uint256 _totalSwaps,
        uint256 _activeResolvers
    ) {
        _totalVolume = totalVolume;
        _totalSwaps = totalSwaps;
        
        // Count active resolvers - simplified version
        uint256 count = 0;
        for (uint i = 0; i < resolverList.length; i++) {
            if (isWhitelistedResolver(resolverList[i])) {
                count++;
            }
        }
        _activeResolvers = count;
    }
    
    /**
     * @notice Check if address is valid resolver (public wrapper)
     * @param resolver Address to check
     * @return bool True if valid
     */
    function isValidResolver(address resolver) external view returns (bool) {
        return isWhitelistedResolver(resolver);
    }
}