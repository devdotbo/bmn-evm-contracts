// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { Script, console } from "forge-std/Script.sol";
import { EscrowFactory } from "../contracts/EscrowFactory.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MainnetDeploy is Script {
    // BMN Access Token deployed with CREATE2 - same on all chains
    address constant BMN_ACCESS_TOKEN = 0xaa0D55FF5c69584c085F503900Af10628517ddbE;
    
    function run() external {
        uint256 deployerKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);
        
        vm.startBroadcast(deployerKey);
        
        EscrowFactory factory = new EscrowFactory(
            address(0), // No limit order protocol needed for mainnet
            IERC20(address(0)), // Fee token - not used
            IERC20(BMN_ACCESS_TOKEN), // BMN Access token for public functions
            deployer, // Owner
            86400,  // rescueDelaySrc: 1 day
            86400   // rescueDelayDst: 1 day
        );
        
        console.log("=== MAINNET DEPLOYMENT ===");
        console.log("Factory deployed at:", address(factory));
        console.log("Src Implementation:", factory.ESCROW_SRC_IMPLEMENTATION());
        console.log("Dst Implementation:", factory.ESCROW_DST_IMPLEMENTATION());
        console.log("Access Token:", BMN_ACCESS_TOKEN);
        console.log("=======================");
        
        vm.stopBroadcast();
    }
}
