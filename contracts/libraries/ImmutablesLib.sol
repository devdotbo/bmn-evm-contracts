// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import { IBaseEscrow } from "../interfaces/IBaseEscrow.sol";

/**
 * @title Library for escrow immutables.
 * @custom:security-contact security@1inch.io
 */
library ImmutablesLib {
    /**
     * @notice Returns the hash of the immutables.
     * @dev Now uses abi.encode to properly handle the dynamic bytes field
     * @param immutables The immutables to hash.
     * @return The computed hash.
     */
    function hash(IBaseEscrow.Immutables calldata immutables) internal pure returns(bytes32) {
        return keccak256(abi.encode(immutables));
    }

    /**
     * @notice Returns the hash of the immutables.
     * @dev Now uses abi.encode to properly handle the dynamic bytes field
     * @param immutables The immutables to hash.
     * @return The computed hash.
     */
    function hashMem(IBaseEscrow.Immutables memory immutables) internal pure returns(bytes32) {
        return keccak256(abi.encode(immutables));
    }
}
