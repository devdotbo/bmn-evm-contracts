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
    // Factory addresses (v2.3 via CREATE3, same on both chains)
    address constant FACTORY_V2_3 = 0xdebE6F4bC7BaAD2266603Ba7AfEB3BB6dDA9FE0A;
    
    // Resolver to whitelist
    address constant RESOLVER = 0xfdF1dDeB176BEA06c7430166e67E615bC312b7B5; // Bob
    
    function run() external {
        // Get deployer private key (factory owner)
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        
        // Whitelist on Base
        console.log("\n=== WHITELISTING RESOLVER ON BASE ===");
        vm.createSelectFork(vm.envString("BASE_RPC_URL"));
        _whitelistResolver(FACTORY_V2_3, RESOLVER, deployerPrivateKey, "BASE");
        
        // Whitelist on Optimism
        console.log("\n=== WHITELISTING RESOLVER ON OPTIMISM ===");
        vm.createSelectFork(vm.envString("OPTIMISM_RPC_URL"));
        _whitelistResolver(FACTORY_V2_3, RESOLVER, deployerPrivateKey, "OPTIMISM");
        
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