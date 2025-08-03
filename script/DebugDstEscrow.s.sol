// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IBaseEscrow} from "../contracts/interfaces/IBaseEscrow.sol";
import {TimelocksLib, Timelocks} from "../contracts/libraries/TimelocksLib.sol";

contract DebugDstEscrow is Script {
    using TimelocksLib for Timelocks;
    
    address constant DST_ESCROW = 0x7961656805D07570ef590d27163036E54d387dDa;
    address constant BMN_TOKEN = 0x8287CD2aC7E227D9D927F998EB600a0683a832A1;
    
    function run() external view {
        console.log("=== Debugging Destination Escrow ===");
        console.log("Escrow address:", DST_ESCROW);
        
        // Check if escrow has code
        uint256 codeSize;
        assembly {
            codeSize := extcodesize(DST_ESCROW)
        }
        console.log("Code size:", codeSize);
        
        if (codeSize == 0) {
            console.log("[ERROR] No code at escrow address!");
            return;
        }
        
        // Check BMN balance
        uint256 bmnBalance = IERC20(BMN_TOKEN).balanceOf(DST_ESCROW);
        console.log("BMN balance:", bmnBalance / 1e18, "BMN");
        
        // Check ETH balance (safety deposit)
        uint256 ethBalance = DST_ESCROW.balance;
        console.log("ETH balance:", ethBalance, "wei");
        
        // Load state to check immutables
        string memory stateJson = vm.readFile("deployments/mainnet-test-state.json");
        bytes memory dstImmutablesData = vm.parseJsonBytes(stateJson, ".dstImmutables");
        IBaseEscrow.Immutables memory dstImmutables = abi.decode(dstImmutablesData, (IBaseEscrow.Immutables));
        
        uint256 deployedTimelocks = vm.parseJsonUint(stateJson, ".deployedTimelocks");
        uint256 dstDeployTime = vm.parseJsonUint(stateJson, ".dstDeployTime");
        
        console.log("\n=== Immutables ===");
        console.log("Hashlock:", vm.toString(dstImmutables.hashlock));
        console.log("Amount:", dstImmutables.amount / 1e18, "BMN");
        console.log("Safety deposit:", dstImmutables.safetyDeposit, "wei");
        
        console.log("\n=== Timelocks ===");
        console.log("Deploy time:", dstDeployTime);
        console.log("Current time:", block.timestamp);
        console.log("Elapsed:", block.timestamp - dstDeployTime, "seconds");
        
        Timelocks timelocks = Timelocks.wrap(deployedTimelocks);
        uint256 dstWithdrawal = timelocks.get(TimelocksLib.Stage.DstWithdrawal);
        uint256 dstCancellation = timelocks.get(TimelocksLib.Stage.DstCancellation);
        
        console.log("Dst withdrawal:", dstWithdrawal);
        console.log("Dst cancellation:", dstCancellation);
        
        if (block.timestamp >= dstWithdrawal && block.timestamp < dstCancellation) {
            console.log("[OK] Currently in withdrawal window");
        } else if (block.timestamp >= dstCancellation) {
            console.log("[WARNING] In cancellation period");
        } else {
            console.log("[ERROR] Not yet in withdrawal window");
        }
    }
}