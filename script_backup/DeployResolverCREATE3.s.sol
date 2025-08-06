// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import { Create3Factory } from "../contracts/Create3Factory.sol";

// CREATE3 Factory interface
interface ICREATE3 {
    function deploy(bytes32 salt, bytes calldata bytecode) external payable returns (address);
    function getDeployed(address deployer, bytes32 salt) external view returns (address);
}

/**
 * @title DeployResolverCREATE3
 * @notice Deploy resolver infrastructure using CREATE3
 * @dev Bob (resolver) deploys his own CREATE3 factory for managing resolver contracts
 */
contract DeployResolverCREATE3 is Script {
    // CREATE3 factory deployed on both Base and Etherlink
    address constant CREATE3_FACTORY = 0x7B9e9BE124C5A0E239E04fDC93b66ead4e8C669d;
    
    // Salt for resolver's CREATE3 factory
    bytes32 constant RESOLVER_FACTORY_SALT = keccak256("BMN-Resolver-Factory-v1.0.0");
    
    // Deployment result
    address public resolverFactory;
    
    function run() external {
        // Load Bob's private key (resolver)
        uint256 bobPrivateKey = vm.envUint("RESOLVER_PRIVATE_KEY");
        address bob = vm.addr(bobPrivateKey);
        
        console.log("Deploying Resolver Infrastructure with CREATE3");
        console.log("=============================================");
        console.log("Resolver (Bob):", bob);
        console.log("Chain ID:", block.chainid);
        console.log("CREATE3 Factory:", CREATE3_FACTORY);
        
        // Predict resolver factory address
        resolverFactory = ICREATE3(CREATE3_FACTORY).getDeployed(bob, RESOLVER_FACTORY_SALT);
        
        console.log("\nPredicted resolver factory address:", resolverFactory);
        
        vm.startBroadcast(bobPrivateKey);
        
        // Deploy resolver's own CREATE3 factory for managing resolver contracts
        if (resolverFactory.code.length == 0) {
            console.log("\nDeploying Resolver's CREATE3 Factory...");
            bytes memory factoryBytecode = abi.encodePacked(
                type(Create3Factory).creationCode,
                abi.encode(bob) // Bob is the owner
            );
            
            address deployedFactory = ICREATE3(CREATE3_FACTORY).deploy(RESOLVER_FACTORY_SALT, factoryBytecode);
            require(deployedFactory == resolverFactory, "Resolver factory address mismatch");
            console.log("Resolver's CREATE3 Factory deployed at:", deployedFactory);
        } else {
            console.log("Resolver's CREATE3 Factory already deployed at:", resolverFactory);
        }
        
        vm.stopBroadcast();
        
        // Save deployment info
        string memory deploymentInfo = string(abi.encodePacked(
            "# Resolver CREATE3 Deployment\n",
            "CHAIN_ID=", vm.toString(block.chainid), "\n",
            "CREATE3_FACTORY=", vm.toString(CREATE3_FACTORY), "\n",
            "RESOLVER_FACTORY=", vm.toString(resolverFactory), "\n",
            "RESOLVER=", vm.toString(bob), "\n"
        ));
        
        string memory filename = string(abi.encodePacked(
            "deployments/resolver-create3-",
            vm.toString(block.chainid),
            ".env"
        ));
        
        vm.writeFile(filename, deploymentInfo);
        console.log("\nDeployment info saved to:", filename);
        console.log("\n=== Resolver Deployment Complete ===");
    }
}