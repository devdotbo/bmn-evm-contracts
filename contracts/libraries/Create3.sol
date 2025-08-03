//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.23;

/**
  @title A library for deploying contracts EIP-3171 style.
  @author Agustin Aguilar <aa@horizon.io>
  @notice Deterministic deployments using CREATE3 pattern
  @dev Deployment addresses depend only on deployer + salt, not on bytecode
*/
library Create3 {
    error ErrorCreatingProxy();
    error ErrorCreatingContract();
    error TargetAlreadyExists();

    // Proxy bytecode that deploys the actual contract
    bytes internal constant PROXY_CHILD_BYTECODE = hex"67_36_3d_3d_37_36_3d_34_f0_3d_52_60_08_60_18_f3";

    // Keccak256 hash of the proxy bytecode
    bytes32 internal constant KECCAK256_PROXY_CHILD_BYTECODE = 0x21c35dbe1b344a2488cf3321d6ce542f8e9f305544ff09e4993a62319a497c1f;

    /**
     * @notice Get code size at address
     * @param _addr Address to check
     * @return size Code size at address
     */
    function codeSize(address _addr) internal view returns (uint256 size) {
        assembly { 
            size := extcodesize(_addr) 
        }
    }

    /**
     * @notice Deploy contract using CREATE3
     * @param _salt Salt for deterministic deployment
     * @param _creationCode Contract creation code (with constructor args)
     * @return addr Deployed contract address
     */
    function create3(bytes32 _salt, bytes memory _creationCode) internal returns (address addr) {
        return create3(_salt, _creationCode, 0);
    }

    /**
     * @notice Deploy contract using CREATE3 with ETH value
     * @param _salt Salt for deterministic deployment
     * @param _creationCode Contract creation code (with constructor args)
     * @param _value ETH value to send with deployment
     * @return addr Deployed contract address
     */
    function create3(bytes32 _salt, bytes memory _creationCode, uint256 _value) internal returns (address addr) {
        bytes memory creationCode = PROXY_CHILD_BYTECODE;

        // Get expected deployment address
        addr = addressOf(_salt);
        
        // Check if already deployed
        if (codeSize(addr) != 0) revert TargetAlreadyExists();

        // Deploy proxy using CREATE2
        address proxy;
        assembly { 
            proxy := create2(0, add(creationCode, 32), mload(creationCode), _salt)
        }
        if (proxy == address(0)) revert ErrorCreatingProxy();

        // Proxy deploys the actual contract using CREATE
        (bool success,) = proxy.call{ value: _value }(_creationCode);
        if (!success || codeSize(addr) == 0) revert ErrorCreatingContract();
    }

    /**
     * @notice Calculate deployment address for given salt
     * @param _salt Salt for deterministic deployment
     * @return Deployment address
     */
    function addressOf(bytes32 _salt) internal view returns (address) {
        address proxy = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            bytes1(0xff),
                            address(this),
                            _salt,
                            KECCAK256_PROXY_CHILD_BYTECODE
                        )
                    )
                )
            )
        );

        return address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            bytes1(0xd6),
                            bytes1(0x94),
                            proxy,
                            bytes1(0x01)
                        )
                    )
                )
            )
        );
    }
}