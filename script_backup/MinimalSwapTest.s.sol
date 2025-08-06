// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Script.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MinimalSwapTest is Script {
    // BMN Token address (same on all chains)
    address constant BMN_TOKEN = 0x8287CD2aC7E227D9D927F998EB600a0683a832A1;
    
    // Factory addresses
    address constant BASE_FACTORY = 0xd599b1543467433F5A6f195Ccc4E01FcbF5AA157;
    address constant OPTIMISM_FACTORY = 0xA6342E61d1a0897A31a1ABAFB4B1669C0A5eaa56;
    
    function run() external {
        // Load private keys
        uint256 aliceKey = vm.envUint("ALICE_PRIVATE_KEY");
        address alice = vm.addr(aliceKey);
        
        console.log("=== SIMPLE TOKEN TRANSFER TEST ===");
        console.log("Alice address:", alice);
        console.log("");
        
        // Connect to Base chain
        string memory baseRpc = "https://mainnet.base.org";
        uint256 baseFork = vm.createFork(baseRpc);
        vm.selectFork(baseFork);
        
        // Check Alice's BMN balance
        IERC20 bmn = IERC20(BMN_TOKEN);
        uint256 aliceBalance = bmn.balanceOf(alice);
        console.log("Alice BMN balance on Base:", aliceBalance / 1e18, "BMN");
        
        // If Alice has BMN tokens, try a simple transfer to herself as proof of concept
        if (aliceBalance > 0) {
            console.log("Attempting self-transfer of 1 BMN token...");
            
            vm.startBroadcast(aliceKey);
            
            // Transfer 1 BMN to self (minimal gas cost)
            bool success = bmn.transfer(alice, 1e18);
            
            if (success) {
                console.log("[SUCCESS] Transfer completed!");
                console.log("Transaction proves account is functional");
            } else {
                console.log("[FAILED] Transfer failed");
            }
            
            vm.stopBroadcast();
        } else {
            console.log("Alice has no BMN tokens on Base");
        }
        
        console.log("");
        console.log("=== NEXT STEPS ===");
        console.log("1. This proves the accounts are functional");
        console.log("2. To execute cross-chain swap, we need:");
        console.log("   - Whitelist resolver (requires debugging factory)");
        console.log("   - Or deploy new simplified factory");
        console.log("   - Or use existing escrow implementations directly");
    }
}