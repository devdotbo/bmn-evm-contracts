// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { EscrowSrc } from "../contracts/EscrowSrc.sol";
import { EscrowDst } from "../contracts/EscrowDst.sol";
import { TestEscrowFactory } from "../contracts/TestEscrowFactory.sol";
import { Constants } from "../contracts/Constants.sol";

/**
 * @title DeployQuickFix
 * @notice Quick deployment for hackathon - uses regular deployment (not CREATE2)
 * @dev Deploy this on both chains, then manually update factory with implementation addresses
 */
contract DeployQuickFix is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);
        
        console.log("Quick deployment from:", deployer);
        console.log("Chain ID:", block.chainid);
        
        vm.startBroadcast(deployerKey);
        
        // Deploy implementations
        EscrowSrc srcImpl = new EscrowSrc();
        EscrowDst dstImpl = new EscrowDst();
        
        console.log("SRC Implementation:", address(srcImpl));
        console.log("DST Implementation:", address(dstImpl));
        
        // Deploy factory
        TestEscrowFactory factory = new TestEscrowFactory(
            address(srcImpl),
            address(dstImpl),
            Constants.BMN_TOKEN,
            0.00001 ether // safety deposit
        );
        
        console.log("Factory deployed at:", address(factory));
        
        vm.stopBroadcast();
        
        // Instructions for manual fix
        console.log("\n=== IMPORTANT: Manual Steps Required ===");
        console.log("1. Deploy this script on BOTH chains");
        console.log("2. Note down the implementation addresses from each chain");
        console.log("3. Update TestEscrowFactory to handle different addresses per chain");
        console.log("\nFor Base (8453):");
        console.log("   DST Implementation:", address(dstImpl));
        console.log("\nFor Etherlink (42793):");
        console.log("   DST Implementation:", address(dstImpl));
        console.log("\n4. Redeploy factory with hardcoded chain-specific addresses");
    }
}