// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

/// @notice EIP712 domain separator struct (as in the referenced example)
struct EIP712Domain {
    string name;
    string version;
    uint256 chainId;
    address verifyingContract;
    bytes32 salt;
}

/// @notice Example typed data message (as in the referenced example)
struct ExampleMessage {
    string message;
    uint256 value;
    address from;
    address to;
}

/// @title EIP712Example
/// @notice Minimal EIP-712 implementation matching the Medium article example
contract EIP712Example {
    bytes32 private DOMAIN_SEPARATOR;
    // Note: Using a literal here mirrors the article; ensure length <= 32 bytes.
    bytes32 private constant SALT = "pseudo-text";

    constructor() {
        DOMAIN_SEPARATOR = _hashDomain(
            EIP712Domain({
                name: "EIP712Example",
                version: "1",
                chainId: block.chainid,
                verifyingContract: address(this),
                salt: SALT
            })
        );
    }

    /// @notice Verifies a typed ExampleMessage signature (v,r,s form)
    function verifyMessage(
        ExampleMessage memory message,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public view returns (bool) {
        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, _hashMessage(message))
        );

        address recovered = ecrecover(digest, v, r, s);
        return recovered == message.from;
    }

    /// @notice Verifies a typed ExampleMessage signature (bytes signature form)
    function verifyMessage(
        ExampleMessage memory message,
        bytes calldata signature
    ) external view returns (bool) {
        require(signature.length == 65, "Invalid sig length");
        bytes32 r;
        bytes32 s;
        uint8 v;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            r := calldataload(signature.offset)
            s := calldataload(add(signature.offset, 32))
            v := byte(0, calldataload(add(signature.offset, 64)))
        }
        return verifyMessage(message, v, r, s);
    }

    function _hashDomain(EIP712Domain memory domain) private pure returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract,bytes32 salt)"
                ),
                keccak256(bytes(domain.name)),
                keccak256(bytes(domain.version)),
                domain.chainId,
                domain.verifyingContract,
                domain.salt
            )
        );
    }

    function _hashMessage(ExampleMessage memory message) private pure returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256(
                    bytes(
                        "ExampleMessage(string message,uint256 value,address from,address to)"
                    )
                ),
                keccak256(bytes(message.message)),
                message.value,
                message.from,
                message.to
            )
        );
    }
}


