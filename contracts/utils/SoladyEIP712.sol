// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @notice Minimal Solady-style EIP-712 typed structured data hashing and signing.
/// @dev Adapted from Solady's EIP712 implementation:
/// https://raw.githubusercontent.com/vectorized/solady/refs/heads/main/src/utils/EIP712.sol
abstract contract SoladyEIP712 {
    // keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)")
    bytes32 internal constant _DOMAIN_TYPEHASH =
        bytes32(0x8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f);

    uint256 private immutable _cachedThis;
    uint256 private immutable _cachedChainId;
    bytes32 private immutable _cachedNameHash;
    bytes32 private immutable _cachedVersionHash;
    bytes32 private immutable _cachedDomainSeparator;

    constructor() {
        _cachedThis = uint256(uint160(address(this)));
        _cachedChainId = block.chainid;
        (string memory name, string memory version) = _domainNameAndVersion();
        bytes32 nameHash = keccak256(bytes(name));
        bytes32 versionHash = keccak256(bytes(version));
        _cachedNameHash = nameHash;
        _cachedVersionHash = versionHash;
        _cachedDomainSeparator = keccak256(
            abi.encode(_DOMAIN_TYPEHASH, nameHash, versionHash, block.chainid, address(this))
        );
    }

    /// @dev Override to return the domain name and version.
    function _domainNameAndVersion() internal view virtual returns (string memory name, string memory version);

    function _domainSeparator() internal view returns (bytes32 separator) {
        separator = _cachedDomainSeparator;
        if (_cachedDomainSeparatorInvalidated()) {
            bytes32 nameHash = _cachedNameHash;
            bytes32 versionHash = _cachedVersionHash;
            separator = keccak256(
                abi.encode(_DOMAIN_TYPEHASH, nameHash, versionHash, block.chainid, address(this))
            );
        }
    }

    function _hashTypedData(bytes32 structHash) internal view returns (bytes32 digest) {
        bytes32 separator = _domainSeparator();
        digest = keccak256(abi.encodePacked("\x19\x01", separator, structHash));
    }

    function _cachedDomainSeparatorInvalidated() private view returns (bool result) {
        uint256 cachedChainId = _cachedChainId;
        uint256 cachedThis = _cachedThis;
        assembly {
            result := iszero(and(eq(chainid(), cachedChainId), eq(address(), cachedThis)))
        }
    }
}


