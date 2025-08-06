// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import { SimplifiedCrossChainEscrowFactory } from "../contracts/SimplifiedCrossChainEscrowFactory.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

interface ICREATE3 {
    function deploy(bytes32 salt, bytes calldata bytecode) external payable returns (address);
    function getDeployed(address deployer, bytes32 salt) external view returns (address);
}

contract DeploySimplifiedFactory is Script {
    address constant CREATE3_FACTORY = 0x7B9e9BE124C5A0E239E04fDC93b66ead4e8C669d;
    bytes32 constant FACTORY_SALT = keccak256("BMN-SimpleFactory-MAINNET-v1");
    bytes32 constant SRC_SALT = keccak256("BMN-EscrowSrc-MAINNET-v1");
    bytes32 constant DST_SALT = keccak256("BMN-EscrowDst-MAINNET-v1");
    
    address constant LIMIT_ORDER_PROTOCOL = 0x1111111254EEB25477B68fb85Ed929f73A960582;
    address constant BMN_TOKEN = 0x8287CD2aC7E227D9D927F998EB600a0683a832A1;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("[SIMPLIFIED FACTORY DEPLOYMENT]");
        console.log("Chain ID:", block.chainid);
        console.log("Deployer:", deployer);
        
        // Get addresses
        address srcImpl = ICREATE3(CREATE3_FACTORY).getDeployed(deployer, SRC_SALT);
        address dstImpl = ICREATE3(CREATE3_FACTORY).getDeployed(deployer, DST_SALT);
        address factoryAddr = ICREATE3(CREATE3_FACTORY).getDeployed(deployer, FACTORY_SALT);
        
        console.log("\nImplementations:");
        console.log("EscrowSrc:", srcImpl);
        console.log("EscrowDst:", dstImpl);
        console.log("\nTarget Factory:", factoryAddr);
        
        // Verify implementations
        require(srcImpl.code.length > 0, "EscrowSrc not deployed");
        require(dstImpl.code.length > 0, "EscrowDst not deployed");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy SimplifiedCrossChainEscrowFactory
        if (factoryAddr.code.length == 0) {
            console.log("\nDeploying SimplifiedCrossChainEscrowFactory...");
            bytes memory factoryCode = abi.encodePacked(
                type(SimplifiedCrossChainEscrowFactory).creationCode,
                abi.encode(
                    LIMIT_ORDER_PROTOCOL,
                    IERC20(BMN_TOKEN),    // fee token (unused but required)
                    IERC20(BMN_TOKEN),    // access token
                    deployer,             // owner
                    srcImpl,              // src implementation
                    dstImpl               // dst implementation
                )
            );
            
            address deployed = ICREATE3(CREATE3_FACTORY).deploy(FACTORY_SALT, factoryCode);
            console.log("[DEPLOYED] SimplifiedCrossChainEscrowFactory:", deployed);
            require(deployed == factoryAddr, "Address mismatch");
        } else {
            console.log("Factory already deployed");
        }
        
        vm.stopBroadcast();
        
        console.log("\n========== MAINNET LIVE ==========");
        console.log("Chain:", getChainName());
        console.log("Factory:", factoryAddr);
        console.log("EscrowSrc:", srcImpl);
        console.log("EscrowDst:", dstImpl);
        console.log("===================================");
        
        // Save deployment
        string memory deploymentData = string(abi.encodePacked(
            "# BMN SIMPLIFIED FACTORY - ", getChainName(), "\n",
            "CHAIN_ID=", vm.toString(block.chainid), "\n",
            "FACTORY=", vm.toString(factoryAddr), "\n",
            "ESCROW_SRC=", vm.toString(srcImpl), "\n",
            "ESCROW_DST=", vm.toString(dstImpl), "\n",
            "BMN_TOKEN=", vm.toString(BMN_TOKEN), "\n",
            "LIMIT_ORDER_PROTOCOL=", vm.toString(LIMIT_ORDER_PROTOCOL), "\n"
        ));
        
        string memory filename = string(abi.encodePacked(
            "deployments/MAINNET-",
            getChainName(),
            "-SIMPLIFIED.txt"
        ));
        
        vm.writeFile(filename, deploymentData);
        console.log("Saved to:", filename);
    }
    
    function getChainName() internal view returns (string memory) {
        if (block.chainid == 8453) return "BASE";
        if (block.chainid == 10) return "OPTIMISM";
        return vm.toString(block.chainid);
    }
}