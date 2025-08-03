// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { BaseCreate2Script } from "../dependencies/create2-helpers-0.5.0/src/BaseCreate2Script.sol";
import { console2 } from "forge-std/console2.sol";
import { EscrowSrc } from "../contracts/EscrowSrc.sol";
import { EscrowDst } from "../contracts/EscrowDst.sol";
import { TestEscrowFactory } from "../contracts/TestEscrowFactory.sol";
import { Constants } from "../contracts/Constants.sol";

/**
 * @title DeployWithHelpers
 * @notice Deploy escrow contracts using create2-helpers for cross-chain consistency
 * @dev Extends BaseCreate2Script for CREATE2 deployment utilities
 */
contract DeployWithHelpers is BaseCreate2Script {
    // Deterministic salts for cross-chain consistency
    bytes32 constant SRC_SALT = keccak256("BMN-EscrowSrc-V1");
    bytes32 constant DST_SALT = keccak256("BMN-EscrowDst-V1");
    bytes32 constant FACTORY_SALT = keccak256("BMN-Factory-V1");
    
    // Standard CREATE2 factory (same as BMN token deployment)
    address constant ARACHNID_CREATE2 = 0x4e59b44847b379578588920cA78FbF26c0B4956C;
    
    function run() external {
        console2.log("Deploying with create2-helpers");
        console2.log("Deployer:", deployer);
        console2.log("Chain ID:", block.chainid);
        
        // Deploy implementations using the standard CREATE2 factory
        address srcImpl = _deployImplementation(SRC_SALT, type(EscrowSrc).creationCode, "EscrowSrc");
        address dstImpl = _deployImplementation(DST_SALT, type(EscrowDst).creationCode, "EscrowDst");
        
        // Deploy factory
        bytes memory factoryInitCode = abi.encodePacked(
            type(TestEscrowFactory).creationCode,
            abi.encode(
                srcImpl,
                dstImpl,
                Constants.BMN_TOKEN,
                0.00001 ether // safety deposit
            )
        );
        
        address factory = _deployImplementation(FACTORY_SALT, factoryInitCode, "TestEscrowFactory");
        
        console2.log("\n=== Deployment Complete ===");
        console2.log("SRC Implementation:", srcImpl);
        console2.log("DST Implementation:", dstImpl);
        console2.log("Factory:", factory);
        console2.log("\nThese addresses should be IDENTICAL on both chains!");
        
        // Verify deployments
        _verifyDeployment(srcImpl, "EscrowSrc");
        _verifyDeployment(dstImpl, "EscrowDst");
        _verifyDeployment(factory, "TestEscrowFactory");
    }
    
    function _deployImplementation(
        bytes32 salt,
        bytes memory initCode,
        string memory contractName
    ) internal returns (address) {
        console2.log("\nDeploying", contractName);
        console2.log("Salt:", vm.toString(salt));
        
        // Calculate expected address
        address expectedAddress = vm.computeCreate2Address(salt, keccak256(initCode), ARACHNID_CREATE2);
        console2.log("Expected address:", expectedAddress);
        
        // Check if already deployed
        if (expectedAddress.code.length > 0) {
            console2.log(contractName, "already deployed at:", expectedAddress);
            return expectedAddress;
        }
        
        // Deploy using CREATE2
        address deployed = _create2IfNotDeployed(deployer, salt, initCode);
        console2.log(contractName, "deployed at:", deployed);
        
        require(deployed == expectedAddress, "Deployment address mismatch");
        return deployed;
    }
    
    function _verifyDeployment(address contractAddress, string memory contractName) internal view {
        uint256 codeSize;
        assembly {
            codeSize := extcodesize(contractAddress)
        }
        
        if (codeSize > 0) {
            console2.log(contractName, "verified at:", contractAddress, "(code size:", codeSize, "bytes)");
        } else {
            revert(string.concat(contractName, " deployment failed"));
        }
    }
    
    // Override to use standard CREATE2 factory instead of ImmutableCreate2Factory
    function _create2IfNotDeployed(address broadcaster, bytes32 salt, bytes memory initCode)
        internal
        override
        returns (address)
    {
        address expectedAddress = vm.computeCreate2Address(salt, keccak256(initCode), ARACHNID_CREATE2);
        if (expectedAddress.code.length == 0) {
            vm.broadcast(broadcaster);
            (bool success,) = ARACHNID_CREATE2.call(bytes.concat(salt, initCode));
            require(success, "CREATE2 deployment failed");
        }
        return expectedAddress;
    }
}