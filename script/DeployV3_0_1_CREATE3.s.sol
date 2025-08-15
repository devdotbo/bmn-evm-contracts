// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import { EscrowSrc } from "../contracts/EscrowSrc.sol";
import { EscrowDst } from "../contracts/EscrowDst.sol";
import { SimplifiedEscrowFactory } from "../contracts/SimplifiedEscrowFactory.sol";

// CREATE3 Factory interface
interface ICREATE3 {
    function deploy(bytes32 salt, bytes calldata bytecode) external payable returns (address);
    function getDeployed(address deployer, bytes32 salt) external view returns (address);
}

/**
 * @title DeployV3_0_1_CREATE3
 * @notice Deploy v3.0.1 bugfix release using CREATE3 for cross-chain address consistency
 * @dev Uses CREATE3 factory at 0x7B9e9BE124C5A0E239E04fDC93b66ead4e8C669d (Base & Optimism)
 */
contract DeployV3_0_1_CREATE3 is Script {
    // CREATE3 factory deployed on Base, Optimism, and Etherlink
    address constant CREATE3_FACTORY = 0x7B9e9BE124C5A0E239E04fDC93b66ead4e8C669d;
    
    // Deterministic salts for v3.0.1 - using new salts for fresh deployment
    bytes32 constant SRC_IMPL_SALT = keccak256("BMN-EscrowSrc-v3.0.1");
    bytes32 constant DST_IMPL_SALT = keccak256("BMN-EscrowDst-v3.0.1");
    bytes32 constant FACTORY_SALT = keccak256("BMN-SimplifiedEscrowFactory-v3.0.1");
    
    // Configuration
    uint32 constant RESCUE_DELAY = 86400; // 1 day
    address constant ACCESS_TOKEN = address(0); // No access token
    
    function run() external {
        // Load deployer from environment
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("=== V3.0.1 BUGFIX DEPLOYMENT WITH CREATE3 ===");
        console.log("Deployer:", deployer);
        console.log("Chain ID:", block.chainid);
        console.log("CREATE3 Factory:", CREATE3_FACTORY);
        
        // Predict addresses (will be same on all chains)
        address srcImplementation = ICREATE3(CREATE3_FACTORY).getDeployed(deployer, SRC_IMPL_SALT);
        address dstImplementation = ICREATE3(CREATE3_FACTORY).getDeployed(deployer, DST_IMPL_SALT);
        address factory = ICREATE3(CREATE3_FACTORY).getDeployed(deployer, FACTORY_SALT);
        
        console.log("\nPredicted addresses (same on all chains):");
        console.log("EscrowSrc Implementation:", srcImplementation);
        console.log("EscrowDst Implementation:", dstImplementation);
        console.log("SimplifiedEscrowFactory v3.0.1:", factory);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // 1. Deploy EscrowSrc implementation
        if (srcImplementation.code.length == 0) {
            console.log("\nDeploying EscrowSrc implementation...");
            bytes memory srcBytecode = abi.encodePacked(
                type(EscrowSrc).creationCode,
                abi.encode(RESCUE_DELAY, ACCESS_TOKEN)
            );
            
            address deployedSrc = ICREATE3(CREATE3_FACTORY).deploy(SRC_IMPL_SALT, srcBytecode);
            require(deployedSrc == srcImplementation, "SRC implementation address mismatch");
            console.log("EscrowSrc deployed at:", deployedSrc);
        } else {
            console.log("EscrowSrc already deployed at:", srcImplementation);
        }
        
        // 2. Deploy EscrowDst implementation
        if (dstImplementation.code.length == 0) {
            console.log("\nDeploying EscrowDst implementation...");
            bytes memory dstBytecode = abi.encodePacked(
                type(EscrowDst).creationCode,
                abi.encode(RESCUE_DELAY, ACCESS_TOKEN)
            );
            
            address deployedDst = ICREATE3(CREATE3_FACTORY).deploy(DST_IMPL_SALT, dstBytecode);
            require(deployedDst == dstImplementation, "DST implementation address mismatch");
            console.log("EscrowDst deployed at:", deployedDst);
        } else {
            console.log("EscrowDst already deployed at:", dstImplementation);
        }
        
        // 3. Deploy SimplifiedEscrowFactory v3.0.1 with bugfix
        if (factory.code.length == 0) {
            console.log("\nDeploying SimplifiedEscrowFactory v3.0.1...");
            bytes memory factoryBytecode = abi.encodePacked(
                type(SimplifiedEscrowFactory).creationCode,
                abi.encode(
                    srcImplementation,
                    dstImplementation,
                    deployer // owner - will be whitelisted automatically
                )
            );
            
            address deployedFactory = ICREATE3(CREATE3_FACTORY).deploy(FACTORY_SALT, factoryBytecode);
            require(deployedFactory == factory, "Factory address mismatch");
            console.log("SimplifiedEscrowFactory v3.0.1 deployed at:", deployedFactory);
            
            // 4. Configure factory
            SimplifiedEscrowFactory factoryContract = SimplifiedEscrowFactory(deployedFactory);
            
            // Enable whitelist bypass for easier testing initially
            factoryContract.setWhitelistBypassed(true);
            console.log("Whitelist bypass enabled for testing");
        } else {
            console.log("SimplifiedEscrowFactory already deployed at:", factory);
        }
        
        vm.stopBroadcast();
        
        // Save deployment info
        string memory timestamp = vm.toString(block.timestamp);
        string memory deploymentPath = string(abi.encodePacked(
            "./deployments/v3_0_1_CREATE3_",
            vm.toString(block.chainid),
            "_",
            timestamp,
            ".json"
        ));
        
        string memory json = string(abi.encodePacked(
            "{\n",
            '  "version": "v3.0.1",\n',
            '  "chainId": ', vm.toString(block.chainid), ',\n',
            '  "timestamp": ', timestamp, ',\n',
            '  "deployer": "', vm.toString(deployer), '",\n',
            '  "create3Factory": "', vm.toString(CREATE3_FACTORY), '",\n',
            '  "factory": "', vm.toString(factory), '",\n',
            '  "srcImplementation": "', vm.toString(srcImplementation), '",\n',
            '  "dstImplementation": "', vm.toString(dstImplementation), '",\n',
            '  "rescueDelay": ', vm.toString(RESCUE_DELAY), ',\n',
            '  "accessToken": "', vm.toString(ACCESS_TOKEN), '",\n',
            '  "whitelistBypassed": true\n',
            "}"
        ));
        
        vm.writeFile(deploymentPath, json);
        
        // Print verification commands
        console.log("\n=== VERIFICATION COMMANDS ===");
        
        // Constructor args for verification
        bytes memory srcConstructorArgs = abi.encode(RESCUE_DELAY, ACCESS_TOKEN);
        bytes memory dstConstructorArgs = abi.encode(RESCUE_DELAY, ACCESS_TOKEN);
        bytes memory factoryConstructorArgs = abi.encode(srcImplementation, dstImplementation, deployer);
        
        console.log("\nBase:");
        console.log(string(abi.encodePacked(
            "forge verify-contract --watch --chain base ",
            vm.toString(factory),
            " contracts/SimplifiedEscrowFactory.sol:SimplifiedEscrowFactory",
            " --constructor-args ",
            vm.toString(factoryConstructorArgs)
        )));
        
        console.log("\nOptimism:");
        console.log(string(abi.encodePacked(
            "forge verify-contract --watch --chain optimism ",
            vm.toString(factory),
            " contracts/SimplifiedEscrowFactory.sol:SimplifiedEscrowFactory",
            " --constructor-args ",
            vm.toString(factoryConstructorArgs)
        )));
        
        console.log("\n=== DEPLOYMENT SUMMARY ===");
        console.log("Version: v3.0.1");
        console.log("Status: BUGFIX RELEASE");
        console.log("Critical Fix: dstCancellation now aligns with srcCancellation");
        console.log("Features:");
        console.log("- Instant withdrawals (0 delay)");
        console.log("- Flexible cancellation times (any duration)");
        console.log("- 60s timestamp tolerance");
        console.log("- Whitelist bypass enabled by default");
        console.log("- SAME ADDRESS ON ALL CHAINS via CREATE3");
        console.log("\nFactory Address (all chains):", factory);
        console.log("  EscrowSrc Impl:", srcImplementation);
        console.log("  EscrowDst Impl:", dstImplementation);
        console.log("  Deployment saved to:", deploymentPath);
    }
}