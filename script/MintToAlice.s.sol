// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { Script, console } from "forge-std/Script.sol";
import { BMNAccessTokenV2 } from "../contracts/BMNAccessTokenV2.sol";

contract MintToAlice is Script {
    // BMN Access Token V2 deployed with CREATE2 - same on all chains
    address constant BMN_TOKEN = 0x18ae5BB6E03Dc346eA9fd1afA78FEc314343857e;
    
    // Alice's address (from test accounts)
    address constant ALICE = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
    
    // Amount to mint to Alice (100 BMN in 18-decimals)
    uint256 constant MINT_AMOUNT = 100 * 10**18;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("=== MINTING BMN TO ALICE ===");
        console.log("Chain ID:", block.chainid);
        console.log("BMN Token:", BMN_TOKEN);
        console.log("Alice:", ALICE);
        console.log("");
        
        vm.startBroadcast(deployerPrivateKey);
        
        BMNAccessTokenV2 token = BMNAccessTokenV2(BMN_TOKEN);
        
        // Authorize Alice if needed
        if (!token.authorized(ALICE)) {
            console.log("Authorizing Alice...");
            token.authorize(ALICE);
            console.log("Alice authorized");
        }
        
        // Check current balance
        uint256 balanceBefore = token.balanceOf(ALICE);
        console.log("Alice balance before:", balanceBefore);
        
        // Mint tokens to Alice
        token.mint(ALICE, MINT_AMOUNT);
        
        uint256 balanceAfter = token.balanceOf(ALICE);
        console.log("Alice balance after:", balanceAfter);
        console.log("Minted", balanceAfter - balanceBefore, "BMN tokens to Alice");
        
        vm.stopBroadcast();
    }
}