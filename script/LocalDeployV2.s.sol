// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import { CrossChainEscrowFactory } from "../contracts/CrossChainEscrowFactory.sol";
import { EscrowSrc } from "../contracts/EscrowSrc.sol";
import { EscrowDst } from "../contracts/EscrowDst.sol";
import { TokenMock } from "../contracts/mocks/TokenMock.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title LocalDeployV2
 * @notice Deploy CrossChainEscrowFactory v2.1.0 locally with Bob whitelisted
 * @dev Deploys factory with security features and whitelists local test accounts
 */
contract LocalDeployV2 is Script {
    // Test accounts (Anvil defaults)
    address constant DEPLOYER = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address constant ALICE = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
    address constant BOB = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;
    
    // Deployed contracts
    CrossChainEscrowFactory public factory;
    TokenMock public tokenA;
    TokenMock public tokenB;
    TokenMock public bmnToken;
    EscrowSrc public srcImplementation;
    EscrowDst public dstImplementation;
    
    function run() external {
        console.log("==============================================");
        console.log("Deploying CrossChainEscrowFactory v2.1.0 Locally");
        console.log("==============================================");
        console.log("Chain ID:", block.chainid);
        console.log("Deployer:", DEPLOYER);
        console.log("Bob (Resolver):", BOB);
        console.log("Alice (User):", ALICE);
        
        // Start deployment
        vm.startBroadcast(DEPLOYER);
        
        // Deploy BMN token (same on both chains for simplicity)
        bmnToken = new TokenMock("BMN Token", "BMN", 18);
        console.log("\n[TOKEN] Deployed BMN:", address(bmnToken));
        
        // Deploy token for this chain
        if (block.chainid == 31337 || block.chainid == 1337) {
            // Chain A - deploy TKA
            tokenA = new TokenMock("Token A", "TKA", 18);
            console.log("[TOKEN] Deployed TKA:", address(tokenA));
            
            // Mint tokens for testing
            tokenA.mint(ALICE, 1000 * 10**18);
            tokenA.mint(BOB, 500 * 10**18);
            console.log("[MINT] Alice: 1000 TKA");
            console.log("[MINT] Bob: 500 TKA");
        } else if (block.chainid == 1338) {
            // Chain B - deploy TKB
            tokenB = new TokenMock("Token B", "TKB", 18);
            console.log("[TOKEN] Deployed TKB:", address(tokenB));
            
            // Mint tokens for testing
            tokenB.mint(ALICE, 100 * 10**18);
            tokenB.mint(BOB, 1000 * 10**18);
            console.log("[MINT] Alice: 100 TKB");
            console.log("[MINT] Bob: 1000 TKB");
        }
        
        // Mint BMN tokens for access control
        bmnToken.mint(BOB, 1000 * 10**18);
        bmnToken.mint(ALICE, 100 * 10**18);
        console.log("[MINT] Bob: 1000 BMN (resolver access)");
        console.log("[MINT] Alice: 100 BMN");
        
        // Deploy escrow implementations
        uint32 rescueDelay = 2 hours;
        srcImplementation = new EscrowSrc(rescueDelay, bmnToken);
        dstImplementation = new EscrowDst(rescueDelay, bmnToken);
        console.log("\n[ESCROW] Source Implementation:", address(srcImplementation));
        console.log("[ESCROW] Destination Implementation:", address(dstImplementation));
        
        // Deploy a simple limit order protocol mock (or use a dummy address for local testing)
        // For local testing, we can use a placeholder address
        address limitOrderProtocol = address(0x1111111111111111111111111111111111111111);
        
        // Deploy factory
        factory = new CrossChainEscrowFactory(
            limitOrderProtocol,
            bmnToken,  // fee token
            bmnToken,  // bmn token
            DEPLOYER,  // owner
            rescueDelay,  // rescue delay src
            rescueDelay   // rescue delay dst
        );
        console.log("\n[FACTORY] CrossChainEscrowFactory v2.1.0:", address(factory));
        console.log("[FACTORY] Version:", factory.VERSION());
        console.log("[FACTORY] Owner:", factory.owner());
        
        // Whitelist Bob as resolver
        console.log("\n[WHITELIST] Adding Bob as resolver...");
        if (!factory.whitelistedResolvers(BOB)) {
            factory.addResolverToWhitelist(BOB);
            console.log("[OK] Bob whitelisted");
        } else {
            console.log("[OK] Bob already whitelisted");
        }
        
        // Check if deployer is already whitelisted (usually is by default)
        if (!factory.whitelistedResolvers(DEPLOYER)) {
            console.log("[WHITELIST] Adding Deployer as resolver...");
            factory.addResolverToWhitelist(DEPLOYER);
            console.log("[OK] Deployer whitelisted");
        } else {
            console.log("[OK] Deployer already whitelisted");
        }
        
        vm.stopBroadcast();
        
        // Verify deployment
        console.log("\n==============================================");
        console.log("DEPLOYMENT COMPLETE");
        console.log("==============================================");
        
        // Check whitelist status
        bool isBobWhitelisted = factory.whitelistedResolvers(BOB);
        bool isDeployerWhitelisted = factory.whitelistedResolvers(DEPLOYER);
        
        console.log("\n[VERIFICATION]");
        console.log("Bob whitelisted:", isBobWhitelisted ? "YES" : "NO");
        console.log("Deployer whitelisted:", isDeployerWhitelisted ? "YES" : "NO");
        console.log("Total resolvers:", factory.resolverCount());
        console.log("Factory paused:", factory.emergencyPaused() ? "YES" : "NO");
        
        // Save deployment info
        string memory chainName = block.chainid == 31337 || block.chainid == 1337 ? "chain-a" : "chain-b";
        address chainToken = address(tokenA) != address(0) ? address(tokenA) : address(tokenB);
        string memory json = string.concat(
            '{"factory":"', vm.toString(address(factory)), '",',
            '"srcImpl":"', vm.toString(address(srcImplementation)), '",',
            '"dstImpl":"', vm.toString(address(dstImplementation)), '",',
            '"bmnToken":"', vm.toString(address(bmnToken)), '",',
            '"token":"', vm.toString(chainToken), '",',
            '"chainId":', vm.toString(block.chainid), ',',
            '"bobWhitelisted":', isBobWhitelisted ? 'true' : 'false', '}'
        );
        
        string memory path = string.concat("deployments/local-", chainName, "-v2.json");
        vm.writeFile(path, json);
        console.log("\n[SAVED] Deployment info to:", path);
        
        // Display summary
        console.log("\n[SUMMARY]");
        console.log("- Factory supports resolver whitelist");
        console.log("- Bob can now execute swaps as resolver");
        console.log("- Emergency pause available if needed");
        console.log("- Ready for cross-chain atomic swaps");
    }
}