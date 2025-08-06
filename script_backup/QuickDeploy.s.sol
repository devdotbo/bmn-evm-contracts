// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import "../contracts/SimplifiedEscrowFactory.sol";
import "../contracts/EscrowSrc.sol";
import "../contracts/EscrowDst.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

/**
 * @title QuickDeploy
 * @notice Quick deployment script for immediate mainnet deployment
 * @dev Deploy with: forge script script/QuickDeploy.s.sol --rpc-url $RPC_URL --broadcast --verify
 */
contract QuickDeploy is Script {
    
    function run() public {
        // Get deployer key
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("=== BMN Quick Deployment ===");
        console.log("Deployer:", deployer);
        console.log("Chain ID:", block.chainid);
        
        // Configuration based on chain
        address bmnToken;
        uint32 rescueDelay = 7 days;
        
        if (block.chainid == 8453) { // Base
            bmnToken = 0x8287CD2aC7E227D9D927F998EB600a0683a832A1;
            console.log("Deploying to Base Mainnet");
        } else if (block.chainid == 10) { // Optimism
            bmnToken = 0x8287CD2aC7E227D9D927F998EB600a0683a832A1;
            console.log("Deploying to Optimism Mainnet");
        } else if (block.chainid == 42793) { // Etherlink
            bmnToken = 0x8287CD2aC7E227D9D927F998EB600a0683a832A1;
            console.log("Deploying to Etherlink Mainnet");
        } else {
            // Local testing - deploy mock token
            bmnToken = address(0);
            rescueDelay = 1 hours;
            console.log("Deploying to Local/Test Network");
        }
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy mock token if needed
        if (bmnToken == address(0)) {
            MockToken mock = new MockToken();
            bmnToken = address(mock);
            console.log("Deployed mock BMN token:", bmnToken);
        }
        
        // Deploy implementations
        console.log("\nDeploying implementations...");
        
        address srcImpl = address(new EscrowSrc(rescueDelay, IERC20(bmnToken)));
        console.log("EscrowSrc:", srcImpl);
        
        address dstImpl = address(new EscrowDst(rescueDelay, IERC20(bmnToken)));
        console.log("EscrowDst:", dstImpl);
        
        // Deploy factory
        console.log("\nDeploying SimplifiedEscrowFactory...");
        SimplifiedEscrowFactory factory = new SimplifiedEscrowFactory(
            srcImpl,
            dstImpl,
            deployer
        );
        console.log("Factory:", address(factory));
        
        // Add test resolver if local
        if (block.chainid == 31337) {
            address testResolver = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC; // Bob
            factory.addResolver(testResolver);
            console.log("Added test resolver:", testResolver);
        }
        
        vm.stopBroadcast();
        
        // Save deployment
        _saveDeployment(address(factory), srcImpl, dstImpl);
        
        console.log("\n=== Deployment Complete ===");
        console.log("\nVerify contracts:");
        console.log("forge verify-contract", address(factory), "SimplifiedEscrowFactory --chain-id", block.chainid);
        console.log("\nWhitelist resolvers:");
        console.log("cast send", address(factory), "addResolver(address) RESOLVER_ADDRESS --private-key KEY");
        console.log("\nTest with small amount first!");
    }
    
    function _saveDeployment(address factory, address srcImpl, address dstImpl) internal {
        string memory chainName = _getChainName();
        string memory path = string.concat("deployments/", chainName, "-quick.json");
        
        string memory json = "deployment";
        vm.serializeAddress(json, "factory", factory);
        vm.serializeAddress(json, "srcImpl", srcImpl);
        vm.serializeAddress(json, "dstImpl", dstImpl);
        vm.serializeUint(json, "timestamp", block.timestamp);
        string memory output = vm.serializeUint(json, "block", block.number);
        
        vm.writeJson(output, path);
        console.log("Saved to:", path);
    }
    
    function _getChainName() internal view returns (string memory) {
        if (block.chainid == 8453) return "base";
        if (block.chainid == 10) return "optimism";
        if (block.chainid == 42793) return "etherlink";
        if (block.chainid == 31337) return "local";
        return "unknown";
    }
}

// Minimal mock token for testing
contract MockToken {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    
    function transfer(address to, uint256 amount) external returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }
    
    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }
    
    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}