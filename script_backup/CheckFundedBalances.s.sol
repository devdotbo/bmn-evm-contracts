// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Script.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract CheckFundedBalances is Script {
    // BMN Token address (same on all chains)
    address constant BMN_TOKEN = 0x8287CD2aC7E227D9D927F998EB600a0683a832A1;
    
    // Factory addresses
    address constant BASE_FACTORY = 0xd599b1543467433F5A6f195Ccc4E01FcbF5AA157;
    address constant OPTIMISM_FACTORY = 0xA6342E61d1a0897A31a1ABAFB4B1669C0A5eaa56;
    
    function run() external {
        // Load private keys from environment
        uint256 resolverKey = vm.envUint("RESOLVER_PRIVATE_KEY");
        uint256 aliceKey = vm.envUint("ALICE_PRIVATE_KEY");
        uint256 deployerKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        
        // Get addresses
        address resolver = vm.addr(resolverKey);
        address alice = vm.addr(aliceKey);
        address deployer = vm.addr(deployerKey);
        
        console.log("=== Account Addresses ===");
        console.log("Resolver:", resolver);
        console.log("Alice:", alice);
        console.log("Deployer:", deployer);
        console.log("");
        
        // Check Base chain
        console.log("=== BASE CHAIN BALANCES ===");
        string memory baseRpc = "https://mainnet.base.org";
        uint256 baseFork = vm.createFork(baseRpc);
        vm.selectFork(baseFork);
        
        console.log("ETH Balances:");
        console.log("  Resolver:", resolver.balance / 1e15, "finney");
        console.log("  Alice:", alice.balance / 1e15, "finney");
        console.log("  Deployer:", deployer.balance / 1e15, "finney");
        
        console.log("BMN Token Balances:");
        IERC20 bmnBase = IERC20(BMN_TOKEN);
        console.log("  Resolver:", bmnBase.balanceOf(resolver) / 1e18, "BMN");
        console.log("  Alice:", bmnBase.balanceOf(alice) / 1e18, "BMN");
        console.log("  Deployer:", bmnBase.balanceOf(deployer) / 1e18, "BMN");
        console.log("");
        
        // Check Optimism chain
        console.log("=== OPTIMISM CHAIN BALANCES ===");
        string memory optimismRpc = "https://mainnet.optimism.io";
        uint256 optimismFork = vm.createFork(optimismRpc);
        vm.selectFork(optimismFork);
        
        console.log("ETH Balances:");
        console.log("  Resolver:", resolver.balance / 1e15, "finney");
        console.log("  Alice:", alice.balance / 1e15, "finney");
        console.log("  Deployer:", deployer.balance / 1e15, "finney");
        
        console.log("BMN Token Balances:");
        IERC20 bmnOptimism = IERC20(BMN_TOKEN);
        console.log("  Resolver:", bmnOptimism.balanceOf(resolver) / 1e18, "BMN");
        console.log("  Alice:", bmnOptimism.balanceOf(alice) / 1e18, "BMN");
        console.log("  Deployer:", bmnOptimism.balanceOf(deployer) / 1e18, "BMN");
        console.log("");
        
        // Check if resolver is whitelisted on Base
        vm.selectFork(baseFork);
        console.log("=== RESOLVER STATUS ===");
        // We'll check this via cast command since we don't have the factory interface here
        console.log("Check resolver whitelist status with:");
        console.log("cast call [BASE_FACTORY] \"resolvers(address)\" [resolver] --rpc-url $BASE_RPC_URL");
    }
}