// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { Script, console } from "forge-std/Script.sol";
import { BMNAccessTokenV2 } from "../contracts/BMNAccessTokenV2.sol";
import { Create3Factory } from "../contracts/Create3Factory.sol";

/**
 * @title VerifyCreate3Deployment
 * @notice Verify CREATE3 deployments across multiple chains
 * @dev Ensures addresses match and contracts are properly configured
 */
contract VerifyCreate3Deployment is Script {
    // Expected addresses (computed deterministically)
    address constant EXPECTED_FACTORY = address(0); // Will be computed
    address constant EXPECTED_BMN = address(0); // Will be computed
    
    // Known salts
    bytes32 constant FACTORY_SALT = keccak256("BMN_CREATE3_FACTORY_V1");
    bytes32 constant BMN_SALT = keccak256("BMN_ACCESS_TOKEN_V3_CREATE3");
    
    // Chain configurations
    struct ChainConfig {
        string name;
        string rpcUrl;
        uint256 chainId;
    }
    
    // Deployment status
    struct DeploymentStatus {
        bool factoryDeployed;
        bool tokenDeployed;
        address factoryAddress;
        address tokenAddress;
        address factoryOwner;
        address tokenOwner;
        uint256 tokenSupply;
        bool isValid;
    }
    
    mapping(uint256 => DeploymentStatus) public chainStatus;
    
    function run() external view {
        address deployer = vm.addr(vm.envUint("DEPLOYER_PRIVATE_KEY"));
        
        console.log("=== CREATE3 DEPLOYMENT VERIFICATION ===");
        console.log("Deployer:", deployer);
        console.log("");
        
        // Calculate expected addresses
        address expectedFactory = calculateCreate3FactoryAddress(deployer);
        address expectedBMN = calculateBMNAddress(deployer, expectedFactory);
        
        console.log("Expected Addresses:");
        console.log("- CREATE3 Factory:", expectedFactory);
        console.log("- BMN Token:", expectedBMN);
        console.log("");
        
        // Verify Base mainnet
        ChainConfig memory baseConfig = ChainConfig({
            name: "Base Mainnet",
            rpcUrl: vm.envString("BASE_RPC_URL"),
            chainId: 8453
        });
        DeploymentStatus memory baseStatus = verifyChain(baseConfig, expectedFactory, expectedBMN);
        
        // Verify Etherlink mainnet
        ChainConfig memory etherlinkConfig = ChainConfig({
            name: "Etherlink Mainnet", 
            rpcUrl: vm.envString("ETHERLINK_RPC_URL"),
            chainId: 42793
        });
        DeploymentStatus memory etherlinkStatus = verifyChain(etherlinkConfig, expectedFactory, expectedBMN);
        
        // Summary
        console.log("\n=== VERIFICATION SUMMARY ===");
        console.log("Base Mainnet:");
        printStatus(baseStatus);
        
        console.log("\nEtherlink Mainnet:");
        printStatus(etherlinkStatus);
        
        // Cross-chain consistency check
        console.log("\n=== CROSS-CHAIN CONSISTENCY ===");
        if (baseStatus.isValid && etherlinkStatus.isValid) {
            console.log("✅ Both chains deployed successfully");
            
            // Verify addresses match
            require(
                baseStatus.factoryAddress == etherlinkStatus.factoryAddress,
                "Factory addresses don't match!"
            );
            require(
                baseStatus.tokenAddress == etherlinkStatus.tokenAddress,
                "Token addresses don't match!"
            );
            
            console.log("✅ Addresses match across chains");
            console.log("✅ Deployment verified successfully!");
        } else {
            console.log("❌ Deployment incomplete or invalid");
            if (!baseStatus.isValid) {
                console.log("  - Base deployment issues");
            }
            if (!etherlinkStatus.isValid) {
                console.log("  - Etherlink deployment issues");
            }
        }
    }
    
    function calculateCreate3FactoryAddress(address deployer) internal pure returns (address) {
        address create2Factory = 0x4e59b44847b379578588920cA78FbF26c0B4956C;
        
        bytes memory initCode = abi.encodePacked(
            type(Create3Factory).creationCode,
            abi.encode(deployer)
        );
        
        return address(uint160(uint256(keccak256(abi.encodePacked(
            bytes1(0xff),
            create2Factory,
            FACTORY_SALT,
            keccak256(initCode)
        )))));
    }
    
    function calculateBMNAddress(address deployer, address factory) internal view returns (address) {
        // Create a temporary fork to call the factory
        vm.createSelectFork(vm.envString("BASE_RPC_URL"));
        
        // Check if factory exists
        uint256 codeSize;
        assembly {
            codeSize := extcodesize(factory)
        }
        
        if (codeSize > 0) {
            Create3Factory create3Factory = Create3Factory(factory);
            return create3Factory.getDeploymentAddress(deployer, BMN_SALT);
        } else {
            // If factory doesn't exist, return zero address
            return address(0);
        }
    }
    
    function verifyChain(
        ChainConfig memory config,
        address expectedFactory,
        address expectedBMN
    ) internal view returns (DeploymentStatus memory status) {
        console.log(string(abi.encodePacked("\n--- Verifying ", config.name, " ---")));
        console.log("RPC URL:", config.rpcUrl);
        console.log("Chain ID:", config.chainId);
        
        vm.createSelectFork(config.rpcUrl);
        require(block.chainid == config.chainId, "Chain ID mismatch");
        
        // Check factory
        uint256 factoryCodeSize;
        assembly {
            factoryCodeSize := extcodesize(expectedFactory)
        }
        
        status.factoryDeployed = factoryCodeSize > 0;
        status.factoryAddress = expectedFactory;
        
        if (status.factoryDeployed) {
            console.log("✅ Factory deployed at:", expectedFactory);
            Create3Factory factory = Create3Factory(expectedFactory);
            status.factoryOwner = factory.owner();
            console.log("  Owner:", status.factoryOwner);
        } else {
            console.log("❌ Factory not deployed");
        }
        
        // Check token
        uint256 tokenCodeSize;
        assembly {
            tokenCodeSize := extcodesize(expectedBMN)
        }
        
        status.tokenDeployed = tokenCodeSize > 0;
        status.tokenAddress = expectedBMN;
        
        if (status.tokenDeployed) {
            console.log("✅ BMN token deployed at:", expectedBMN);
            BMNAccessTokenV2 token = BMNAccessTokenV2(expectedBMN);
            status.tokenOwner = token.owner();
            status.tokenSupply = token.totalSupply();
            console.log("  Owner:", status.tokenOwner);
            console.log("  Total Supply:", status.tokenSupply / 10**18, "BMN");
            
            // Verify token properties
            require(
                keccak256(bytes(token.name())) == keccak256(bytes("BMN Access Token V2")),
                "Invalid token name"
            );
            require(
                keccak256(bytes(token.symbol())) == keccak256(bytes("BMN")),
                "Invalid token symbol"
            );
            require(token.decimals() == 18, "Invalid decimals");
        } else {
            console.log("❌ BMN token not deployed");
        }
        
        // Overall status
        status.isValid = status.factoryDeployed && status.tokenDeployed;
        
        return status;
    }
    
    function printStatus(DeploymentStatus memory status) internal pure {
        if (status.isValid) {
            console.log("  ✅ Status: VALID");
            console.log("  Factory:", status.factoryAddress);
            console.log("  Token:", status.tokenAddress);
            console.log("  Supply:", status.tokenSupply / 10**18, "BMN");
        } else {
            console.log("  ❌ Status: INVALID");
            if (!status.factoryDeployed) {
                console.log("  - Factory not deployed");
            }
            if (!status.tokenDeployed) {
                console.log("  - Token not deployed");
            }
        }
    }
}