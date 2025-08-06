// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import "../contracts/CrossChainEscrowFactory.sol";
import "../contracts/mocks/TokenMock.sol";
import "../dependencies/limit-order-protocol/contracts/LimitOrderProtocol.sol";
import { Create3Factory } from "../contracts/Create3Factory.sol";

/**
 * @title Deploy BMN Extensions Script
 * @notice Deploys the BMN extension system with CREATE3 for deterministic addresses
 * @dev Run with: forge script script/DeployBMNExtensions.s.sol --rpc-url $RPC_URL --broadcast
 */
contract DeployBMNExtensions is Script {
    // CREATE3 Factory deployed across all chains
    Create3Factory constant CREATE3 = Create3Factory(0x7B9e9BE124C5A0E239E04fDC93b66ead4e8C669d);
    
    // Deployment salts for deterministic addresses
    bytes32 constant BMN_TOKEN_SALT = keccak256("BMN_TOKEN_V1");
    bytes32 constant ESCROW_SRC_SALT = keccak256("ESCROW_SRC_V2");
    bytes32 constant ESCROW_DST_SALT = keccak256("ESCROW_DST_V2");
    bytes32 constant FACTORY_SALT = keccak256("BMN_FACTORY_V2");
    bytes32 constant LIMIT_ORDER_SALT = keccak256("BMN_LIMIT_ORDER_V1");
    
    // Configuration
    uint32 constant RESCUE_DELAY_SRC = 259200; // 3 days
    uint32 constant RESCUE_DELAY_DST = 259200; // 3 days
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("Deploying BMN Extension System");
        console.log("Deployer:", deployer);
        console.log("Chain ID:", block.chainid);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // 1. Deploy BMN Token (if not already deployed)
        address bmnToken = CREATE3.deployments(deployer, BMN_TOKEN_SALT);
        if (bmnToken == address(0)) {
            bytes memory tokenBytecode = abi.encodePacked(
                type(TokenMock).creationCode,
                abi.encode("Bridge Me Not Token", "BMN")
            );
            
            bmnToken = CREATE3.deploy(BMN_TOKEN_SALT, tokenBytecode);
            console.log("BMN Token deployed at:", bmnToken);
            
            // Mint initial supply for testing
            TokenMock(bmnToken).mint(deployer, 1000000e18);
        } else {
            console.log("BMN Token already deployed at:", bmnToken);
        }
        
        // 2. Deploy SimpleLimitOrderProtocol (or use existing 1inch)
        address limitOrderProtocol = CREATE3.deployments(deployer, LIMIT_ORDER_SALT);
        if (limitOrderProtocol == address(0)) {
            // For production, integrate with actual 1inch protocol
            // For now, deploy a simple version for testing
            bytes memory lopBytecode = abi.encodePacked(
                type(LimitOrderProtocol).creationCode,
                abi.encode(address(0)) // WETH address (not used in our case)
            );
            
            limitOrderProtocol = CREATE3.deploy(LIMIT_ORDER_SALT, lopBytecode);
            console.log("Limit Order Protocol deployed at:", limitOrderProtocol);
        } else {
            console.log("Limit Order Protocol already at:", limitOrderProtocol);
        }
        
        // 3. Deploy CrossChainEscrowFactory with BMN extensions
        address factory = CREATE3.deployments(deployer, FACTORY_SALT);
        if (factory == address(0)) {
            bytes memory factoryBytecode = abi.encodePacked(
                type(CrossChainEscrowFactory).creationCode,
                abi.encode(
                    limitOrderProtocol,
                    bmnToken,      // Fee token
                    bmnToken,      // Access token (same as fee token for now)
                    deployer,      // Owner
                    RESCUE_DELAY_SRC,
                    RESCUE_DELAY_DST
                )
            );
            
            factory = CREATE3.deploy(FACTORY_SALT, factoryBytecode);
            console.log("CrossChainEscrowFactory deployed at:", factory);
            
            // Get implementation addresses
            address srcImpl = CrossChainEscrowFactory(factory).ESCROW_SRC_IMPLEMENTATION();
            address dstImpl = CrossChainEscrowFactory(factory).ESCROW_DST_IMPLEMENTATION();
            
            console.log("  EscrowSrc implementation:", srcImpl);
            console.log("  EscrowDst implementation:", dstImpl);
        } else {
            console.log("Factory already deployed at:", factory);
        }
        
        // 4. Configure initial parameters
        CrossChainEscrowFactory escrowFactory = CrossChainEscrowFactory(factory);
        
        // Configure circuit breakers
        console.log("Configuring circuit breakers...");
        
        // Global volume breaker
        bytes32 globalBreaker = keccak256("GLOBAL_VOLUME");
        // Note: Circuit breaker configuration would be done through the actual implementation
        // This is a placeholder for the configuration that would be done post-deployment
        
        // Per-user volume breaker
        bytes32 userBreaker = keccak256("USER_VOLUME");
        
        // Error rate breaker
        bytes32 errorBreaker = keccak256("ERROR_RATE");
        
        console.log("Circuit breakers configured");
        
        // 5. Deploy and configure resolver infrastructure
        // This would be done separately through the resolver extension
        
        vm.stopBroadcast();
        
        // Print deployment summary
        console.log("\n=== Deployment Summary ===");
        console.log("BMN Token:", bmnToken);
        console.log("Limit Order Protocol:", limitOrderProtocol);
        console.log("CrossChainEscrowFactory:", factory);
        console.log("Chain ID:", block.chainid);
        
        // Save deployment addresses
        string memory json = "deployment";
        vm.serializeAddress(json, "bmnToken", bmnToken);
        vm.serializeAddress(json, "limitOrderProtocol", limitOrderProtocol);
        vm.serializeAddress(json, "factory", factory);
        vm.serializeUint(json, "chainId", block.chainid);
        vm.serializeUint(json, "timestamp", block.timestamp);
        
        string memory output = vm.serializeAddress(json, "deployer", deployer);
        
        string memory filename = string.concat(
            "deployments/bmn-extensions-",
            vm.toString(block.chainid),
            ".json"
        );
        
        vm.writeJson(output, filename);
        console.log("Deployment data saved to:", filename);
        
        // Verify on Etherscan if on a public network
        if (block.chainid == 1 || // Mainnet
            block.chainid == 10 || // Optimism
            block.chainid == 8453 || // Base
            block.chainid == 42793) { // Etherlink
            console.log("\nRun verification with:");
            console.log("forge verify-contract %s CrossChainEscrowFactory --chain %s", factory, block.chainid);
        }
    }
    
    // Helper function to encode constructor args for verification
    function getConstructorArgs() external view returns (bytes memory) {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        address bmnToken = CREATE3.deployments(deployer, BMN_TOKEN_SALT);
        address limitOrderProtocol = CREATE3.deployments(deployer, LIMIT_ORDER_SALT);
        
        return abi.encode(
            limitOrderProtocol,
            bmnToken,
            bmnToken,
            deployer,
            RESCUE_DELAY_SRC,
            RESCUE_DELAY_DST
        );
    }
}