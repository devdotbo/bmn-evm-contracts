// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import { EscrowSrc } from "../contracts/EscrowSrc.sol";
import { EscrowDst } from "../contracts/EscrowDst.sol";
import { Constants } from "../contracts/Constants.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

// CREATE3 Factory interface
interface ICREATE3 {
    function deploy(bytes32 salt, bytes calldata bytecode) external payable returns (address);
    function getDeployed(address deployer, bytes32 salt) external view returns (address);
}

/**
 * @title DeployImplementationsOnly
 * @notice Deploy only the escrow implementations to mainnet
 */
contract DeployImplementationsOnly is Script {
    // CREATE3 factory verified on all chains
    address constant CREATE3_FACTORY = 0x7B9e9BE124C5A0E239E04fDC93b66ead4e8C669d;
    
    // Production salts for deterministic addresses
    bytes32 constant SRC_IMPL_SALT = keccak256("BMN-EscrowSrc-MAINNET-v1");
    bytes32 constant DST_IMPL_SALT = keccak256("BMN-EscrowDst-MAINNET-v1");
    
    // Production configuration
    address constant BMN_TOKEN = Constants.BMN_TOKEN; // 0x8287CD2aC7E227D9D927F998EB600a0683a832A1
    uint32 constant RESCUE_DELAY = 7 days;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("[MAINNET ESCROW DEPLOYMENT]");
        console.log("===========================");
        console.log("Deployer:", deployer);
        console.log("Chain ID:", block.chainid);
        console.log("BMN Token:", BMN_TOKEN);
        
        // Get deterministic addresses
        address srcImpl = ICREATE3(CREATE3_FACTORY).getDeployed(deployer, SRC_IMPL_SALT);
        address dstImpl = ICREATE3(CREATE3_FACTORY).getDeployed(deployer, DST_IMPL_SALT);
        
        console.log("\nTarget Addresses:");
        console.log("- EscrowSrc:", srcImpl);
        console.log("- EscrowDst:", dstImpl);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Check if already deployed
        bool srcDeployed = srcImpl.code.length > 0;
        bool dstDeployed = dstImpl.code.length > 0;
        
        if (srcDeployed && dstDeployed) {
            console.log("\n[SUCCESS] Both implementations already deployed!");
            console.log("EscrowSrc:", srcImpl);
            console.log("EscrowDst:", dstImpl);
        } else {
            console.log("\n[WARNING] Implementations not fully deployed");
            console.log("EscrowSrc deployed:", srcDeployed);
            console.log("EscrowDst deployed:", dstDeployed);
            
            if (!srcDeployed) {
                console.log("\nTrying to deploy EscrowSrc...");
                bytes memory srcBytecode = abi.encodePacked(
                    type(EscrowSrc).creationCode,
                    abi.encode(RESCUE_DELAY, IERC20(BMN_TOKEN))
                );
                try ICREATE3(CREATE3_FACTORY).deploy(SRC_IMPL_SALT, srcBytecode) returns (address deployed) {
                    console.log("[OK] EscrowSrc deployed:", deployed);
                } catch {
                    console.log("[ERROR] Failed to deploy EscrowSrc");
                }
            }
            
            if (!dstDeployed) {
                console.log("\nTrying to deploy EscrowDst...");
                bytes memory dstBytecode = abi.encodePacked(
                    type(EscrowDst).creationCode,
                    abi.encode(RESCUE_DELAY, IERC20(BMN_TOKEN))
                );
                try ICREATE3(CREATE3_FACTORY).deploy(DST_IMPL_SALT, dstBytecode) returns (address deployed) {
                    console.log("[OK] EscrowDst deployed:", deployed);
                } catch {
                    console.log("[ERROR] Failed to deploy EscrowDst");
                }
            }
        }
        
        vm.stopBroadcast();
        
        // Final status
        console.log("\n========== FINAL STATUS ==========");
        console.log("Chain:", getChainName());
        console.log("EscrowSrc:", srcImpl, srcImpl.code.length > 0 ? "[DEPLOYED]" : "[NOT DEPLOYED]");
        console.log("EscrowDst:", dstImpl, dstImpl.code.length > 0 ? "[DEPLOYED]" : "[NOT DEPLOYED]");
        console.log("==================================");
        
        // Save deployment addresses
        string memory chainName = getChainName();
        string memory deploymentData = string(abi.encodePacked(
            "# BMN ESCROW IMPLEMENTATIONS - ", chainName, "\n",
            "CHAIN_ID=", vm.toString(block.chainid), "\n",
            "ESCROW_SRC=", vm.toString(srcImpl), "\n",
            "ESCROW_DST=", vm.toString(dstImpl), "\n",
            "BMN_TOKEN=", vm.toString(BMN_TOKEN), "\n",
            "DEPLOYER=", vm.toString(deployer), "\n",
            "TIMESTAMP=", vm.toString(block.timestamp), "\n"
        ));
        
        string memory filename = string(abi.encodePacked(
            "deployments/escrow-implementations-",
            chainName,
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