// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

/**
 * @title BaseExtension
 * @notice Stub implementation for 1inch BaseExtension
 * @dev This is a minimal implementation for compilation purposes
 */
abstract contract BaseExtension {
    /**
     * @notice Virtual function for post-interaction hook
     * @dev Override this in derived contracts to add custom logic
     */
    function _postInteraction(
        address /*orderMaker*/,
        address /*interactionTarget*/,
        bytes calldata /*interaction*/
    ) internal virtual {
        // Default implementation - do nothing
    }
}