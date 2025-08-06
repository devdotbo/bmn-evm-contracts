// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import "../contracts/SimplifiedEscrowFactory.sol";

/**
 * @title WhitelistResolver
 * @notice Script to whitelist resolvers on both Base and Optimism factories
 * @dev Used to fix the factory configuration and enable atomic swaps
 */
contract WhitelistResolver is Script {
    // Factory addresses
    address constant BASE_FACTORY = 0xd599b1543467433F5A6f195Ccc4E01FcbF5AA157;
    address constant OPTIMISM_FACTORY = 0xA6342E61d1a0897A31a1ABAFB4B1669C0A5eaa56;
    
    // Resolver to whitelist
    address constant RESOLVER = 0xc18c3C96E20FaD1c656a5c4ed2F4f7871BD42be1;
    
    function run() external {
        // Get deployer private key (factory owner)
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        
        // Whitelist on Base
        console.log("\n=== WHITELISTING RESOLVER ON BASE ===");
        vm.createSelectFork("https://base.rpc.thirdweb.com");
        _whitelistResolver(BASE_FACTORY, RESOLVER, deployerPrivateKey, "BASE");
        
        // Whitelist on Optimism
        console.log("\n=== WHITELISTING RESOLVER ON OPTIMISM ===");
        vm.createSelectFork("https://mainnet.optimism.io");
        _whitelistResolver(OPTIMISM_FACTORY, RESOLVER, deployerPrivateKey, "OPTIMISM");
        
        console.log("\n=== WHITELISTING COMPLETE ===");
        console.log("Resolver %s is now whitelisted on both chains", RESOLVER);
    }
    
    function _whitelistResolver(
        address factoryAddr,
        address resolver,
        uint256 ownerKey,
        string memory chain
    ) internal {
        vm.startBroadcast(ownerKey);
        
        SimplifiedEscrowFactory factory = SimplifiedEscrowFactory(factoryAddr);
        
        console.log("[%s] Factory: %s", chain, factoryAddr);
        console.log("[%s] Owner: %s", chain, factory.owner());
        
        if (!factory.whitelistedResolvers(resolver)) {
            console.log("[%s] Adding resolver to whitelist...", chain);
            factory.addResolver(resolver);
            console.log("[%s] Resolver added successfully!", chain);
        } else {
            console.log("[%s] Resolver already whitelisted", chain);
        }
        
        console.log("[%s] Whitelist status: %s", chain, factory.whitelistedResolvers(resolver));
        console.log("[%s] Total resolvers: %s", chain, factory.resolverCount());
        
        vm.stopBroadcast();
    }
}