// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {IBaseEscrow} from "../contracts/interfaces/IBaseEscrow.sol";
import {TimelocksLib, Timelocks} from "../contracts/libraries/TimelocksLib.sol";
import {ImmutablesLib} from "../contracts/libraries/ImmutablesLib.sol";
import {AddressLib} from "@1inch/solidity-utils/contracts/libraries/AddressLib.sol";

contract DebugMainnetAddress is Script {
    using TimelocksLib for Timelocks;
    using ImmutablesLib for IBaseEscrow.Immutables;
    
    uint256 constant SWAP_AMOUNT = 10 ether;
    uint256 constant SAFETY_DEPOSIT = 0.00001 ether;
    
    function run() external {
        // Load the state file
        string memory stateJson = vm.readFile("deployments/mainnet-test-state.json");
        
        // Parse the destination immutables
        bytes memory dstImmutablesData = vm.parseJsonBytes(stateJson, ".existing.dstImmutables");
        IBaseEscrow.Immutables memory dstImmutables = abi.decode(dstImmutablesData, (IBaseEscrow.Immutables));
        
        // Parse deployment time
        uint256 deployTime = vm.parseJsonUint(stateJson, ".dstDeployTime");
        
        // Don't update timelocks here - the factory does it internally
        
        // Factory address on Etherlink
        address factory = 0x6b3E1410513DcC0874E367CbD79Ee3448D6478C9;
        address dstImpl = 0x3CEEE89102B0F4c6181d939003C587647692Ba60;
        
        console.log("Debug Info:");
        console.log("Factory:", factory);
        console.log("Dst Implementation:", dstImpl);
        console.log("Deploy time:", deployTime);
        
        // Print immutables
        console.log("\nImmutables:");
        console.log("  orderHash:", uint256(dstImmutables.orderHash));
        console.log("  hashlock:", uint256(dstImmutables.hashlock));
        console.log("  maker:", AddressLib.get(dstImmutables.maker));
        console.log("  taker:", AddressLib.get(dstImmutables.taker));
        console.log("  token:", AddressLib.get(dstImmutables.token));
        console.log("  amount:", dstImmutables.amount);
        console.log("  safetyDeposit:", dstImmutables.safetyDeposit);
        console.log("  timelocks:", Timelocks.unwrap(dstImmutables.timelocks));
        
        // Calculate the salt
        bytes32 salt = dstImmutables.hashMem();
        console.log("\nSalt:", uint256(salt));
        
        // Calculate expected address
        address expected = Clones.predictDeterministicAddress(dstImpl, salt, factory);
        console.log("\nExpected address:", expected);
        console.log("Actual address from event:", 0xfDa2D0E5aa2441D1Fc02Bc3BF423da37F5ca42D9);
        
        // Let's try to figure out what deployment timestamp was actually used
        // The factory sets the deployment timestamp when createDstEscrow is called
        // We need to find the actual block timestamp when the transaction was executed
        
        console.log("\nTrying to find the correct deployment timestamp...");
        
        // The actual deployed address is 0xfDa2D0E5aa2441D1Fc02Bc3BF423da37F5ca42D9
        // Let's try different timestamps around the expected deployment time
        
        // Start with the deployment time from state file
        uint256 testTime = deployTime;
        
        // Try a range of timestamps (±300 seconds to account for delays)
        for (uint256 i = 0; i < 600; i++) {
            uint256 tryTime = testTime - 300 + i;
            IBaseEscrow.Immutables memory testImmutables = dstImmutables;
            testImmutables.timelocks = testImmutables.timelocks.setDeployedAt(tryTime);
            bytes32 testSalt = testImmutables.hashMem();
            address testAddress = Clones.predictDeterministicAddress(dstImpl, testSalt, factory);
            
            if (testAddress == 0xfDa2D0E5aa2441D1Fc02Bc3BF423da37F5ca42D9) {
                console.log("\nFOUND IT!");
                console.log("Correct deployment timestamp:", tryTime);
                console.log("Difference from expected:", int256(tryTime) - int256(deployTime));
                
                // Update and verify immutables with correct timestamp
                testImmutables.timelocks = testImmutables.timelocks.setDeployedAt(tryTime);
                console.log("\nCorrected timelocks:", Timelocks.unwrap(testImmutables.timelocks));
                
                break;
            }
        }
    }
}