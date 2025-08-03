// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { Script, console } from "forge-std/Script.sol";
import { BMNAccessTokenV3 } from "../contracts/BMNAccessTokenV3.sol";
import { CREATE3Factory } from "zeframlou-create3-factory/CREATE3Factory.sol";

/**
 * @title VerifyBMNV3Create3
 * @notice Verify BMN V3 CREATE3 deployment across multiple chains
 * @dev Ensures addresses match and contracts are properly configured
 */
contract VerifyBMNV3Create3 is Script {
    // Known CREATE3 factory address
    address constant CREATE3_FACTORY = 0x9fBB3DF7C40Da2e5A0dE984fFE2CCB7C47cd0ABf;
    
    // Deployment salt
    bytes32 constant BMN_SALT = keccak256("BMN_ACCESS_TOKEN_V3_MAINNET_2025");
    
    struct ChainInfo {
        string name;
        uint256 chainId;
        string rpcUrl;
    }
    
    struct DeploymentInfo {
        address factory;
        address token;
        bool isDeployed;
        address owner;
        uint256 totalSupply;
        string version;
    }
    
    function run() external view {
        address deployer = vm.addr(vm.envUint("DEPLOYER_PRIVATE_KEY"));
        
        console.log("=== BMN V3 CREATE3 Verification ===");
        console.log("Deployer:", deployer);
        console.log("Salt:", vm.toString(BMN_SALT));
        console.log("");
        
        // Define chains to verify
        ChainInfo[] memory chains = new ChainInfo[](4);
        
        // Base Mainnet
        chains[0] = ChainInfo({
            name: "Base Mainnet",
            chainId: 8453,
            rpcUrl: vm.envOr("BASE_RPC_URL", string("https://mainnet.base.org"))
        });
        
        // Etherlink Mainnet
        chains[1] = ChainInfo({
            name: "Etherlink Mainnet",
            chainId: 42793,
            rpcUrl: vm.envOr("ETHERLINK_RPC_URL", string("https://node.mainnet.etherlink.com"))
        });
        
        // Base Sepolia (testnet)
        chains[2] = ChainInfo({
            name: "Base Sepolia",
            chainId: 84532,
            rpcUrl: vm.envOr("BASE_SEPOLIA_RPC_URL", string("https://sepolia.base.org"))
        });
        
        // Local Anvil
        chains[3] = ChainInfo({
            name: "Local Anvil",
            chainId: 31337,
            rpcUrl: "http://localhost:8545"
        });
        
        // Calculate expected address once (same for all chains)
        address expectedAddress = calculateExpectedAddress(deployer);
        console.log("Expected BMN V3 address (all chains):", expectedAddress);
        console.log("");
        
        // Verify each chain
        for (uint256 i = 0; i < chains.length; i++) {
            verifyChain(chains[i], expectedAddress);
        }
        
        console.log("");
        console.log("=== Verification Complete ===");
        console.log("All chains should have the same token address:", expectedAddress);
    }
    
    function calculateExpectedAddress(address deployer) internal view returns (address) {
        // Check if we can access the factory
        try vm.createSelectFork("https://mainnet.base.org") {
            uint256 codeSize;
            assembly {
                codeSize := extcodesize(CREATE3_FACTORY)
            }
            
            if (codeSize > 0) {
                CREATE3Factory factory = CREATE3Factory(CREATE3_FACTORY);
                return factory.getDeployed(deployer, BMN_SALT);
            }
        } catch {}
        
        // If factory not available, return zero
        return address(0);
    }
    
    function verifyChain(ChainInfo memory chain, address expectedAddress) internal view {
        console.log(string(abi.encodePacked("--- ", chain.name, " ---")));
        
        // Try to connect to chain
        try vm.createSelectFork(chain.rpcUrl) {
            if (block.chainid != chain.chainId) {
                console.log("Warning: Chain ID mismatch. Expected", chain.chainId, "got", block.chainid);
            }
            
            DeploymentInfo memory info = getDeploymentInfo(expectedAddress);
            
            if (info.isDeployed) {
                console.log("✅ Token deployed at:", expectedAddress);
                console.log("   Owner:", info.owner);
                console.log("   Total Supply:", info.totalSupply / 10**18, "BMN");
                console.log("   Version:", info.version);
                
                // Verify it's the correct implementation
                BMNAccessTokenV3 token = BMNAccessTokenV3(expectedAddress);
                require(
                    keccak256(bytes(token.name())) == keccak256(bytes("BMN Access Token V3")),
                    "Invalid token name"
                );
                require(
                    keccak256(bytes(token.symbol())) == keccak256(bytes("BMN")),
                    "Invalid token symbol"
                );
                require(token.decimals() == 18, "Invalid decimals");
            } else {
                console.log("❌ Token not deployed yet");
            }
            
            // Check factory
            uint256 factoryCodeSize;
            assembly {
                factoryCodeSize := extcodesize(CREATE3_FACTORY)
            }
            
            if (factoryCodeSize > 0) {
                console.log("   Factory available at:", CREATE3_FACTORY);
            } else {
                console.log("   Factory not deployed");
            }
            
        } catch Error(string memory reason) {
            console.log("❌ Failed to connect:", reason);
        } catch {
            console.log("❌ Failed to connect to chain");
        }
        
        console.log("");
    }
    
    function getDeploymentInfo(address tokenAddress) internal view returns (DeploymentInfo memory info) {
        uint256 codeSize;
        assembly {
            codeSize := extcodesize(tokenAddress)
        }
        
        info.isDeployed = codeSize > 0;
        info.token = tokenAddress;
        info.factory = CREATE3_FACTORY;
        
        if (info.isDeployed) {
            BMNAccessTokenV3 token = BMNAccessTokenV3(tokenAddress);
            info.owner = token.owner();
            info.totalSupply = token.totalSupply();
            info.version = token.version();
        }
    }
}