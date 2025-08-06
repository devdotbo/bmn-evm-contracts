// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

/**
 * @title BaseExtension
 * @notice Functional implementation for 1inch BaseExtension compatibility
 * @dev Provides post-interaction hooks with basic validation and event logging
 */
abstract contract BaseExtension {
    // Events for tracking interactions
    event InteractionExecuted(
        address indexed orderMaker,
        address indexed interactionTarget,
        bytes32 indexed interactionHash,
        uint256 timestamp
    );
    
    event InteractionFailed(
        address indexed orderMaker,
        address indexed interactionTarget,
        string reason
    );
    
    // State for tracking interaction history
    mapping(address => uint256) public lastInteractionTimestamp;
    mapping(bytes32 => bool) public processedInteractions;
    
    // Constants for rate limiting
    uint256 private constant MIN_INTERACTION_DELAY = 1; // 1 second minimum between interactions
    uint256 private constant MAX_INTERACTION_SIZE = 100000; // Max interaction data size in bytes
    
    /**
     * @notice Post-interaction hook with validation and logging
     * @dev Validates interaction parameters and logs the execution
     * @param orderMaker The address that created the order
     * @param interactionTarget The target contract for the interaction
     * @param interaction The interaction data to be processed
     */
    function _postInteraction(
        address orderMaker,
        address interactionTarget,
        bytes calldata interaction
    ) internal virtual {
        // Basic validation checks
        require(orderMaker != address(0), "BaseExtension: Invalid order maker");
        require(interactionTarget != address(0), "BaseExtension: Invalid interaction target");
        require(interaction.length > 0, "BaseExtension: Empty interaction data");
        require(interaction.length <= MAX_INTERACTION_SIZE, "BaseExtension: Interaction too large");
        
        // Rate limiting per maker
        uint256 lastTimestamp = lastInteractionTimestamp[orderMaker];
        if (lastTimestamp > 0) {
            require(
                block.timestamp >= lastTimestamp + MIN_INTERACTION_DELAY,
                "BaseExtension: Too frequent interactions"
            );
        }
        
        // Calculate interaction hash for deduplication
        bytes32 interactionHash = keccak256(
            abi.encodePacked(
                orderMaker,
                interactionTarget,
                interaction,
                block.timestamp / 60 // Group by minute to allow retries
            )
        );
        
        // Prevent duplicate processing within same time window
        require(
            !processedInteractions[interactionHash],
            "BaseExtension: Duplicate interaction"
        );
        
        // Mark as processed
        processedInteractions[interactionHash] = true;
        lastInteractionTimestamp[orderMaker] = block.timestamp;
        
        // Validate interaction target is a contract
        uint256 targetCodeSize;
        assembly {
            targetCodeSize := extcodesize(interactionTarget)
        }
        require(targetCodeSize > 0, "BaseExtension: Target is not a contract");
        
        // Execute any custom validation logic in derived contracts
        _validateInteraction(orderMaker, interactionTarget, interaction);
        
        // Emit success event
        emit InteractionExecuted(
            orderMaker,
            interactionTarget,
            interactionHash,
            block.timestamp
        );
    }
    
    /**
     * @notice Hook for custom validation in derived contracts
     * @dev Override this to add specific validation logic
     * @param orderMaker The address that created the order
     * @param interactionTarget The target contract for the interaction
     * @param interaction The interaction data to be validated
     */
    function _validateInteraction(
        address orderMaker,
        address interactionTarget,
        bytes calldata interaction
    ) internal virtual {
        // Default implementation - can be overridden by derived contracts
        // No additional validation by default
    }
    
    /**
     * @notice Check if an interaction has been processed
     * @param orderMaker The address that created the order
     * @param interactionTarget The target contract
     * @param interaction The interaction data
     * @return bool True if the interaction has been processed
     */
    function isInteractionProcessed(
        address orderMaker,
        address interactionTarget,
        bytes calldata interaction
    ) external view returns (bool) {
        bytes32 interactionHash = keccak256(
            abi.encodePacked(
                orderMaker,
                interactionTarget,
                interaction,
                block.timestamp / 60
            )
        );
        return processedInteractions[interactionHash];
    }
}