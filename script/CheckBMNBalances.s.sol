// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../contracts/BMNAccessTokenV2.sol";

/**
 * @title Check BMN Token Balances
 * @notice Checks BMN token balances on Base and Etherlink
 * @dev Run with: forge script script/CheckBMNBalances.s.sol --rpc-url base
 */
contract CheckBMNBalances is Script {
    address constant BMN_TOKEN = 0x18ae5BB6E03Dc346eA9fd1afA78FEc314343857e;
    address constant DEPLOYER = 0x5f29827e25dc174a6A51C99e6811Bbd7581285b0;
    address constant ALICE = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
    address constant BOB_RESOLVER = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;

    function run() external view {
        BMNAccessTokenV2 token = BMNAccessTokenV2(BMN_TOKEN);
        
        console.log("=== BMN Token Balances ===");
        console.log("Chain ID:", block.chainid);
        console.log("BMN Token:", BMN_TOKEN);
        console.log("");
        
        uint256 deployerBalance = token.balanceOf(DEPLOYER);
        uint256 aliceBalance = token.balanceOf(ALICE);
        uint256 bobBalance = token.balanceOf(BOB_RESOLVER);
        
        console.log("Deployer:", deployerBalance, "BMN");
        console.log("Alice:", aliceBalance, "BMN");
        console.log("Bob/Resolver:", bobBalance, "BMN");
        console.log("");
        
        // Check authorization status
        console.log("=== Authorization Status ===");
        console.log("Deployer authorized:", token.authorized(DEPLOYER));
        console.log("Alice authorized:", token.authorized(ALICE));
        console.log("Bob authorized:", token.authorized(BOB_RESOLVER));
    }
}