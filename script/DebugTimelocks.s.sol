// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { Timelocks, TimelocksLib } from "../contracts/libraries/TimelocksLib.sol";

contract DebugTimelocks is Script {
    using TimelocksLib for Timelocks;

    function run() external view {
        // Original timelocks from the transaction
        uint256 originalTimelocks = 0x000003840000012c00000000000004b0000003840000012c00000000;
        console.log("Original timelocks:", vm.toString(originalTimelocks));
        console.log("Original timelocks (hex):", vm.toString(bytes32(originalTimelocks)));
        
        // Deployment timestamp
        uint256 deploymentTimestamp = 1754186605;
        console.log("Deployment timestamp:", deploymentTimestamp);
        console.log("Deployment timestamp (hex):", vm.toString(bytes32(deploymentTimestamp)));
        
        // Set deployment timestamp
        Timelocks timelocks = Timelocks.wrap(originalTimelocks);
        Timelocks deployedTimelocks = timelocks.setDeployedAt(deploymentTimestamp);
        
        uint256 deployedTimelocksValue = Timelocks.unwrap(deployedTimelocks);
        console.log("Deployed timelocks:", deployedTimelocksValue);
        console.log("Deployed timelocks (hex):", vm.toString(bytes32(deployedTimelocksValue)));
    }
}