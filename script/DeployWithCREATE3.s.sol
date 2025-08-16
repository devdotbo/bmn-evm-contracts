// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import { SimplifiedEscrowFactoryV3_0_3 } from "../contracts/SimplifiedEscrowFactoryV3_0_3.sol";
import { Constants } from "../contracts/Constants.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

// CREATE3 Factory interface - selector 0xcdcb760a for deploy, 0x50f1c464 for getDeployed
interface ICREATE3 {
    function deploy(bytes32 salt, bytes calldata bytecode) external payable returns (address);
    function getDeployed(address deployer, bytes32 salt) external view returns (address);
}

/**
 * @title DeployWithCREATE3
 * @notice Deploy BMN protocol v3.0.3 factory using CREATE3 for cross-chain consistency
 * @dev Uses verified CREATE3 factory at 0x7B9e9BE124C5A0E239E04fDC93b66ead4e8C669d
 *      v3.0.3 fixes resolver compatibility by using predictable timelocks
 */
contract DeployWithCREATE3 is Script {
    // CREATE3 factory deployed on both Base and Etherlink
    address constant CREATE3_FACTORY = 0x7B9e9BE124C5A0E239E04fDC93b66ead4e8C669d;
    
    // Deterministic salt for v3.0.3 factory
    bytes32 constant FACTORY_SALT = keccak256("BMN-SimplifiedEscrowFactory-v3.0.3");
    
    // Deployment result
    address public factory;
    
    function run() external {
        // Load deployer from environment
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("Deploying BMN Protocol v3.0.3 with CREATE3");
        console.log("============================================");
        console.log("Deployer:", deployer);
        console.log("Chain ID:", block.chainid);
        console.log("CREATE3 Factory:", CREATE3_FACTORY);
        
        // Predict factory address
        factory = ICREATE3(CREATE3_FACTORY).getDeployed(deployer, FACTORY_SALT);
        
        console.log("\nPredicted factory address:");
        console.log("SimplifiedEscrowFactoryV3_0_3:", factory);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy factory (which will deploy its own implementations)
        if (factory.code.length == 0) {
            console.log("\nDeploying SimplifiedEscrowFactoryV3_0_3...");
            console.log("Note: Factory fixes resolver compatibility with predictable timelocks");
            
            bytes memory factoryBytecode = abi.encodePacked(
                type(SimplifiedEscrowFactoryV3_0_3).creationCode,
                abi.encode(
                    IERC20(Constants.BMN_TOKEN),  // accessToken
                    deployer,                      // owner
                    604800                         // 7 days rescue delay
                )
            );
            
            address deployedFactory = ICREATE3(CREATE3_FACTORY).deploy(FACTORY_SALT, factoryBytecode);
            require(deployedFactory == factory, "Factory address mismatch");
            console.log("SimplifiedEscrowFactoryV3_0_3 deployed at:", deployedFactory);
            console.log("Factory has deployed its own EscrowSrc and EscrowDst implementations");
        } else {
            console.log("SimplifiedEscrowFactoryV3_0_3 already deployed at:", factory);
        }
        
        vm.stopBroadcast();
        
        // Save deployment info
        string memory deploymentInfo = string(abi.encodePacked(
            "# BMN Protocol v3.0.3 CREATE3 Deployment\n",
            "# Factory fixes resolver compatibility with predictable timelocks\n",
            "CHAIN_ID=", vm.toString(block.chainid), "\n",
            "CREATE3_FACTORY=", vm.toString(CREATE3_FACTORY), "\n",
            "FACTORY=", vm.toString(factory), "\n",
            "DEPLOYER=", vm.toString(deployer), "\n",
            "# Note: Implementation addresses are chain-specific and deployed by the factory\n"
        ));
        
        string memory filename = string(abi.encodePacked(
            "deployments/create3-v3.0.3-",
            vm.toString(block.chainid),
            ".env"
        ));
        
        vm.writeFile(filename, deploymentInfo);
        console.log("\nDeployment info saved to:", filename);
        console.log("\n=== Deployment Complete ===");
        console.log("Factory v3.0.3 fixes resolver compatibility with predictable timelocks and enhanced events");
    }
}