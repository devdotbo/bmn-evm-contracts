// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import { EscrowSrc } from "../contracts/EscrowSrc.sol";
import { EscrowDst } from "../contracts/EscrowDst.sol";
import { SimplifiedEscrowFactory } from "../contracts/SimplifiedEscrowFactory.sol";
import { Constants } from "../contracts/Constants.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

// CREATE3 Factory interface
interface ICREATE3 {
    function deploy(bytes32 salt, bytes calldata bytecode) external payable returns (address);
    function getDeployed(address deployer, bytes32 salt) external view returns (address);
}

/**
 * @title DeployV2_2_Mainnet
 * @notice Deploy SimplifiedEscrowFactory v2.2.0 with PostInteraction support to mainnet
 * @dev Deploys to Base and Optimism using CREATE3 for deterministic addresses
 * 
 * Key Features:
 * - PostInteraction interface implementation for 1inch integration
 * - Resolver whitelisting for controlled access
 * - Emergency pause mechanism
 * - Deterministic addresses across chains
 * 
 * Deployment Process:
 * 1. Deploy EscrowSrc and EscrowDst implementations (if not already deployed)
 * 2. Deploy SimplifiedEscrowFactory with PostInteraction support
 * 3. Configure initial resolver whitelist
 * 4. Verify deployment and save addresses
 */
