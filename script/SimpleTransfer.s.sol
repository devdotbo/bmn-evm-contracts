// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract SimpleTransfer is Script {
    address constant BMN_TOKEN = 0xf410a63e825C162274c3295F13EcA1Dd1202b5cC;
    address constant ALICE = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
    address constant BOB = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;
    uint256 constant TRANSFER_AMOUNT = 100 ether; // 100 BMN

    function run() external {
        vm.startBroadcast();
        
        IERC20 bmn = IERC20(BMN_TOKEN);
        
        // Transfer to Alice on Base
        console.log("Transferring 100 BMN to Alice on Base");
        console.log("Alice balance before:", bmn.balanceOf(ALICE));
        
        bool success = bmn.transfer(ALICE, TRANSFER_AMOUNT);
        require(success, "Transfer to Alice failed");
        
        console.log("Alice balance after:", bmn.balanceOf(ALICE));
        
        vm.stopBroadcast();
    }
}