// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import { CrossChainEscrowFactory } from "../contracts/CrossChainEscrowFactory.sol";
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
 * @title DeployFactoryV2
 * @notice Deploy secure CrossChainEscrowFactory v2.1.0 with resolver whitelist and emergency pause
 * @dev This deployment includes critical security features missing from v1.1.0
 */
contract DeployFactoryV2 is Script {
    // CREATE3 factory deployed on Base, Etherlink, and Optimism
    address constant CREATE3_FACTORY = 0x7B9e9BE124C5A0E239E04fDC93b66ead4e8C669d;
    
    // Use new salt for v2 factory to get new address
    bytes32 constant FACTORY_V2_SALT = keccak256("BMN_FACTORY_V2.1.0_SECURE_20250106");
    
    // Limit Order Protocol address (needs to be set per chain)
    // For now using a placeholder - should be replaced with actual address
    address constant LIMIT_ORDER_PROTOCOL = address(0);
    
    // Rescue delays (7 days in seconds)
    uint32 constant RESCUE_DELAY = 604800;
    
    // Initial resolver to whitelist
    address constant INITIAL_RESOLVER = Constants.BOB_RESOLVER;
    
    // Deployment result
    address public factoryV2;
    
    function run() external {
        // Load deployer from environment
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("==============================================");
        console.log("Deploying Secure CrossChainEscrowFactory v2.1.0");
        console.log("==============================================");
        console.log("Deployer:", deployer);
        console.log("Chain ID:", block.chainid);
        console.log("CREATE3 Factory:", CREATE3_FACTORY);
        
        // Predict factory address
        factoryV2 = ICREATE3(CREATE3_FACTORY).getDeployed(deployer, FACTORY_V2_SALT);
        
        console.log("\nPredicted factory v2 address:", factoryV2);
        console.log("\n[INFO] Factory will deploy its own implementation contracts");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Check if factory is already deployed
        if (factoryV2.code.length == 0) {
            console.log("\n[DEPLOYMENT] Deploying CrossChainEscrowFactory v2.1.0...");
            
            // Prepare constructor arguments
            bytes memory factoryBytecode = abi.encodePacked(
                type(CrossChainEscrowFactory).creationCode,
                abi.encode(
                    LIMIT_ORDER_PROTOCOL,     // limitOrderProtocol
                    IERC20(Constants.BMN_TOKEN), // feeToken
                    IERC20(Constants.BMN_TOKEN), // bmnToken
                    deployer,                  // owner
                    RESCUE_DELAY,             // rescueDelaySrc
                    RESCUE_DELAY              // rescueDelayDst
                )
            );
            
            // Deploy with CREATE3
            address deployedFactory = ICREATE3(CREATE3_FACTORY).deploy(FACTORY_V2_SALT, factoryBytecode);
            require(deployedFactory == factoryV2, "Factory address mismatch");
            
            console.log("[OK] Factory v2 deployed at:", deployedFactory);
            console.log("[INFO] Factory automatically deployed its own implementations");
            
            // Whitelist initial resolver
            console.log("\n[SECURITY] Whitelisting initial resolver...");
            CrossChainEscrowFactory(factoryV2).addResolverToWhitelist(INITIAL_RESOLVER);
            console.log("[OK] Resolver whitelisted:", INITIAL_RESOLVER);
            
            // Verify deployment
            console.log("\n[VERIFY] Checking deployment...");
            require(
                CrossChainEscrowFactory(factoryV2).whitelistedResolvers(INITIAL_RESOLVER),
                "Resolver not whitelisted"
            );
            require(
                !CrossChainEscrowFactory(factoryV2).emergencyPaused(),
                "Factory should not be paused"
            );
            console.log("[OK] Security features verified");
            
        } else {
            console.log("\n[WARNING] Factory v2 already deployed at:", factoryV2);
            console.log("Skipping deployment...");
        }
        
        vm.stopBroadcast();
        
        // Save deployment info
        string memory deploymentInfo = string(abi.encodePacked(
            "# CrossChainEscrowFactory v2.1.0 Secure Deployment\n",
            "# This factory includes resolver whitelist and emergency pause\n",
            "CHAIN_ID=", vm.toString(block.chainid), "\n",
            "FACTORY_V2=", vm.toString(factoryV2), "\n",
            "INITIAL_RESOLVER=", vm.toString(INITIAL_RESOLVER), "\n",
            "DEPLOYER=", vm.toString(deployer), "\n",
            "DEPLOYMENT_TIME=", vm.toString(block.timestamp), "\n"
        ));
        
        string memory filename = string(abi.encodePacked(
            "deployments/factory-v2-",
            vm.toString(block.chainid),
            ".env"
        ));
        
        vm.writeFile(filename, deploymentInfo);
        
        console.log("\n==============================================");
        console.log("Deployment Complete");
        console.log("==============================================");
        console.log("Factory v2 address:", factoryV2);
        console.log("Deployment info saved to:", filename);
        console.log("\nNEXT STEPS:");
        console.log("1. Verify contract on explorer (if applicable)");
        console.log("2. Update resolver configuration with new factory address");
        console.log("3. Test security features with verification script");
        console.log("4. Update documentation with new addresses");
    }
}