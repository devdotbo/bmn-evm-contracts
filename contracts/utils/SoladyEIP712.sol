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

        bytes32 separator;
        assembly {
            let m := mload(0x40)
            mstore(m, _DOMAIN_TYPEHASH)
            mstore(add(m, 0x20), nameHash)
            mstore(add(m, 0x40), versionHash)
            mstore(add(m, 0x60), chainid())
            mstore(add(m, 0x80), address())
            separator := keccak256(m, 0xa0)
        }
        _cachedDomainSeparator = separator;
    }

    /// @dev Override to return the domain name and version.
    function _domainNameAndVersion() internal view virtual returns (string memory name, string memory version);

    function _domainSeparator() internal view returns (bytes32 separator) {
        separator = _cachedDomainSeparator;
        if (_cachedDomainSeparatorInvalidated()) {
            bytes32 nameHash = _cachedNameHash;
            bytes32 versionHash = _cachedVersionHash;
            assembly {
                let m := mload(0x40)
                mstore(m, _DOMAIN_TYPEHASH)
                mstore(add(m, 0x20), nameHash)
                mstore(add(m, 0x40), versionHash)
                mstore(add(m, 0x60), chainid())
                mstore(add(m, 0x80), address())
                separator := keccak256(m, 0xa0)
            }
        }
    }

    function _hashTypedData(bytes32 structHash) internal view returns (bytes32 digest) {
        bytes32 separator = _domainSeparator();
        assembly {
            mstore(0x00, 0x1901000000000000)
            mstore(0x1a, separator)
            mstore(0x3a, structHash)
            digest := keccak256(0x18, 0x42)
            mstore(0x3a, 0)
        }
    }

    function _cachedDomainSeparatorInvalidated() private view returns (bool result) {
        uint256 cachedChainId = _cachedChainId;
        uint256 cachedThis = _cachedThis;
        assembly {
            result := iszero(and(eq(chainid(), cachedChainId), eq(address(), cachedThis)))
        }
    }
}


