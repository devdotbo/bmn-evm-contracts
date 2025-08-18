// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Script.sol";

/**
 * @title DeployConfig
 * @notice Configuration helper for SimplifiedEscrowFactory deployments
 * @dev Provides chain-specific configurations and helper functions
 */
contract DeployConfig is Script {
    
    // Bridge-Me-Not SimpleLimitOrderProtocol addresses (custom implementation)
    struct ChainConfig {
        uint256 chainId;
        string name;
        address limitOrderProtocol;
        address weth;
        address oneInchToken; // For access control if needed
        string rpcEnvKey;
        string etherscanApiKeyEnvKey;
    }
    
    // Deployment parameters
    struct DeployParams {
        address limitOrderProtocol;
        address owner;
        uint32 rescueDelay;
        address accessToken;
        address weth;
        bool useMockProtocol;
        bool useCreate3;
        string chainName;
    }
    
    /**
     * @notice Get chain configuration
     */
    function getChainConfig(uint256 chainId) public pure returns (ChainConfig memory) {
        if (chainId == 1) {
            return ChainConfig({
                chainId: 1,
                name: "Ethereum Mainnet",
                limitOrderProtocol: 0x119c71D3BbAC22029622cbaEc24854d3D32D2828,
                weth: 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2,
                oneInchToken: 0x111111111117dC0aa78b770fA6A738034120C302,
                rpcEnvKey: "MAINNET_RPC_URL",
                etherscanApiKeyEnvKey: "ETHERSCAN_API_KEY"
            });
        } else if (chainId == 10) {
            return ChainConfig({
                chainId: 10,
                name: "Optimism",
                limitOrderProtocol: 0xe767105dcfB3034a346578afd2aFD8e583171489, // Bridge-Me-Not SimpleLimitOrderProtocol
                weth: 0x4200000000000000000000000000000000000006,
                oneInchToken: address(0), // No 1INCH on Optimism yet
                rpcEnvKey: "OPTIMISM_RPC_URL",
                etherscanApiKeyEnvKey: "OPTIMISM_ETHERSCAN_API_KEY"
            });
        } else if (chainId == 8453) {
            return ChainConfig({
                chainId: 8453,
                name: "Base",
                limitOrderProtocol: 0xe767105dcfB3034a346578afd2aFD8e583171489, // Bridge-Me-Not SimpleLimitOrderProtocol
                weth: 0x4200000000000000000000000000000000000006,
                oneInchToken: address(0), // No 1INCH on Base yet
                rpcEnvKey: "BASE_RPC_URL",
                etherscanApiKeyEnvKey: "BASESCAN_API_KEY"
            });
        } else if (chainId == 137) {
            return ChainConfig({
                chainId: 137,
                name: "Polygon",
                limitOrderProtocol: 0x119c71D3BbAC22029622cbaEc24854d3D32D2828,
                weth: 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270, // WMATIC
                oneInchToken: 0x9c2C5fd7b07E95EE044DDeba0E97a665F142394f,
                rpcEnvKey: "POLYGON_RPC_URL",
                etherscanApiKeyEnvKey: "POLYGONSCAN_API_KEY"
            });
        } else if (chainId == 42161) {
            return ChainConfig({
                chainId: 42161,
                name: "Arbitrum One",
                limitOrderProtocol: 0x119c71D3BbAC22029622cbaEc24854d3D32D2828,
                weth: 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1,
                oneInchToken: address(0), // No 1INCH on Arbitrum yet
                rpcEnvKey: "ARBITRUM_RPC_URL",
                etherscanApiKeyEnvKey: "ARBISCAN_API_KEY"
            });
        } else if (chainId == 56) {
            return ChainConfig({
                chainId: 56,
                name: "BSC",
                limitOrderProtocol: 0x119c71D3BbAC22029622cbaEc24854d3D32D2828,
                weth: 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c, // WBNB
                oneInchToken: 0x111111111117dC0aa78b770fA6A738034120C302,
                rpcEnvKey: "BSC_RPC_URL",
                etherscanApiKeyEnvKey: "BSCSCAN_API_KEY"
            });
        } else if (chainId == 31337) {
            return ChainConfig({
                chainId: 31337,
                name: "Local Anvil",
                limitOrderProtocol: address(0), // Will deploy mock
                weth: address(0),
                oneInchToken: address(0),
                rpcEnvKey: "LOCAL_RPC_URL",
                etherscanApiKeyEnvKey: ""
            });
        } else {
            return ChainConfig({
                chainId: chainId,
                name: "Unknown Chain",
                limitOrderProtocol: address(0),
                weth: address(0),
                oneInchToken: address(0),
                rpcEnvKey: "RPC_URL",
                etherscanApiKeyEnvKey: "ETHERSCAN_API_KEY"
            });
        }
    }
    
    /**
     * @notice Build deployment parameters for current chain
     */
    function buildDeployParams(address deployer) public view returns (DeployParams memory) {
        ChainConfig memory config = getChainConfig(block.chainid);
        
        DeployParams memory params;
        params.chainName = config.name;
        params.owner = vm.envOr("OWNER", deployer);
        params.rescueDelay = uint32(vm.envOr("RESCUE_DELAY", uint256(7 days)));
        
        // Override protocol address from environment if provided
        params.limitOrderProtocol = vm.envOr("LIMIT_ORDER_PROTOCOL", config.limitOrderProtocol);
        
        // WETH address (can be overridden)
        params.weth = vm.envOr("WETH", config.weth);
        
        // Access token (optional, defaults to no access control)
        params.accessToken = vm.envOr("ACCESS_TOKEN", address(0));
        
        // Use mock protocol for local testing or if explicitly requested
        params.useMockProtocol = block.chainid == 31337 || vm.envOr("USE_MOCK_PROTOCOL", false);
        
        // Use CREATE3 for production deployments (not local)
        params.useCreate3 = block.chainid != 31337 && vm.envOr("USE_CREATE3", true);
        
        // If no protocol address and not using mock, error
        if (params.limitOrderProtocol == address(0) && !params.useMockProtocol) {
            revert("No LimitOrderProtocol address configured for this chain. Set LIMIT_ORDER_PROTOCOL or USE_MOCK_PROTOCOL=true");
        }
        
        return params;
    }
    
    /**
     * @notice Get RPC URL for current chain
     */
    function getRpcUrl() public view returns (string memory) {
        ChainConfig memory config = getChainConfig(block.chainid);
        
        // Try chain-specific env var first
        string memory rpcUrl = vm.envOr(config.rpcEnvKey, string(""));
        
        // Fallback to generic RPC_URL
        if (bytes(rpcUrl).length == 0) {
            rpcUrl = vm.envOr("RPC_URL", string(""));
        }
        
        // Default for local
        if (bytes(rpcUrl).length == 0 && block.chainid == 31337) {
            rpcUrl = "http://localhost:8545";
        }
        
        return rpcUrl;
    }
    
    /**
     * @notice Get Etherscan API key for current chain
     */
    function getEtherscanApiKey() public view returns (string memory) {
        ChainConfig memory config = getChainConfig(block.chainid);
        
        if (bytes(config.etherscanApiKeyEnvKey).length == 0) {
            return "";
        }
        
        return vm.envOr(config.etherscanApiKeyEnvKey, string(""));
    }
    
    /**
     * @notice Log deployment configuration
     */
    function logConfig(DeployParams memory params) public view {
        console.log("=== Deployment Configuration ===");
        console.log("Chain:", params.chainName);
        console.log("Chain ID:", block.chainid);
        
        console.log("\nAddresses:");
        console.log("- Owner:", params.owner);
        console.log("- Limit Order Protocol:", params.limitOrderProtocol);
        console.log("- WETH:", params.weth);
        console.log("- Access Token:", params.accessToken);
        
        console.log("\nParameters:");
        console.log("- Rescue Delay:", params.rescueDelay, "seconds");
        console.log("  (", params.rescueDelay / 86400, "days)");
        console.log("- Use Mock Protocol:", params.useMockProtocol);
        console.log("- Use CREATE3:", params.useCreate3);
    }
    
    /**
     * @notice Generate verification command for deployed contract
     */
    function getVerificationCommand(
        address contractAddress,
        DeployParams memory params
    ) public view returns (string memory) {
        ChainConfig memory config = getChainConfig(block.chainid);
        
        string memory chainName;
        if (block.chainid == 1) chainName = "mainnet";
        else if (block.chainid == 10) chainName = "optimism";
        else if (block.chainid == 8453) chainName = "base";
        else if (block.chainid == 137) chainName = "polygon";
        else if (block.chainid == 42161) chainName = "arbitrum";
        else if (block.chainid == 56) chainName = "bsc";
        else return "Verification not configured for this chain";
        
        string memory cmd = string.concat(
            "forge verify-contract --watch \\\n",
            "  --chain ", chainName, " \\\n",
            "  ", vm.toString(contractAddress), " \\\n",
            "  contracts/SimplifiedEscrowFactory.sol:SimplifiedEscrowFactory \\\n",
            "  --constructor-args $(cast abi-encode \"constructor(address,address,uint32,address,address)\" ",
            vm.toString(params.limitOrderProtocol), " ",
            vm.toString(params.owner), " ",
            vm.toString(params.rescueDelay), " ",
            vm.toString(params.accessToken), " ",
            vm.toString(params.weth), ") \\\n",
            "  --verifier etherscan \\\n",
            "  --etherscan-api-key $", config.etherscanApiKeyEnvKey
        );
        
        return cmd;
    }
    
    /**
     * @notice Show configuration for all supported chains
     */
    function showAllChains() external view {
        console.log("=== Supported Chain Configurations ===\n");
        
        uint256[] memory chainIds = new uint256[](7);
        chainIds[0] = 1;      // Mainnet
        chainIds[1] = 10;     // Optimism
        chainIds[2] = 8453;   // Base
        chainIds[3] = 137;    // Polygon
        chainIds[4] = 42161;  // Arbitrum
        chainIds[5] = 56;     // BSC
        chainIds[6] = 31337;  // Local
        
        for (uint256 i = 0; i < chainIds.length; i++) {
            ChainConfig memory config = getChainConfig(chainIds[i]);
            
            console.log(config.name, "(Chain ID:", config.chainId, ")");
            console.log("- Limit Order Protocol:", config.limitOrderProtocol);
            console.log("- WETH:", config.weth);
            if (config.oneInchToken != address(0)) {
                console.log("- 1INCH Token:", config.oneInchToken);
            }
            console.log("- RPC Env Key:", config.rpcEnvKey);
            if (bytes(config.etherscanApiKeyEnvKey).length > 0) {
                console.log("- Etherscan API Key:", config.etherscanApiKeyEnvKey);
            }
            console.log("");
        }
        
        console.log("Environment Variable Overrides:");
        console.log("- LIMIT_ORDER_PROTOCOL: Override protocol address");
        console.log("- OWNER: Set factory owner");
        console.log("- RESCUE_DELAY: Set rescue delay (seconds)");
        console.log("- ACCESS_TOKEN: Set access token for escrows");
        console.log("- WETH: Override WETH address");
        console.log("- USE_MOCK_PROTOCOL: Deploy mock protocol (true/false)");
        console.log("- USE_CREATE3: Use CREATE3 deployment (true/false)");
    }
}