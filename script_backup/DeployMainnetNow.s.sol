// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import { EscrowSrc } from "../contracts/EscrowSrc.sol";
import { EscrowDst } from "../contracts/EscrowDst.sol";
import { CrossChainEscrowFactory } from "../contracts/CrossChainEscrowFactory.sol";
import { Constants } from "../contracts/Constants.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

// CREATE3 Factory interface
interface ICREATE3 {
    function deploy(bytes32 salt, bytes calldata bytecode) external payable returns (address);
    function getDeployed(address deployer, bytes32 salt) external view returns (address);
}

/**
 * @title DeployMainnetNow
 * @notice MAINNET DEPLOYMENT - Base, Optimism, Etherlink
 * @dev Simplified deployment script for immediate mainnet deployment
 */
contract DeployMainnetNow is Script {
    // CREATE3 factory verified on all chains
    address constant CREATE3_FACTORY = 0x7B9e9BE124C5A0E239E04fDC93b66ead4e8C669d;
    
    // Production salts for deterministic addresses
    bytes32 constant SRC_IMPL_SALT = keccak256("BMN-EscrowSrc-MAINNET-v1");
    bytes32 constant DST_IMPL_SALT = keccak256("BMN-EscrowDst-MAINNET-v1");
    bytes32 constant FACTORY_SALT = keccak256("BMN-Factory-MAINNET-v1");
    
    // Production configuration
    address constant LIMIT_ORDER_PROTOCOL = 0x1111111254EEB25477B68fb85Ed929f73A960582; // 1inch on all chains
    address constant BMN_TOKEN = Constants.BMN_TOKEN; // 0x8287CD2aC7E227D9D927F998EB600a0683a832A1
    uint32 constant RESCUE_DELAY = 7 days;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("[MAINNET DEPLOYMENT]");
        console.log("====================");
        console.log("Deployer:", deployer);
        console.log("Chain ID:", block.chainid);
        console.log("BMN Token:", BMN_TOKEN);
        
        // Get deterministic addresses
        address srcImpl = ICREATE3(CREATE3_FACTORY).getDeployed(deployer, SRC_IMPL_SALT);
        address dstImpl = ICREATE3(CREATE3_FACTORY).getDeployed(deployer, DST_IMPL_SALT);
        address factory = ICREATE3(CREATE3_FACTORY).getDeployed(deployer, FACTORY_SALT);
        
        console.log("\nTarget Addresses:");
        console.log("- EscrowSrc:", srcImpl);
        console.log("- EscrowDst:", dstImpl);
        console.log("- Factory:", factory);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // 1. Deploy EscrowSrc Implementation
        if (srcImpl.code.length == 0) {
            console.log("\n[1/3] Deploying EscrowSrc...");
            bytes memory srcBytecode = abi.encodePacked(
                type(EscrowSrc).creationCode,
                abi.encode(RESCUE_DELAY, IERC20(BMN_TOKEN))
            );
            address deployed = ICREATE3(CREATE3_FACTORY).deploy(SRC_IMPL_SALT, srcBytecode);
            require(deployed == srcImpl, "EscrowSrc address mismatch");
            console.log("[OK] EscrowSrc deployed:", deployed);
        } else {
            console.log("[1/3] EscrowSrc already deployed");
        }
        
        // 2. Deploy EscrowDst Implementation
        if (dstImpl.code.length == 0) {
            console.log("\n[2/3] Deploying EscrowDst...");
            bytes memory dstBytecode = abi.encodePacked(
                type(EscrowDst).creationCode,
                abi.encode(RESCUE_DELAY, IERC20(BMN_TOKEN))
            );
            address deployed = ICREATE3(CREATE3_FACTORY).deploy(DST_IMPL_SALT, dstBytecode);
            require(deployed == dstImpl, "EscrowDst address mismatch");
            console.log("[OK] EscrowDst deployed:", deployed);
        } else {
            console.log("[2/3] EscrowDst already deployed");
        }
        
        // 3. Deploy CrossChainEscrowFactory
        if (factory.code.length == 0) {
            console.log("\n[3/3] Deploying CrossChainEscrowFactory...");
            bytes memory factoryBytecode = abi.encodePacked(
                type(CrossChainEscrowFactory).creationCode,
                abi.encode(
                    LIMIT_ORDER_PROTOCOL,
                    IERC20(BMN_TOKEN),    // fee token
                    IERC20(BMN_TOKEN),    // access token
                    deployer,             // owner
                    srcImpl,              // src implementation
                    dstImpl               // dst implementation
                )
            );
            address deployed = ICREATE3(CREATE3_FACTORY).deploy(FACTORY_SALT, factoryBytecode);
            require(deployed == factory, "Factory address mismatch");
            console.log("[OK] Factory deployed:", deployed);
        } else {
            console.log("[3/3] Factory already deployed");
        }
        
        vm.stopBroadcast();
        
        // Print deployment summary
        console.log("\n========== DEPLOYMENT COMPLETE ==========");
        console.log("Chain ID:", block.chainid);
        console.log("EscrowSrc:", srcImpl);
        console.log("EscrowDst:", dstImpl);
        console.log("CrossChainEscrowFactory:", factory);
        console.log("=========================================");
        
        // Save deployment addresses
        string memory chainName = getChainName();
        string memory deploymentData = string(abi.encodePacked(
            "# BMN MAINNET DEPLOYMENT - ", chainName, "\n",
            "CHAIN_ID=", vm.toString(block.chainid), "\n",
            "ESCROW_SRC=", vm.toString(srcImpl), "\n",
            "ESCROW_DST=", vm.toString(dstImpl), "\n",
            "FACTORY=", vm.toString(factory), "\n",
            "BMN_TOKEN=", vm.toString(BMN_TOKEN), "\n",
            "DEPLOYER=", vm.toString(deployer), "\n",
            "TIMESTAMP=", vm.toString(block.timestamp), "\n"
        ));
        
        string memory filename = string(abi.encodePacked(
            "deployments/mainnet-",
            chainName,
            "-",
            vm.toString(block.timestamp),
            ".txt"
        ));
        
        vm.writeFile(filename, deploymentData);
        console.log("\nDeployment saved to:", filename);
    }
    
    function getChainName() internal view returns (string memory) {
        if (block.chainid == 8453) return "base";
        if (block.chainid == 10) return "optimism";
        if (block.chainid == 42793) return "etherlink";
        return vm.toString(block.chainid);
    }
}