// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IBMNToken is IERC20 {
    function mint(address to, uint256 amount) external;
    function owner() external view returns (address);
}

contract MintForTest is Script {
    address constant BMN_TOKEN = 0x18ae5BB6E03Dc346eA9fd1afA78FEc314343857e;
    address constant ALICE = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
    address constant BOB = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;
    uint256 constant MINT_AMOUNT = 100 ether; // 100 BMN

    function run() external {
        string memory chain = vm.envString("TARGET_CHAIN");
        address target = vm.envAddress("TARGET_ADDRESS");
        
        console.log("Minting on chain:", chain);
        console.log("Target address:", target);
        
        vm.startBroadcast();
        
        IBMNToken bmn = IBMNToken(BMN_TOKEN);
        
        // Check current balance
        uint256 currentBalance = bmn.balanceOf(target);
        console.log("Current balance:", currentBalance);
        
        if (currentBalance < 15 ether) {
            console.log("Minting", MINT_AMOUNT, "BMN to", target);
            bmn.mint(target, MINT_AMOUNT);
            console.log("New balance:", bmn.balanceOf(target));
        } else {
            console.log("Sufficient balance, skipping mint");
        }
        
        vm.stopBroadcast();
    }
}