contract DeployV2_2_Mainnet is Script {
    // CREATE3 factory verified and deployed on Base and Optimism
    address constant CREATE3_FACTORY = 0x7B9e9BE124C5A0E239E04fDC93b66ead4e8C669d;
    
    // Chain IDs
    uint256 constant BASE_CHAIN_ID = 8453;
    uint256 constant OPTIMISM_CHAIN_ID = 10;
    
    // Deterministic salts for v2.2.0 deployment
    // Using existing implementation salts since implementations don't change
    bytes32 constant SRC_IMPL_SALT = keccak256("BMN-EscrowSrc-v1.0.0");
    bytes32 constant DST_IMPL_SALT = keccak256("BMN-EscrowDst-v1.0.0");
    
    // New salt for v2.2.0 factory with PostInteraction
    bytes32 constant FACTORY_SALT = keccak256("BMN-SimplifiedEscrowFactory-v2.2.0-PostInteraction");
    
    // Rescue delay for escrows (7 days in seconds)
    uint256 constant RESCUE_DELAY = 604800;
    
    // Deployment results
    address public srcImplementation;
    address public dstImplementation;
    address public factory;
    
    // Initial resolvers to whitelist (production resolvers)
    address[] public initialResolvers;
    
    function run() external {
        // Load deployer from environment
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        // Validate chain
        require(
            block.chainid == BASE_CHAIN_ID || block.chainid == OPTIMISM_CHAIN_ID,
            "Must deploy to Base or Optimism mainnet"
        );
        
        string memory chainName = block.chainid == BASE_CHAIN_ID ? "Base" : "Optimism";
        
        console.log("================================================");
        console.log("Deploying SimplifiedEscrowFactory v2.2.0 to", chainName);
        console.log("================================================");
        console.log("Deployer:", deployer);
        console.log("Chain ID:", block.chainid);
        console.log("CREATE3 Factory:", CREATE3_FACTORY);
        console.log("BMN Token:", Constants.BMN_TOKEN);
        
        // Predict addresses
        srcImplementation = ICREATE3(CREATE3_FACTORY).getDeployed(deployer, SRC_IMPL_SALT);
        dstImplementation = ICREATE3(CREATE3_FACTORY).getDeployed(deployer, DST_IMPL_SALT);
        factory = ICREATE3(CREATE3_FACTORY).getDeployed(deployer, FACTORY_SALT);
        
        console.log("\nPredicted Addresses:");
        console.log("------------------------------------------------");
        console.log("EscrowSrc Implementation:", srcImplementation);
        console.log("EscrowDst Implementation:", dstImplementation);
        console.log("SimplifiedEscrowFactory v2.2.0:", factory);
        
        // Setup initial resolvers from environment (comma-separated)
        string memory resolverList = vm.envOr("INITIAL_RESOLVERS", string(""));
        address[] memory parsedResolvers = parseResolvers(resolverList);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy EscrowSrc implementation if not already deployed
        if (srcImplementation.code.length == 0) {
            console.log("\n[1/3] Deploying EscrowSrc implementation...");
            bytes memory srcBytecode = abi.encodePacked(
                type(EscrowSrc).creationCode,
                abi.encode(RESCUE_DELAY, IERC20(Constants.BMN_TOKEN))
            );
            
            address deployedSrc = ICREATE3(CREATE3_FACTORY).deploy(SRC_IMPL_SALT, srcBytecode);
            require(deployedSrc == srcImplementation, "SRC implementation address mismatch");
            console.log("       SUCCESS: EscrowSrc deployed at", deployedSrc);
        } else {
            console.log("\n[1/3] EscrowSrc implementation already deployed at:", srcImplementation);
        }
        
        // Deploy EscrowDst implementation if not already deployed
        if (dstImplementation.code.length == 0) {
            console.log("\n[2/3] Deploying EscrowDst implementation...");
            bytes memory dstBytecode = abi.encodePacked(
                type(EscrowDst).creationCode,
                abi.encode(RESCUE_DELAY, IERC20(Constants.BMN_TOKEN))
            );
            
            address deployedDst = ICREATE3(CREATE3_FACTORY).deploy(DST_IMPL_SALT, dstBytecode);
            require(deployedDst == dstImplementation, "DST implementation address mismatch");
            console.log("       SUCCESS: EscrowDst deployed at", deployedDst);
        } else {
            console.log("\n[2/3] EscrowDst implementation already deployed at:", dstImplementation);
        }
        
        // Deploy SimplifiedEscrowFactory v2.2.0
        if (factory.code.length == 0) {
            console.log("\n[3/3] Deploying SimplifiedEscrowFactory v2.2.0 with PostInteraction...");
            bytes memory factoryBytecode = abi.encodePacked(
                type(SimplifiedEscrowFactory).creationCode,
                abi.encode(
                    srcImplementation,
                    dstImplementation,
                    deployer // Initial owner (should be transferred to multisig after deployment)
                )
            );
            
            address deployedFactory = ICREATE3(CREATE3_FACTORY).deploy(FACTORY_SALT, factoryBytecode);
            require(deployedFactory == factory, "Factory address mismatch");
            console.log("       SUCCESS: SimplifiedEscrowFactory v2.2.0 deployed at", deployedFactory);
            
            // Configure initial resolvers if provided
            if (parsedResolvers.length > 0) {
                SimplifiedEscrowFactory factoryInstance = SimplifiedEscrowFactory(deployedFactory);
                console.log("\n[4/4] Configuring initial resolver whitelist...");
                for (uint256 i = 0; i < parsedResolvers.length; i++) {
                    if (!factoryInstance.whitelistedResolvers(parsedResolvers[i])) {
                        factoryInstance.addResolver(parsedResolvers[i]);
                        console.log("       Whitelisted resolver:", parsedResolvers[i]);
                    }
                }
            }
        } else {
            console.log("\n[3/3] SimplifiedEscrowFactory v2.2.0 already deployed at:", factory);
        }
        
        vm.stopBroadcast();
        
        // Verify deployment
        console.log("\n================================================");
        console.log("Deployment Verification");
        console.log("================================================");
        
        // Check contract sizes
        console.log("\nContract Sizes:");
        console.log("EscrowSrc:", srcImplementation.code.length, "bytes");
        console.log("EscrowDst:", dstImplementation.code.length, "bytes");
        console.log("SimplifiedEscrowFactory:", factory.code.length, "bytes");
        
        // Verify factory configuration
        SimplifiedEscrowFactory factoryContract = SimplifiedEscrowFactory(factory);
        console.log("\nFactory Configuration:");
        console.log("Owner:", factoryContract.owner());
        console.log("Src Implementation:", factoryContract.ESCROW_SRC_IMPLEMENTATION());
        console.log("Dst Implementation:", factoryContract.ESCROW_DST_IMPLEMENTATION());
        console.log("Emergency Paused:", factoryContract.emergencyPaused());
        console.log("Resolver Count:", factoryContract.resolverCount());
        
        // Save deployment info
        string memory deploymentInfo = string(abi.encodePacked(
            "# SimplifiedEscrowFactory v2.2.0 Deployment\n",
            "# Chain: ", chainName, "\n",
            "# Date: ", vm.toString(block.timestamp), "\n",
            "# Features: PostInteraction, Resolver Whitelist, Emergency Pause\n",
            "\n",
            "CHAIN_ID=", vm.toString(block.chainid), "\n",
            "CHAIN_NAME=", chainName, "\n",
            "CREATE3_FACTORY=", vm.toString(CREATE3_FACTORY), "\n",
            "BMN_TOKEN=", vm.toString(Constants.BMN_TOKEN), "\n",
            "\n",
            "# Implementation Contracts (v1.0.0 - unchanged)\n",
            "ESCROW_SRC_IMPLEMENTATION=", vm.toString(srcImplementation), "\n",
            "ESCROW_DST_IMPLEMENTATION=", vm.toString(dstImplementation), "\n",
            "\n",
            "# Factory Contract (v2.2.0 with PostInteraction)\n",
            "SIMPLIFIED_ESCROW_FACTORY=", vm.toString(factory), "\n",
            "\n",
            "# Deployment Details\n",
            "DEPLOYER=", vm.toString(deployer), "\n",
            "FACTORY_OWNER=", vm.toString(deployer), "\n",
            "FACTORY_SALT=BMN-SimplifiedEscrowFactory-v2.2.0-PostInteraction\n",
            "\n",
            "# PostInteraction Integration\n",
            "# The factory implements IPostInteraction interface\n",
            "# Compatible with 1inch SimpleLimitOrderProtocol\n",
            "# Enables atomic escrow creation during order fills\n"
        ));
        
        string memory filename = string(abi.encodePacked(
            "deployments/v2.2.0-mainnet-",
            vm.toString(block.chainid),
            ".env"
        ));
        
        vm.writeFile(filename, deploymentInfo);
        console.log("\n================================================");
        console.log("Deployment Complete!");
        console.log("================================================");
        console.log("Deployment info saved to:", filename);
        console.log("\nIMPORTANT POST-DEPLOYMENT STEPS:");
        console.log("1. Transfer ownership to multisig wallet");
        console.log("2. Whitelist production resolvers");
        console.log("3. Configure 1inch SimpleLimitOrderProtocol integration");
        console.log("4. Update resolver infrastructure to v2.2.0 factory address");
        console.log("5. Verify contracts on Etherscan/Basescan");
        console.log("\nFactory Address for all chains:", factory);
    }
    
    /**
     * @notice Helper function to parse comma-separated addresses
     * @dev This would be called if INITIAL_RESOLVERS env var is provided
     */
    function parseResolvers(string memory resolverList) internal pure returns (address[] memory) {
        bytes memory b = bytes(resolverList);
        if (b.length == 0) return new address[](0);
        // Count commas
        uint256 count = 1;
        for (uint256 i = 0; i < b.length; i++) {
            if (b[i] == ",") count++;
        }
        address[] memory result = new address[](count);
        uint256 idx = 0;
        uint256 start = 0;
        for (uint256 i = 0; i <= b.length; i++) {
            if (i == b.length || b[i] == ",") {
                uint256 len = i - start;
                if (len > 0) {
                    bytes memory slice = new bytes(len);
                    for (uint256 j = 0; j < len; j++) {
                        slice[j] = b[start + j];
                    }
                    // Trim spaces
                    uint256 s = 0; while (s < slice.length && slice[s] == 0x20) s++;
                    uint256 e = slice.length; while (e > s && slice[e-1] == 0x20) e--;
                    bytes memory trimmed = new bytes(e - s);
                    for (uint256 k = 0; k < trimmed.length; k++) trimmed[k] = slice[s + k];
                    // Expect 0x-prefixed address string
                    if (trimmed.length >= 42) {
                        result[idx] = parseAddress(trimmed);
                        idx++;
                    }
                }
                start = i + 1;
            }
        }
        assembly { mstore(result, idx) }
        return result;
    }

    function parseAddress(bytes memory s) internal pure returns (address a) {
        // s expected like "0x....40hex"
        require(s.length >= 42, "bad addr");
        uint160 acc = 0;
        for (uint256 i = 2; i < 42; i++) {
            uint8 c = uint8(s[i]);
            uint8 v;
            if (c >= 48 && c <= 57) v = c - 48;           // 0-9
            else if (c >= 97 && c <= 102) v = 10 + c - 97; // a-f
            else if (c >= 65 && c <= 70) v = 10 + c - 65;  // A-F
            else revert("bad hex");
            acc = uint160(acc * 16 + v);
        }
        a = address(acc);
    }
}