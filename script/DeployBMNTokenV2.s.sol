// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { Script, console } from "forge-std/Script.sol";
import { BMNAccessTokenV2 } from "../contracts/BMNAccessTokenV2.sol";
import { Create2 } from "@openzeppelin/contracts/utils/Create2.sol";

contract DeployBMNTokenV2 is Script {
    // Fixed salt for deterministic deployment
    bytes32 constant SALT = keccak256("BMN_ACCESS_TOKEN_V2");
    
    function run() external {
        uint256 deployerKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);
        
        // Calculate expected address
        bytes memory bytecode = abi.encodePacked(
            type(BMNAccessTokenV2).creationCode,
            abi.encode(deployer) // Constructor parameter
        );
        address expectedAddress = Create2.computeAddress(SALT, keccak256(bytecode), CREATE2_FACTORY);
        
        console.log("=== BMN ACCESS TOKEN V2 DEPLOYMENT ===");
        console.log("Deployer:", deployer);
        console.log("Salt:", uint256(SALT));
        console.log("Expected address:", expectedAddress);
        
        vm.startBroadcast(deployerKey);
        
        // Check if already deployed
        uint256 codeSize;
        assembly {
            codeSize := extcodesize(expectedAddress)
        }
        
        if (codeSize > 0) {
            console.log("Token already deployed at:", expectedAddress);
            BMNAccessTokenV2 token = BMNAccessTokenV2(expectedAddress);
            console.log("Name:", token.name());
            console.log("Symbol:", token.symbol());
            console.log("Owner:", token.owner());
        } else {
            // Deploy with CREATE2
            BMNAccessTokenV2 token = new BMNAccessTokenV2{salt: SALT}(deployer);
            console.log("Token deployed at:", address(token));
            
            console.log("Deployment successful!");
            console.log("Name:", token.name());
            console.log("Symbol:", token.symbol());
            console.log("Decimals:", token.decimals());
            console.log("Owner:", token.owner());
            
            require(token.owner() == deployer, "Owner not set correctly");
            console.log("Ownership verified!");
        }
        
        vm.stopBroadcast();
    }
}