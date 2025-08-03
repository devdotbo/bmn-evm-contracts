// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { Script, console } from "forge-std/Script.sol";
import { Create3Factory } from "../contracts/Create3Factory.sol";
import { Create2 } from "@openzeppelin/contracts/utils/Create2.sol";

/**
 * @title DeployCreate3Factory
 * @notice Deployment script for CREATE3 factory using CREATE2 for deterministic address
 * @dev Deploys factory at same address on all chains
 */
contract DeployCreate3Factory is Script {
    // Salt for deterministic factory deployment
    bytes32 constant FACTORY_SALT = keccak256("BMN_CREATE3_FACTORY_V1");
    
    // Known CREATE2 factory on most chains
    address constant CANONICAL_CANONICAL_CREATE2_FACTORY = 0x4e59b44847b379578588920cA78FbF26c0B4956C;
    
    function run() external {
        uint256 deployerKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);
        
        // Calculate expected factory address
        bytes memory initCode = abi.encodePacked(
            type(Create3Factory).creationCode,
            abi.encode(deployer) // Constructor parameter
        );
        
        address expectedFactory = Create2.computeAddress(
            FACTORY_SALT,
            keccak256(initCode),
            CANONICAL_CREATE2_FACTORY
        );
        
        console.log("=== CREATE3 FACTORY DEPLOYMENT ===");
        console.log("Deployer:", deployer);
        console.log("CREATE2 Factory:", CANONICAL_CREATE2_FACTORY);
        console.log("Salt:", vm.toString(abi.encodePacked(FACTORY_SALT)));
        console.log("Expected Factory Address:", expectedFactory);
        console.log("");
        
        // Deploy on Base mainnet
        deployOnChain(
            "Base Mainnet",
            vm.envString("BASE_RPC_URL"),
            8453,
            deployerKey,
            deployer,
            expectedFactory,
            initCode
        );
        
        // Deploy on Etherlink mainnet
        deployOnChain(
            "Etherlink Mainnet", 
            vm.envString("ETHERLINK_RPC_URL"),
            42793,
            deployerKey,
            deployer,
            expectedFactory,
            initCode
        );
        
        // Save deployment info
        saveDeploymentInfo(deployer, expectedFactory);
    }
    
    function deployOnChain(
        string memory chainName,
        string memory rpcUrl,
        uint256 chainId,
        uint256 deployerKey,
        address deployer,
        address expectedFactory,
        bytes memory initCode
    ) internal {
        console.log(string(abi.encodePacked("\n--- Deploying on ", chainName, " ---")));
        console.log("RPC URL:", rpcUrl);
        console.log("Chain ID:", chainId);
        
        vm.createSelectFork(rpcUrl);
        require(block.chainid == chainId, "Chain ID mismatch");
        
        // Check if factory already deployed
        uint256 codeSize;
        assembly {
            codeSize := extcodesize(expectedFactory)
        }
        
        vm.startBroadcast(deployerKey);
        
        if (codeSize > 0) {
            console.log("Factory already deployed at:", expectedFactory);
            Create3Factory factory = Create3Factory(expectedFactory);
            console.log("Owner:", factory.owner());
            console.log("Deployer authorized:", factory.authorized(deployer));
        } else {
            console.log("Deploying CREATE3 Factory...");
            
            // Deploy using CREATE2 factory
            (bool success,) = CANONICAL_CREATE2_FACTORY.call(
                abi.encodePacked(FACTORY_SALT, initCode)
            );
            require(success, "CREATE2 deployment failed");
            
            // Verify deployment
            uint256 deployedCodeSize;
            assembly {
                deployedCodeSize := extcodesize(expectedFactory)
            }
            require(deployedCodeSize > 0, "Factory not deployed at expected address");
            
            console.log("Factory deployed at:", expectedFactory);
            
            Create3Factory factory = Create3Factory(expectedFactory);
            console.log("Owner:", factory.owner());
            console.log("Deployer authorized:", factory.authorized(deployer));
            
            // Authorize additional deployers if needed
            address alice = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
            factory.authorize(alice);
            console.log("Authorized Alice:", alice);
            
            console.log("\nDeployment complete!");
        }
        
        vm.stopBroadcast();
    }
    
    function saveDeploymentInfo(address deployer, address factoryAddress) internal {
        string memory timestamp = vm.toString(block.timestamp);
        string memory deploymentJson = string(abi.encodePacked(
            '{\n',
            '  "deploymentTime": "', timestamp, '",\n',
            '  "deployer": "', vm.toString(deployer), '",\n',
            '  "create2Factory": "', vm.toString(CANONICAL_CREATE2_FACTORY), '",\n',
            '  "salt": "', vm.toString(abi.encodePacked(FACTORY_SALT)), '",\n',
            '  "create3FactoryAddress": "', vm.toString(factoryAddress), '",\n',
            '  "chains": {\n',
            '    "base_mainnet": {\n',
            '      "chainId": 8453,\n',
            '      "address": "', vm.toString(factoryAddress), '"\n',
            '    },\n',
            '    "etherlink_mainnet": {\n',
            '      "chainId": 42793,\n',
            '      "address": "', vm.toString(factoryAddress), '"\n',
            '    }\n',
            '  }\n',
            '}\n'
        ));
        
        // Create timestamp for filename
        string memory dateStr = "2025-01-08";
        vm.writeFile(
            string(abi.encodePacked("deployments/create3-factory-", dateStr, ".json")), 
            deploymentJson
        );
        console.log("\nDeployment info saved to deployments/create3-factory-", dateStr, ".json");
    }
}