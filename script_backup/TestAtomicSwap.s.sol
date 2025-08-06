// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Script.sol";
import "../contracts/SimpleAtomicSwap.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract TestAtomicSwap is Script {
    // Test accounts (Anvil defaults)
    address constant ALICE = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
    address constant RESOLVER = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;
    
    // BMN Token address (same on all chains)
    address constant BMN_TOKEN = 0x8287CD2aC7E227D9D927F998EB600a0683a832A1;
    
    // Test parameters
    uint256 constant SWAP_AMOUNT = 100 * 10**18; // 100 BMN
    uint256 constant TIMELOCK_DURATION = 1 hours;
    
    function run() external {
        // Generate secret and hashlock
        bytes32 secret = keccak256(abi.encodePacked("test_secret_123", block.timestamp));
        bytes32 hashlock = keccak256(abi.encodePacked(secret));
        
        console.log("Starting Simple Atomic Swap Test");
        console.log("Secret:", vm.toString(secret));
        console.log("Hashlock:", vm.toString(hashlock));
        
        // Deploy on Base
        console.log("\n[OK] Deploying on Base...");
        vm.createSelectFork(vm.envString("BASE_RPC_URL"));
        
        vm.startBroadcast(vm.envUint("DEPLOYER_PRIVATE_KEY"));
        SimpleAtomicSwap baseSwap = new SimpleAtomicSwap();
        console.log("Base SimpleAtomicSwap:", address(baseSwap));
        vm.stopBroadcast();
        
        // Deploy on Optimism
        console.log("\n[OK] Deploying on Optimism...");
        vm.createSelectFork(vm.envString("OPTIMISM_RPC_URL"));
        
        vm.startBroadcast(vm.envUint("DEPLOYER_PRIVATE_KEY"));
        SimpleAtomicSwap optimismSwap = new SimpleAtomicSwap();
        console.log("Optimism SimpleAtomicSwap:", address(optimismSwap));
        vm.stopBroadcast();
        
        // Setup test tokens
        console.log("\n[OK] Setting up test tokens...");
        
        // On Base - Check Alice balance and approve
        vm.selectFork(0); // Base fork
        IERC20 baseToken = IERC20(BMN_TOKEN);
        uint256 aliceBaseBalance = baseToken.balanceOf(ALICE);
        console.log("Alice Base BMN balance:", aliceBaseBalance / 10**18);
        
        if (aliceBaseBalance >= SWAP_AMOUNT) {
            vm.startPrank(ALICE);
            baseToken.approve(address(baseSwap), SWAP_AMOUNT);
            vm.stopPrank();
        } else {
            console.log("[WARNING] Alice doesn't have enough BMN on Base");
            console.log("Please ensure Alice has at least 100 BMN on Base");
            return;
        }
        
        // On Optimism - Check Resolver balance and approve
        vm.selectFork(1); // Optimism fork
        IERC20 optimismToken = IERC20(BMN_TOKEN);
        uint256 resolverOptBalance = optimismToken.balanceOf(RESOLVER);
        console.log("Resolver Optimism BMN balance:", resolverOptBalance / 10**18);
        
        if (resolverOptBalance >= SWAP_AMOUNT) {
            vm.startPrank(RESOLVER);
            optimismToken.approve(address(optimismSwap), SWAP_AMOUNT);
            vm.stopPrank();
        } else {
            console.log("[WARNING] Resolver doesn't have enough BMN on Optimism");
            console.log("Please ensure Resolver has at least 100 BMN on Optimism");
            return;
        }
        
        // Step 1: Alice creates swap on Base (Alice sends BMN to Resolver)
        console.log("\n[OK] Step 1: Alice creates swap on Base...");
        vm.selectFork(0); // Base
        vm.startPrank(ALICE);
        
        uint256 aliceBalanceBefore = baseToken.balanceOf(ALICE);
        bytes32 baseSwapId = baseSwap.createSwap(
            RESOLVER,
            BMN_TOKEN,
            SWAP_AMOUNT,
            hashlock,
            block.timestamp + TIMELOCK_DURATION
        );
        uint256 aliceBalanceAfter = baseToken.balanceOf(ALICE);
        
        console.log("Base Swap ID:", vm.toString(baseSwapId));
        console.log("Alice balance before:", aliceBalanceBefore / 10**18, "BMN");
        console.log("Alice balance after:", aliceBalanceAfter / 10**18, "BMN");
        console.log("Tokens locked:", (aliceBalanceBefore - aliceBalanceAfter) / 10**18, "BMN");
        vm.stopPrank();
        
        // Step 2: Resolver creates swap on Optimism (Resolver sends BMN to Alice)
        console.log("\n[OK] Step 2: Resolver creates swap on Optimism...");
        vm.selectFork(1); // Optimism
        vm.startPrank(RESOLVER);
        
        uint256 resolverBalanceBefore = optimismToken.balanceOf(RESOLVER);
        bytes32 optimismSwapId = optimismSwap.createSwap(
            ALICE,
            BMN_TOKEN,
            SWAP_AMOUNT,
            hashlock, // Same hashlock!
            block.timestamp + TIMELOCK_DURATION
        );
        uint256 resolverBalanceAfter = optimismToken.balanceOf(RESOLVER);
        
        console.log("Optimism Swap ID:", vm.toString(optimismSwapId));
        console.log("Resolver balance before:", resolverBalanceBefore / 10**18, "BMN");
        console.log("Resolver balance after:", resolverBalanceAfter / 10**18, "BMN");
        console.log("Tokens locked:", (resolverBalanceBefore - resolverBalanceAfter) / 10**18, "BMN");
        vm.stopPrank();
        
        // Step 3: Alice withdraws on Optimism with secret
        console.log("\n[OK] Step 3: Alice withdraws on Optimism with secret...");
        vm.selectFork(1); // Optimism
        vm.startPrank(ALICE);
        
        uint256 aliceOptBalanceBefore = optimismToken.balanceOf(ALICE);
        optimismSwap.withdraw(optimismSwapId, secret);
        uint256 aliceOptBalanceAfter = optimismToken.balanceOf(ALICE);
        
        console.log("Alice Optimism balance before:", aliceOptBalanceBefore / 10**18, "BMN");
        console.log("Alice Optimism balance after:", aliceOptBalanceAfter / 10**18, "BMN");
        console.log("Alice received:", (aliceOptBalanceAfter - aliceOptBalanceBefore) / 10**18, "BMN");
        vm.stopPrank();
        
        // Step 4: Resolver withdraws on Base with same secret
        console.log("\n[OK] Step 4: Resolver withdraws on Base with same secret...");
        vm.selectFork(0); // Base
        vm.startPrank(RESOLVER);
        
        uint256 resolverBaseBalanceBefore = baseToken.balanceOf(RESOLVER);
        baseSwap.withdraw(baseSwapId, secret);
        uint256 resolverBaseBalanceAfter = baseToken.balanceOf(RESOLVER);
        
        console.log("Resolver Base balance before:", resolverBaseBalanceBefore / 10**18, "BMN");
        console.log("Resolver Base balance after:", resolverBaseBalanceAfter / 10**18, "BMN");
        console.log("Resolver received:", (resolverBaseBalanceAfter - resolverBaseBalanceBefore) / 10**18, "BMN");
        vm.stopPrank();
        
        // Final summary
        console.log("\n[SUCCESS] ATOMIC SWAP COMPLETE!");
        console.log("- Alice sent 100 BMN on Base, received 100 BMN on Optimism");
        console.log("- Resolver sent 100 BMN on Optimism, received 100 BMN on Base");
        console.log("- Both parties successfully exchanged tokens atomically!");
    }
}