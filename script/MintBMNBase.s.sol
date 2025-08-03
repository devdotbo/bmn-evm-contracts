// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../contracts/BMNAccessTokenV2.sol";

contract MintBMNBase is Script {
    address constant BMN_TOKEN = 0x18ae5BB6E03Dc346eA9fd1afA78FEc314343857e;
    address constant ALICE = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
    uint256 constant MINT_AMOUNT = 100 * 10**18; // 100 BMN tokens
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("=== MINTING BMN ON BASE ===");
        console.log("Chain ID:", block.chainid);
        console.log("BMN Token:", BMN_TOKEN);
        console.log("Alice:", ALICE);
        console.log("Deployer:", deployer);
        console.log("");
        
        vm.startBroadcast(deployerPrivateKey);
        
        BMNAccessTokenV2 token = BMNAccessTokenV2(BMN_TOKEN);
        
        // Check owner
        address owner = token.owner();
        console.log("Token owner:", owner);
        require(owner == deployer, "Deployer is not the owner");
        
        // Check current balance
        uint256 balanceBefore = token.balanceOf(ALICE);
        console.log("Alice balance before:", balanceBefore);
        
        // Authorize and mint in one transaction if needed
        if (!token.authorized(ALICE)) {
            console.log("Authorizing Alice...");
            token.authorize(ALICE);
        }
        
        // Mint tokens to Alice
        console.log("Minting", MINT_AMOUNT / 10**18, "BMN tokens to Alice...");
        token.mint(ALICE, MINT_AMOUNT);
        
        uint256 balanceAfter = token.balanceOf(ALICE);
        console.log("Alice balance after:", balanceAfter);
        console.log("Successfully minted", (balanceAfter - balanceBefore) / 10**18, "BMN tokens");
        
        vm.stopBroadcast();
    }
}