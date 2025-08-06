// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import { BaseExtension } from "./stubs/extensions/BaseExtension.sol";
import { ResolverValidationExtension } from "./stubs/extensions/ResolverValidationExtension.sol";

import { ProxyHashLib } from "./libraries/ProxyHashLib.sol";
import { BaseEscrowFactory } from "./BaseEscrowFactory.sol";
import { MerkleStorageInvalidator } from "./MerkleStorageInvalidator.sol";

/**
 * @title CrossChainEscrowFactory
 * @notice Factory that accepts pre-deployed implementations for cross-chain consistency
 * @dev Use this with CREATE2-deployed implementations to ensure same addresses on all chains
 * @custom:security-contact security@1inch.io
 */
contract CrossChainEscrowFactory is BaseEscrowFactory {
    constructor(
        address limitOrderProtocol,
        IERC20 feeToken,
        IERC20 accessToken,
        address owner,
        address srcImplementation,
        address dstImplementation
    )
    MerkleStorageInvalidator(limitOrderProtocol) {
        // Note: In production, BaseExtension and ResolverValidationExtension would have constructors
        // Our stub implementations don't require initialization
        require(srcImplementation != address(0), "Invalid SRC implementation");
        require(dstImplementation != address(0), "Invalid DST implementation");
        
        ESCROW_SRC_IMPLEMENTATION = srcImplementation;
        ESCROW_DST_IMPLEMENTATION = dstImplementation;
        _PROXY_SRC_BYTECODE_HASH = ProxyHashLib.computeProxyBytecodeHash(ESCROW_SRC_IMPLEMENTATION);
        _PROXY_DST_BYTECODE_HASH = ProxyHashLib.computeProxyBytecodeHash(ESCROW_DST_IMPLEMENTATION);
    }
}