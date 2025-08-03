// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {IBaseEscrow} from "../contracts/interfaces/IBaseEscrow.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {TimelocksLib, Timelocks} from "../contracts/libraries/TimelocksLib.sol";
// BMN token address on Etherlink
address constant BMN_TOKEN = 0x8287CD2aC7E227D9D927F998EB600a0683a832A1;

contract FixMainnetWithdraw is Script {
    using TimelocksLib for Timelocks;
    
    function run() external {
        // The actual deployed escrow address from event
        address dstEscrow = 0xfDa2D0E5aa2441D1Fc02Bc3BF423da37F5ca42D9;
        
        // Load the secret from state file
        string memory stateJson = vm.readFile("deployments/mainnet-test-state.json");
        bytes32 secret = vm.parseJsonBytes32(stateJson, ".existing.existing.secret");
        
        // Parse the original immutables
        bytes memory dstImmutablesData = vm.parseJsonBytes(stateJson, ".existing.dstImmutables");
        IBaseEscrow.Immutables memory dstImmutables = abi.decode(dstImmutablesData, (IBaseEscrow.Immutables));
        
        // The actual deployment timestamp from our debug script
        uint256 actualDeployTime = 1754229116;
        dstImmutables.timelocks = dstImmutables.timelocks.setDeployedAt(actualDeployTime);
        
        console.log("Attempting withdrawal from:", dstEscrow);
        console.log("Secret:", uint256(secret));
        console.log("Deployment time:", actualDeployTime);
        
        // Get Alice's private key
        uint256 aliceKey = vm.envUint("ALICE_PRIVATE_KEY");
        address alice = vm.addr(aliceKey);
        
        vm.startBroadcast(aliceKey);
        
        // Check balance before
        uint256 balanceBefore = IERC20(BMN_TOKEN).balanceOf(alice);
        console.log("Alice BMN balance before:", balanceBefore / 1e18);
        
        // Withdraw from destination escrow
        IBaseEscrow(dstEscrow).withdraw(secret, dstImmutables);
        
        // Check balance after
        uint256 balanceAfter = IERC20(BMN_TOKEN).balanceOf(alice);
        console.log("Alice BMN balance after:", balanceAfter / 1e18);
        console.log("Alice received:", (balanceAfter - balanceBefore) / 1e18, "BMN");
        
        vm.stopBroadcast();
        
        // Update state file with correct info for next steps
        string memory json = "state";
        string memory newState = vm.readFile("deployments/mainnet-test-state.json");
        vm.serializeString(json, "existing", newState);
        vm.serializeAddress(json, "dstEscrow", dstEscrow);
        vm.serializeUint(json, "deployedTimelocks", Timelocks.unwrap(dstImmutables.timelocks));
        string memory updatedJson = vm.serializeUint(json, "dstDeployTime", actualDeployTime);
        vm.writeJson(updatedJson, "deployments/mainnet-test-state.json");
    }
}