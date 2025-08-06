// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "./BaseExtension.sol";

/**
 * @title ResolverValidationExtension
 * @notice Stub implementation for 1inch ResolverValidationExtension
 * @dev This is a minimal implementation for compilation purposes
 */
abstract contract ResolverValidationExtension is BaseExtension {
    /**
     * @notice Validates if an address is a whitelisted resolver
     * @param resolver The address to validate
     * @return bool True if the resolver is whitelisted
     */
    function isWhitelistedResolver(address resolver) public view virtual returns (bool) {
        // In production, this would check against a whitelist
        // For now, return true for any non-zero address
        return resolver != address(0);
    }
    
    /**
     * @notice Modifier to check if msg.sender is a whitelisted resolver
     */
    modifier onlyWhitelistedResolver() {
        require(isWhitelistedResolver(msg.sender), "Not a whitelisted resolver");
        _;
    }
}