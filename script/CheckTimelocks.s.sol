// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import {TimelocksLib, Timelocks} from "../contracts/libraries/TimelocksLib.sol";
import {IBaseEscrow} from "../contracts/interfaces/IBaseEscrow.sol";

contract CheckTimelocks is Script {
    using TimelocksLib for Timelocks;
    
    function run() external view {
        // Load immutables from state file
        string memory stateJson = vm.readFile("deployments/mainnet-test-state.json");
        bytes memory srcImmutablesData = vm.parseJsonBytes(stateJson, ".srcImmutables");
        IBaseEscrow.Immutables memory immutables = abi.decode(srcImmutablesData, (IBaseEscrow.Immutables));
        
        uint256 srcDeployTime = vm.parseJsonUint(stateJson, ".srcDeployTime");
        
        // Update timelocks with deployment timestamp
        Timelocks timelocks = immutables.timelocks.setDeployedAt(srcDeployTime);
        
        console.log("Source Escrow Timelock Analysis");
        console.log("===============================");
        console.log("Deployment time:", srcDeployTime);
        console.log("Current time:", block.timestamp);
        console.log("Time elapsed:", block.timestamp - srcDeployTime, "seconds");
        console.log("");
        
        // Get individual timelock stages
        uint256 srcWithdrawal = timelocks.get(TimelocksLib.Stage.SrcWithdrawal);
        uint256 srcPublicWithdrawal = timelocks.get(TimelocksLib.Stage.SrcPublicWithdrawal);
        uint256 srcCancellation = timelocks.get(TimelocksLib.Stage.SrcCancellation);
        uint256 srcPublicCancellation = timelocks.get(TimelocksLib.Stage.SrcPublicCancellation);
        
        console.log("Timelock stages (absolute timestamps):");
        console.log("  SrcWithdrawal:", srcWithdrawal);
        console.log("  SrcPublicWithdrawal:", srcPublicWithdrawal);
        console.log("  SrcCancellation:", srcCancellation);
        console.log("  SrcPublicCancellation:", srcPublicCancellation);
        console.log("");
        
        console.log("Time until/since each stage:");
        console.log("  SrcWithdrawal:", srcWithdrawal > block.timestamp ? "in" : "passed", 
                    srcWithdrawal > block.timestamp ? srcWithdrawal - block.timestamp : block.timestamp - srcWithdrawal, "seconds");
        console.log("  SrcPublicWithdrawal:", srcPublicWithdrawal > block.timestamp ? "in" : "passed",
                    srcPublicWithdrawal > block.timestamp ? srcPublicWithdrawal - block.timestamp : block.timestamp - srcPublicWithdrawal, "seconds");
        console.log("  SrcCancellation:", srcCancellation > block.timestamp ? "in" : "passed",
                    srcCancellation > block.timestamp ? srcCancellation - block.timestamp : block.timestamp - srcCancellation, "seconds");
        console.log("  SrcPublicCancellation:", srcPublicCancellation > block.timestamp ? "in" : "passed",
                    srcPublicCancellation > block.timestamp ? srcPublicCancellation - block.timestamp : block.timestamp - srcPublicCancellation, "seconds");
        console.log("");
        
        // Check current valid action
        if (block.timestamp >= srcWithdrawal && block.timestamp < srcCancellation) {
            console.log("[OK] Currently in WITHDRAWAL period");
            if (block.timestamp >= srcPublicWithdrawal) {
                console.log("    - Public withdrawal is allowed");
            } else {
                console.log("    - Only taker can withdraw");
            }
        } else if (block.timestamp >= srcCancellation) {
            console.log("[WARNING] Currently in CANCELLATION period");
            if (block.timestamp >= srcPublicCancellation) {
                console.log("    - Public cancellation is allowed");
            } else {
                console.log("    - Only maker can cancel");
            }
        } else {
            console.log("[ERROR] Withdrawal period has not started yet!");
        }
    }
}