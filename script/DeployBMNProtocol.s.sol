// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { BaseCreate2Script } from "../dependencies/create2-helpers-0.5.0/src/BaseCreate2Script.sol";
import { console2 } from "forge-std/console2.sol";
import { EscrowSrc } from "../contracts/EscrowSrc.sol";
import { EscrowDst } from "../contracts/EscrowDst.sol";
import { CrossChainEscrowFactory } from "../contracts/CrossChainEscrowFactory.sol";
import { Constants } from "../contracts/Constants.sol";

// Import CREATE2 factory address constant
address constant CREATE2_FACTORY = 0x4e59b44847b379578588920cA78FbF26c0B4956C;

/**
 * @title DeployBMNProtocol
 * @notice Deploy escrow contracts using same pattern as BMN token for cross-chain consistency
 * @dev Follows exact deployment pattern that worked for BMN token
 */
contract DeployBMNProtocol is BaseCreate2Script {
    // Deterministic salts for cross-chain consistency
    bytes32 constant SRC_SALT = keccak256("BMN-EscrowSrc-v1.0.0");
    bytes32 constant DST_SALT = keccak256("BMN-EscrowDst-v1.0.0");
    bytes32 constant FACTORY_SALT = keccak256("BMN-EscrowFactory-v1.0.0");
    
    // Deployment results
    address public srcImplementation;
    address public dstImplementation;
    address public factory;
    
    function run() external {
        // Load deployer from environment
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployerAddr = vm.addr(deployerPrivateKey);
        
        console2.log("Deploying BMN Protocol with deployer:", deployerAddr);
        console2.log("=========================================");
        console2.log("Chain ID:", block.chainid);
        console2.log("CREATE2 Factory:", CREATE2_FACTORY);
        
        // Start broadcast
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy implementations with constructor args
        uint32 rescueDelay = 604800; // 7 days
        bytes memory srcConstructorArgs = abi.encode(
            rescueDelay,
            Constants.BMN_TOKEN // using BMN as access token for simplicity
        );
        
        srcImplementation = deployContract(
            SRC_SALT,
            type(EscrowSrc).creationCode,
            srcConstructorArgs,
            "EscrowSrc"
        );
        
        bytes memory dstConstructorArgs = abi.encode(
            rescueDelay,
            Constants.BMN_TOKEN // using BMN as access token for simplicity
        );
        
        dstImplementation = deployContract(
            DST_SALT,
            type(EscrowDst).creationCode,
            dstConstructorArgs,
            "EscrowDst"
        );
        
        // Deploy factory with pre-deployed implementations
        bytes memory factoryConstructorArgs = abi.encode(
            address(0), // limit order protocol (not needed for testing)
            Constants.BMN_TOKEN, // fee token (using BMN as fee token)
            Constants.BMN_TOKEN, // access token (using BMN as access token for simplicity)
            deployerAddr, // owner
            srcImplementation, // pre-deployed SRC implementation
            dstImplementation  // pre-deployed DST implementation
        );
        
        factory = deployContract(
            FACTORY_SALT,
            type(CrossChainEscrowFactory).creationCode,
            factoryConstructorArgs,
            "CrossChainEscrowFactory"
        );
        
        vm.stopBroadcast();
        
        // Log deployment summary
        console2.log("\n=== Deployment Complete ===");
        console2.log("SRC Implementation:", srcImplementation);
        console2.log("DST Implementation:", dstImplementation);
        console2.log("Factory:", factory);
        console2.log("\nThese addresses will be IDENTICAL on all chains!");
        console2.log("=========================================");
    }
    
    function deployContract(
        bytes32 salt,
        bytes memory creationCode,
        bytes memory constructorArgs,
        string memory contractName
    ) internal returns (address) {
        console2.log("\nDeploying", contractName, "...");
        console2.log("Salt:", vm.toString(salt));
        
        // Prepare init code
        bytes memory initCode = abi.encodePacked(creationCode, constructorArgs);
        
        // Calculate expected address
        address expectedAddress = vm.computeCreate2Address(
            salt,
            keccak256(initCode),
            CREATE2_FACTORY
        );
        
        console2.log("Expected address:", expectedAddress);
        
        // Check if already deployed
        uint256 codeSize;
        assembly {
            codeSize := extcodesize(expectedAddress)
        }
        
        if (codeSize > 0) {
            console2.log(contractName, "already deployed at:", expectedAddress);
            return expectedAddress;
        }
        
        // Deploy using CREATE2
        console2.log("Deploying", contractName, "with CREATE2...");
        (bool success,) = CREATE2_FACTORY.call(bytes.concat(salt, initCode));
        require(success, string.concat("CREATE2 deployment failed for ", contractName));
        
        // Verify deployment
        assembly {
            codeSize := extcodesize(expectedAddress)
        }
        require(codeSize > 0, string.concat(contractName, " deployment verification failed"));
        
        console2.log(contractName, "deployed successfully at:", expectedAddress);
        return expectedAddress;
    }
    
    // Dry run function to compute addresses without deployment
    function dryRun() external view {
        console2.log("\n=== DRY RUN - Expected Addresses ===");
        console2.log("Chain ID:", block.chainid);
        
        // Constructor args for implementations
        uint32 rescueDelay = 604800; // 7 days
        bytes memory implConstructorArgs = abi.encode(rescueDelay, Constants.BMN_TOKEN);
        
        // Compute SRC implementation address
        bytes memory srcInitCode = abi.encodePacked(
            type(EscrowSrc).creationCode,
            implConstructorArgs
        );
        address expectedSrc = vm.computeCreate2Address(
            SRC_SALT,
            keccak256(srcInitCode),
            CREATE2_FACTORY
        );
        console2.log("EscrowSrc will be deployed at:", expectedSrc);
        
        // Compute DST implementation address
        bytes memory dstInitCode = abi.encodePacked(
            type(EscrowDst).creationCode,
            implConstructorArgs
        );
        address expectedDst = vm.computeCreate2Address(
            DST_SALT,
            keccak256(dstInitCode),
            CREATE2_FACTORY
        );
        console2.log("EscrowDst will be deployed at:", expectedDst);
        
        // Compute factory address
        bytes memory factoryInitCode = abi.encodePacked(
            type(CrossChainEscrowFactory).creationCode,
            abi.encode(
                address(0), // limit order protocol
                Constants.BMN_TOKEN, // fee token
                Constants.BMN_TOKEN, // access token
                vm.envAddress("DEPLOYER"), // owner
                expectedSrc,
                expectedDst
            )
        );
        address expectedFactory = vm.computeCreate2Address(
            FACTORY_SALT,
            keccak256(factoryInitCode),
            CREATE2_FACTORY
        );
        console2.log("CrossChainEscrowFactory will be deployed at:", expectedFactory);
        
        console2.log("\nThese addresses will be IDENTICAL on all chains!");
        console2.log("=========================================");
    }
}