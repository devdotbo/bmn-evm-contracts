// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { Script, console } from "forge-std/Script.sol";
import { BMNAccessToken } from "../contracts/BMNAccessToken.sol";
import { Create2 } from "@openzeppelin/contracts/utils/Create2.sol";

contract DeployBMNToken is Script {
    // Fixed salt for deterministic deployment
    bytes32 constant SALT = keccak256("BMN_ACCESS_TOKEN_V1");
    
    function run() external {
        uint256 deployerKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);
        
        // Forge uses a deterministic CREATE2 factory at 0x4e59b44847b379578588920cA78FbF26c0B4956C
        address create2Factory = 0x4e59b44847b379578588920cA78FbF26c0B4956C;
        
        // Calculate expected address using Forge's CREATE2 factory
        bytes memory bytecode = type(BMNAccessToken).creationCode;
        address expectedAddress = Create2.computeAddress(SALT, keccak256(bytecode), create2Factory);
        
        console.log("=== BMN ACCESS TOKEN DEPLOYMENT ===");
        console.log("Deployer:", deployer);
        console.log("CREATE2 Factory:", create2Factory);
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
            BMNAccessToken token = BMNAccessToken(expectedAddress);
            console.log("Name:", token.name());
            console.log("Symbol:", token.symbol());
            console.log("Owner:", token.owner());
        } else {
            // Deploy with CREATE2
            BMNAccessToken token = new BMNAccessToken{salt: SALT}();
            console.log("Token deployed at:", address(token));
            
            console.log("Deployment successful!");
            console.log("Name:", token.name());
            console.log("Symbol:", token.symbol());
            console.log("Decimals:", token.decimals());
            console.log("Owner:", token.owner());
            
            // Note: Ownership stays with CREATE2 factory
            console.log("Note: Token ownership remains with CREATE2 factory");
        }
        
        vm.stopBroadcast();
    }
    
    // Helper function to get the address without deploying
    function getAddress() external view returns (address) {
        bytes memory bytecode = type(BMNAccessToken).creationCode;
        return Create2.computeAddress(SALT, keccak256(bytecode), msg.sender);
    }
}