// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import { EscrowSrc } from "../contracts/EscrowSrc.sol";
import { EscrowDst } from "../contracts/EscrowDst.sol";
import { SimplifiedEscrowFactory } from "../contracts/SimplifiedEscrowFactory.sol";
import { Constants } from "../contracts/Constants.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

interface ICREATE3 {
    function deploy(bytes32 salt, bytes calldata bytecode) external payable returns (address);
    function getDeployed(address deployer, bytes32 salt) external view returns (address);
}

/**
 * @title DeployMainnet
 * @notice Unified deployment script for BMN Protocol - handles all versions
 * @dev Set VERSION environment variable to control deployment version
 */
contract DeployMainnet is Script {
    // CREATE3 factory deployed on Base, Optimism, and Etherlink
    address constant CREATE3_FACTORY = 0x7B9e9BE124C5A0E239E04fDC93b66ead4e8C669d;
    
    // Protocol parameters
    uint256 constant RESCUE_DELAY = 604800; // 7 days in seconds
    
    // Deployment results
    address public srcImplementation;
    address public dstImplementation;
    address public factory;
    
    function run() external {
        // Get version from environment (defaults to v3.0.0)
        string memory version = vm.envOr("VERSION", string("v3.0.0"));
        
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        // Generate salts based on version
        bytes32 srcSalt = keccak256(abi.encodePacked("BMN-EscrowSrc-", version));
        bytes32 dstSalt = keccak256(abi.encodePacked("BMN-EscrowDst-", version));
        bytes32 factorySalt = keccak256(abi.encodePacked("BMN-SimplifiedEscrowFactory-", version));
        
        console.log("========================================");
        console.log("BMN Protocol Deployment");
        console.log("========================================");
        console.log("Version:", version);
        console.log("Deployer:", deployer);
        console.log("Chain ID:", block.chainid);
        console.log("CREATE3 Factory:", CREATE3_FACTORY);
        console.log("BMN Token:", Constants.BMN_TOKEN);
        console.log("");
        
        // Predict addresses
        srcImplementation = ICREATE3(CREATE3_FACTORY).getDeployed(deployer, srcSalt);
        dstImplementation = ICREATE3(CREATE3_FACTORY).getDeployed(deployer, dstSalt);
        factory = ICREATE3(CREATE3_FACTORY).getDeployed(deployer, factorySalt);
        
        console.log("Predicted Addresses:");
        console.log("- EscrowSrc Implementation:", srcImplementation);
        console.log("- EscrowDst Implementation:", dstImplementation);
        console.log("- SimplifiedEscrowFactory:", factory);
        console.log("");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy EscrowSrc implementation if not deployed
        if (srcImplementation.code.length == 0) {
            bytes memory srcBytecode = abi.encodePacked(
                type(EscrowSrc).creationCode,
                abi.encode(
                    uint32(RESCUE_DELAY),  // rescueDelay
                    IERC20(Constants.BMN_TOKEN)  // accessToken
                )
            );
            address deployedSrc = ICREATE3(CREATE3_FACTORY).deploy(srcSalt, srcBytecode);
            require(deployedSrc == srcImplementation, "EscrowSrc address mismatch");
            console.log("[OK] Deployed EscrowSrc implementation");
        } else {
            console.log("[SKIP] EscrowSrc already deployed");
        }
        
        // Deploy EscrowDst implementation if not deployed
        if (dstImplementation.code.length == 0) {
            bytes memory dstBytecode = abi.encodePacked(
                type(EscrowDst).creationCode,
                abi.encode(
                    uint32(RESCUE_DELAY),  // rescueDelay
                    IERC20(Constants.BMN_TOKEN)  // accessToken
                )
            );
            address deployedDst = ICREATE3(CREATE3_FACTORY).deploy(dstSalt, dstBytecode);
            require(deployedDst == dstImplementation, "EscrowDst address mismatch");
            console.log("[OK] Deployed EscrowDst implementation");
        } else {
            console.log("[SKIP] EscrowDst already deployed");
        }
        
        // Deploy SimplifiedEscrowFactory if not deployed
        if (factory.code.length == 0) {
            bytes memory factoryBytecode = abi.encodePacked(
                type(SimplifiedEscrowFactory).creationCode,
                abi.encode(
                    srcImplementation,
                    dstImplementation,
                    deployer  // owner
                )
            );
            address deployedFactory = ICREATE3(CREATE3_FACTORY).deploy(factorySalt, factoryBytecode);
            require(deployedFactory == factory, "Factory address mismatch");
            console.log("[OK] Deployed SimplifiedEscrowFactory");
            
            // Log important settings for v3.0.0+
            SimplifiedEscrowFactory factoryContract = SimplifiedEscrowFactory(factory);
            console.log("");
            console.log("Factory Settings:");
            console.log("- Owner:", factoryContract.owner());
            console.log("- Whitelist Bypassed:", factoryContract.whitelistBypassed());
        } else {
            console.log("[SKIP] Factory already deployed");
        }
        
        vm.stopBroadcast();
        
        // Save deployment info
        string memory chainName = getChainName(block.chainid);
        string memory filename = string(abi.encodePacked(
            "deployments/",
            version,
            "-",
            chainName,
            "-",
            vm.toString(block.chainid),
            ".env"
        ));
        
        string memory content = string(abi.encodePacked(
            "# BMN Protocol ", version, " Deployment\n",
            "# Chain: ", chainName, " (", vm.toString(block.chainid), ")\n",
            "# Deployed: ", vm.toString(block.timestamp), "\n\n",
            "FACTORY_ADDRESS=", vm.toString(factory), "\n",
            "ESCROW_SRC_IMPL=", vm.toString(srcImplementation), "\n",
            "ESCROW_DST_IMPL=", vm.toString(dstImplementation), "\n",
            "BMN_TOKEN=", vm.toString(Constants.BMN_TOKEN), "\n",
            "CHAIN_ID=", vm.toString(block.chainid), "\n",
            "VERSION=", version, "\n"
        ));
        
        vm.writeFile(filename, content);
        console.log("");
        console.log("Deployment info saved to:", filename);
        
        // Display verification commands
        console.log("");
        console.log("To verify contracts, run:");
        if (block.chainid == 8453) {
            console.log("forge verify-contract", srcImplementation, "EscrowSrc --etherscan-api-key $BASESCAN_API_KEY");
            console.log("forge verify-contract", dstImplementation, "EscrowDst --etherscan-api-key $BASESCAN_API_KEY");
            console.log("forge verify-contract", factory, "SimplifiedEscrowFactory --etherscan-api-key $BASESCAN_API_KEY");
        } else if (block.chainid == 10) {
            console.log("forge verify-contract", srcImplementation, "EscrowSrc --etherscan-api-key $OPTIMISTIC_ETHERSCAN_API_KEY");
            console.log("forge verify-contract", dstImplementation, "EscrowDst --etherscan-api-key $OPTIMISTIC_ETHERSCAN_API_KEY");
            console.log("forge verify-contract", factory, "SimplifiedEscrowFactory --etherscan-api-key $OPTIMISTIC_ETHERSCAN_API_KEY");
        }
    }
    
    function getChainName(uint256 chainId) internal pure returns (string memory) {
        if (chainId == 1) return "ethereum";
        if (chainId == 10) return "optimism";
        if (chainId == 8453) return "base";
        if (chainId == 42793) return "etherlink";
        if (chainId == 84532) return "base-sepolia";
        if (chainId == 11155111) return "sepolia";
        if (chainId == 31337) return "anvil";
        return "unknown";
    }
}