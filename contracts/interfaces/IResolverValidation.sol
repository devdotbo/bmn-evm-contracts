// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

interface IResolverValidation {
    function isWhitelistedResolver(address resolver) external view returns (bool);
}


