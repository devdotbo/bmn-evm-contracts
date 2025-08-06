// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Script.sol";
import "../contracts/SimpleAtomicSwap.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract SimpleAtomicTest is Script {
    address constant BMN_TOKEN = 0x8287CD2aC7E227D9D927F998EB600a0683a832A1;
    uint256 constant SWAP_AMOUNT = 100 * 10**18;
    
    function run() external {
        // Test secret
        bytes32 secret = keccak256("test_secret");
        bytes32 hashlock = keccak256(abi.encodePacked(secret));
        
        console.log("Deploying SimpleAtomicSwap on Base and Optimism...");
        
        // Deploy on Base
        vm.createSelectFork(vm.envString("BASE_RPC_URL"));
        vm.startBroadcast(vm.envUint("DEPLOYER_PRIVATE_KEY"));
        SimpleAtomicSwap baseSwap = new SimpleAtomicSwap();
        console.log("Base contract:", address(baseSwap));
        vm.stopBroadcast();
        
        // Deploy on Optimism  
        vm.createSelectFork(vm.envString("OPTIMISM_RPC_URL"));
        vm.startBroadcast(vm.envUint("DEPLOYER_PRIVATE_KEY"));
        SimpleAtomicSwap optSwap = new SimpleAtomicSwap();
        console.log("Optimism contract:", address(optSwap));
        vm.stopBroadcast();
        
        console.log("\n[SUCCESS] Deployed SimpleAtomicSwap on both chains!");
        console.log("Next steps:");
        console.log("1. Fund accounts with BMN tokens");
        console.log("2. Create swaps with hashlock:", vm.toString(hashlock));
        console.log("3. Withdraw with secret:", vm.toString(secret));
    }
}