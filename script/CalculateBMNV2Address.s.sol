// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { Script, console } from "forge-std/Script.sol";
import { BMNAccessTokenV2 } from "../contracts/BMNAccessTokenV2.sol";
import { Create2 } from "@openzeppelin/contracts/utils/Create2.sol";

contract CalculateBMNV2Address is Script {
    bytes32 constant SALT = keccak256("BMN_ACCESS_TOKEN_V2");
    
    function run() external view {
        address deployer = 0x5f29827e25dc174a6A51C99e6811Bbd7581285b0; // Our deployer
        
        // Calculate address with constructor parameter
        bytes memory bytecode = abi.encodePacked(
            type(BMNAccessTokenV2).creationCode,
            abi.encode(deployer)
        );
        
        address expectedAddress = Create2.computeAddress(
            SALT,
            keccak256(bytecode),
            CREATE2_FACTORY
        );
        
        console.log("=== BMN TOKEN V2 ADDRESS CALCULATION ===");
        console.log("Deployer:", deployer);
        console.log("CREATE2 Factory:", CREATE2_FACTORY);
        console.log("Salt:", uint256(SALT));
        console.log("Expected Address:", expectedAddress);
        console.log("======================================");
    }
}