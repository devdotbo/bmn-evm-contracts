// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { Script, console } from "forge-std/Script.sol";
import { BMNAccessTokenV2 } from "../contracts/BMNAccessTokenV2.sol";
import { Create3Factory } from "../contracts/Create3Factory.sol";
import { Create3 } from "../contracts/libraries/Create3.sol";

/**
 * @title EstimateCreate3Gas
 * @notice Estimate gas costs for CREATE3 deployment
 * @dev Provides detailed gas breakdown for deployment planning
 */
contract EstimateCreate3Gas is Script {
    function run() external {
        address deployer = vm.addr(vm.envUint("DEPLOYER_PRIVATE_KEY"));
        
        console.log("=== CREATE3 GAS ESTIMATION ===");
        console.log("Deployer:", deployer);
        console.log("");
        
        // Estimate factory deployment
        estimateFactoryDeployment(deployer);
        
        // Estimate token deployment
        estimateTokenDeployment(deployer);
        
        // Compare with direct deployment
        compareDeploymentMethods(deployer);
        
        // Estimate for different chains
        estimateMultiChainCosts();
    }
    
    function estimateFactoryDeployment(address deployer) internal {
        console.log("--- CREATE3 Factory Deployment ---");
        
        // Factory bytecode
        bytes memory factoryBytecode = abi.encodePacked(
            type(Create3Factory).creationCode,
            abi.encode(deployer)
        );
        
        console.log("Factory bytecode size:", factoryBytecode.length, "bytes");
        
        // Estimate deployment gas
        uint256 baseGas = 21000; // Transaction base cost
        uint256 bytecodeGas = factoryBytecode.length * 200; // ~200 gas per byte
        uint256 createGas = 32000; // CREATE opcode
        uint256 executionGas = 100000; // Constructor execution estimate
        
        uint256 totalFactoryGas = baseGas + bytecodeGas + createGas + executionGas;
        
        console.log("Estimated gas breakdown:");
        console.log("  Base cost:", baseGas);
        console.log("  Bytecode cost:", bytecodeGas);
        console.log("  CREATE cost:", createGas);
        console.log("  Execution cost:", executionGas);
        console.log("  TOTAL:", totalFactoryGas);
        console.log("");
    }
    
    function estimateTokenDeployment(address deployer) internal {
        console.log("--- BMN Token Deployment via CREATE3 ---");
        
        // Token bytecode
        bytes memory tokenBytecode = abi.encodePacked(
            type(BMNAccessTokenV2).creationCode,
            abi.encode(deployer)
        );
        
        console.log("Token bytecode size:", tokenBytecode.length, "bytes");
        
        // CREATE3 specific costs
        uint256 proxyDeploymentGas = 55000; // CREATE2 proxy deployment
        uint256 proxyCallGas = 10000; // Proxy call overhead
        
        // Token deployment costs
        uint256 baseGas = 21000;
        uint256 bytecodeGas = tokenBytecode.length * 200;
        uint256 createGas = 32000;
        uint256 executionGas = 150000; // ERC20 constructor
        
        uint256 tokenDeploymentGas = bytecodeGas + createGas + executionGas;
        uint256 totalCreate3Gas = baseGas + proxyDeploymentGas + proxyCallGas + tokenDeploymentGas;
        
        console.log("Estimated gas breakdown:");
        console.log("  Base cost:", baseGas);
        console.log("  CREATE3 proxy:", proxyDeploymentGas);
        console.log("  Proxy call:", proxyCallGas);
        console.log("  Token deployment:", tokenDeploymentGas);
        console.log("  TOTAL:", totalCreate3Gas);
        console.log("");
    }
    
    function compareDeploymentMethods(address deployer) internal {
        console.log("--- Deployment Method Comparison ---");
        
        bytes memory tokenBytecode = abi.encodePacked(
            type(BMNAccessTokenV2).creationCode,
            abi.encode(deployer)
        );
        
        // Direct deployment
        uint256 directGas = 21000 + (tokenBytecode.length * 200) + 32000 + 150000;
        
        // CREATE2 deployment
        uint256 create2Gas = directGas; // Same as direct
        
        // CREATE3 deployment
        uint256 create3Gas = directGas + 55000 + 10000; // Add proxy overhead
        
        console.log("Direct deployment:", directGas, "gas");
        console.log("CREATE2 deployment:", create2Gas, "gas");
        console.log("CREATE3 deployment:", create3Gas, "gas");
        console.log("");
        
        uint256 overhead = ((create3Gas - directGas) * 100) / directGas;
        console.log("CREATE3 overhead:", overhead, "%");
        console.log("");
    }
    
    function estimateMultiChainCosts() internal view {
        console.log("--- Multi-Chain Deployment Costs ---");
        
        // Gas estimates
        uint256 factoryGas = 500000;
        uint256 tokenGas = 2555000;
        
        // Base Mainnet (30 gwei)
        uint256 baseGasPrice = 30 gwei;
        uint256 baseFactoryCost = factoryGas * baseGasPrice;
        uint256 baseTokenCost = tokenGas * baseGasPrice;
        uint256 baseTotalWei = baseFactoryCost + baseTokenCost;
        
        console.log("Base Mainnet (30 gwei):");
        console.log("  Factory:", baseFactoryCost / 1e18, "ETH");
        console.log("  Token:", baseTokenCost / 1e18, "ETH");
        console.log("  TOTAL:", baseTotalWei / 1e18, "ETH");
        console.log("");
        
        // Etherlink (estimated XTZ costs)
        console.log("Etherlink Mainnet (estimated):");
        console.log("  Factory: ~0.5 XTZ");
        console.log("  Token: ~2.0 XTZ");
        console.log("  TOTAL: ~2.5 XTZ");
        console.log("");
        
        // Total deployment cost for both chains
        console.log("Total Deployment Cost (both chains):");
        console.log("  Base: ~", baseTotalWei / 1e18, "ETH");
        console.log("  Etherlink: ~2.5 XTZ");
        console.log("");
        
        // Cost in USD (example rates)
        uint256 ethPrice = 3000; // $3000 per ETH
        uint256 xtzPrice = 5; // $5 per XTZ
        
        uint256 baseUSD = (baseTotalWei / 1e18) * ethPrice;
        uint256 etherlinkUSD = 25 * xtzPrice / 10; // 2.5 XTZ
        
        console.log("Estimated USD Cost:");
        console.log("  Base: ~$", baseUSD);
        console.log("  Etherlink: ~$", etherlinkUSD);
        console.log("  TOTAL: ~$", baseUSD + etherlinkUSD);
    }
}