// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {stdJson} from "forge-std/StdJson.sol";

contract CleanStateFile is Script {
    using stdJson for string;

    function run() external {
        string memory stateFile = "deployments/mainnet-test-state.json";
        string memory backupFile = "deployments/mainnet-test-state.backup.json";
        
        // Read the corrupted state file
        string memory corruptedJson = vm.readFile(stateFile);
        
        // Create backup before cleaning
        vm.writeFile(backupFile, corruptedJson);
        console2.log("Backup created at:", backupFile);
        
        // Extract values from nested structure
        bytes32 secret = extractSecret(corruptedJson);
        bytes32 hashlock = extractHashlock(corruptedJson);
        address srcEscrow = extractSrcEscrow(corruptedJson);
        uint256 srcDeployTime = extractSrcDeployTime(corruptedJson);
        bytes memory srcImmutables = extractSrcImmutables(corruptedJson);
        address dstEscrow = extractDstEscrow(corruptedJson);
        uint256 dstDeployTime = extractDstDeployTime(corruptedJson);
        bytes memory dstImmutables = extractDstImmutables(corruptedJson);
        uint256 deployedTimelocks = extractDeployedTimelocks(corruptedJson);
        
        // Create clean JSON structure
        string memory cleanJson = "root";
        cleanJson.serialize("secret", secret);
        cleanJson.serialize("hashlock", hashlock);
        cleanJson.serialize("srcEscrow", srcEscrow);
        cleanJson.serialize("srcDeployTime", srcDeployTime);
        cleanJson.serialize("srcImmutables", srcImmutables);
        cleanJson.serialize("dstEscrow", dstEscrow);
        cleanJson.serialize("dstDeployTime", dstDeployTime);
        cleanJson.serialize("dstImmutables", dstImmutables);
        string memory finalJson = cleanJson.serialize("deployedTimelocks", deployedTimelocks);
        
        // Write cleaned state back to file
        vm.writeFile(stateFile, finalJson);
        
        // Validate the cleaned state
        validateState(stateFile);
        
        console2.log("State file cleaned successfully!");
        console2.log("Original file backed up to:", backupFile);
    }
    
    function extractSecret(string memory json) internal pure returns (bytes32) {
        // Navigate through: .existing.existing.existing.secret
        return bytes32(json.readBytes32(".existing.existing.existing.secret"));
    }
    
    function extractHashlock(string memory json) internal pure returns (bytes32) {
        // Navigate through: .existing.existing.existing.hashlock
        return bytes32(json.readBytes32(".existing.existing.existing.hashlock"));
    }
    
    function extractSrcEscrow(string memory json) internal pure returns (address) {
        // Navigate through: .existing.existing.srcEscrow
        return json.readAddress(".existing.existing.srcEscrow");
    }
    
    function extractSrcDeployTime(string memory json) internal pure returns (uint256) {
        // Navigate through: .existing.existing.srcDeployTime
        return json.readUint(".existing.existing.srcDeployTime");
    }
    
    function extractSrcImmutables(string memory json) internal pure returns (bytes memory) {
        // Navigate through: .existing.existing.srcImmutables
        return json.readBytes(".existing.existing.srcImmutables");
    }
    
    function extractDstEscrow(string memory json) internal pure returns (address) {
        // Get the top-level dstEscrow (the most recent one)
        return json.readAddress(".dstEscrow");
    }
    
    function extractDstDeployTime(string memory json) internal pure returns (uint256) {
        // Get the top-level dstDeployTime (the most recent one)
        return json.readUint(".dstDeployTime");
    }
    
    function extractDstImmutables(string memory json) internal pure returns (bytes memory) {
        // Navigate through: .existing.existing.dstImmutables
        return json.readBytes(".existing.existing.dstImmutables");
    }
    
    function extractDeployedTimelocks(string memory json) internal pure returns (uint256) {
        // Get the top-level deployedTimelocks (the most recent one)
        return json.readUint(".deployedTimelocks");
    }
    
    function validateState(string memory stateFile) internal view {
        string memory cleanedJson = vm.readFile(stateFile);
        
        // Validate all required fields are present
        require(cleanedJson.readBytes32(".secret") != bytes32(0), "Missing secret");
        require(cleanedJson.readBytes32(".hashlock") != bytes32(0), "Missing hashlock");
        require(cleanedJson.readAddress(".srcEscrow") != address(0), "Missing srcEscrow");
        require(cleanedJson.readUint(".srcDeployTime") != 0, "Missing srcDeployTime");
        require(cleanedJson.readBytes(".srcImmutables").length > 0, "Missing srcImmutables");
        require(cleanedJson.readAddress(".dstEscrow") != address(0), "Missing dstEscrow");
        require(cleanedJson.readUint(".dstDeployTime") != 0, "Missing dstDeployTime");
        require(cleanedJson.readBytes(".dstImmutables").length > 0, "Missing dstImmutables");
        require(cleanedJson.readUint(".deployedTimelocks") != 0, "Missing deployedTimelocks");
        
        // Log the cleaned state for verification
        console2.log("Cleaned state validated successfully!");
        console2.log("Secret:", vm.toString(cleanedJson.readBytes32(".secret")));
        console2.log("Hashlock:", vm.toString(cleanedJson.readBytes32(".hashlock")));
        console2.log("Src Escrow:", cleanedJson.readAddress(".srcEscrow"));
        console2.log("Dst Escrow:", cleanedJson.readAddress(".dstEscrow"));
        console2.log("Src Deploy Time:", cleanedJson.readUint(".srcDeployTime"));
        console2.log("Dst Deploy Time:", cleanedJson.readUint(".dstDeployTime"));
    }
}