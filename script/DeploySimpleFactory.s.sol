// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import { BaseEscrowFactory } from "../contracts/BaseEscrowFactory.sol";
import { Constants } from "../contracts/Constants.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

interface ICREATE3 {
    function deploy(bytes32 salt, bytes calldata bytecode) external payable returns (address);
    function getDeployed(address deployer, bytes32 salt) external view returns (address);
}

/**
 * @title DeploySimpleFactory
 * @notice Deploy a simplified BaseEscrowFactory to mainnet
 */
contract DeploySimpleFactory is Script {
    address constant CREATE3_FACTORY = 0x7B9e9BE124C5A0E239E04fDC93b66ead4e8C669d;
    
    // Use the same salts for consistency
    bytes32 constant SRC_IMPL_SALT = keccak256("BMN-EscrowSrc-MAINNET-v1");
    bytes32 constant DST_IMPL_SALT = keccak256("BMN-EscrowDst-MAINNET-v1");
    bytes32 constant FACTORY_SALT = keccak256("BMN-BaseFactory-MAINNET-v1"); // Different salt for base factory
    
    address constant BMN_TOKEN = Constants.BMN_TOKEN;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("[MAINNET BASE FACTORY DEPLOYMENT]");
        console.log("=================================");
        console.log("Deployer:", deployer);
        console.log("Chain ID:", block.chainid);
        
        // Get implementation addresses
        address srcImpl = ICREATE3(CREATE3_FACTORY).getDeployed(deployer, SRC_IMPL_SALT);
        address dstImpl = ICREATE3(CREATE3_FACTORY).getDeployed(deployer, DST_IMPL_SALT);
        address factory = ICREATE3(CREATE3_FACTORY).getDeployed(deployer, FACTORY_SALT);
        
        console.log("\nAddresses:");
        console.log("- EscrowSrc:", srcImpl);
        console.log("- EscrowDst:", dstImpl);
        console.log("- Factory:", factory);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy BaseEscrowFactory
        if (factory.code.length == 0) {
            console.log("\nDeploying BaseEscrowFactory...");
            bytes memory factoryBytecode = abi.encodePacked(
                type(BaseEscrowFactory).creationCode,
                abi.encode(
                    IERC20(BMN_TOKEN),    // access token
                    deployer,             // owner
                    srcImpl,              // src implementation
                    dstImpl               // dst implementation
                )
            );
            
            address deployed = ICREATE3(CREATE3_FACTORY).deploy(FACTORY_SALT, factoryBytecode);
            require(deployed == factory, "Factory address mismatch");
            console.log("[OK] BaseEscrowFactory deployed:", deployed);
        } else {
            console.log("BaseEscrowFactory already deployed at:", factory);
        }
        
        vm.stopBroadcast();
        
        console.log("\n========== DEPLOYMENT COMPLETE ==========");
        console.log("BaseEscrowFactory:", factory);
        console.log("=========================================");
        
        // Save deployment
        string memory chainName = getChainName();
        string memory deploymentData = string(abi.encodePacked(
            "# BMN BASE FACTORY - ", chainName, "\n",
            "CHAIN_ID=", vm.toString(block.chainid), "\n",
            "BASE_FACTORY=", vm.toString(factory), "\n",
            "ESCROW_SRC=", vm.toString(srcImpl), "\n",
            "ESCROW_DST=", vm.toString(dstImpl), "\n",
            "BMN_TOKEN=", vm.toString(BMN_TOKEN), "\n",
            "DEPLOYER=", vm.toString(deployer), "\n"
        ));
        
        string memory filename = string(abi.encodePacked(
            "deployments/base-factory-",
            chainName,
            ".txt"
        ));
        
        vm.writeFile(filename, deploymentData);
        console.log("\nDeployment saved to:", filename);
    }
    
    function getChainName() internal view returns (string memory) {
        if (block.chainid == 8453) return "base";
        if (block.chainid == 10) return "optimism";
        return vm.toString(block.chainid);
    }
}