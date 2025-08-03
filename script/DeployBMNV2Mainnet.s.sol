// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { Script, console } from "forge-std/Script.sol";
import { BMNAccessTokenV2 } from "../contracts/BMNAccessTokenV2.sol";
import { Create2 } from "@openzeppelin/contracts/utils/Create2.sol";

contract DeployBMNV2Mainnet is Script {
    // New salt for V2 with 18 decimals (different from original deployment)
    bytes32 constant SALT = keccak256("BMN_ACCESS_TOKEN_V2_18_DECIMALS");
    
    struct ChainDeployment {
        string name;
        string rpcUrl;
        uint256 chainId;
        address bmnTokenAddress;
    }
    
    function run() external {
        uint256 deployerKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);
        
        // Calculate expected address (same on both chains due to CREATE2)
        bytes memory bytecode = abi.encodePacked(
            type(BMNAccessTokenV2).creationCode,
            abi.encode(deployer) // Constructor parameter
        );
        address expectedAddress = Create2.computeAddress(SALT, keccak256(bytecode), CREATE2_FACTORY);
        
        console.log("=== BMN ACCESS TOKEN V2 (18 DECIMALS) DEPLOYMENT ===");
        console.log("Deployer:", deployer);
        console.log("Salt:", uint256(SALT));
        console.log("Expected address on all chains:", expectedAddress);
        console.log("");
        
        // Deploy on Base mainnet
        deployOnChain("Base Mainnet", vm.envString("CHAIN_A_RPC_URL"), 8453, deployerKey, deployer, expectedAddress);
        
        // Deploy on Etherlink mainnet
        deployOnChain("Etherlink Mainnet", vm.envString("CHAIN_B_RPC_URL"), 42793, deployerKey, deployer, expectedAddress);
        
        // Save deployment info
        string memory timestamp = vm.toString(block.timestamp);
        string memory deploymentJson = string(abi.encodePacked(
            '{\n',
            '  "deploymentTime": "', timestamp, '",\n',
            '  "deployer": "', vm.toString(deployer), '",\n',
            '  "bmnTokenV2Address": "', vm.toString(expectedAddress), '",\n',
            '  "decimals": 18,\n',
            '  "chains": {\n',
            '    "base_mainnet": {\n',
            '      "chainId": 8453,\n',
            '      "address": "', vm.toString(expectedAddress), '"\n',
            '    },\n',
            '    "etherlink_mainnet": {\n',
            '      "chainId": 42793,\n',
            '      "address": "', vm.toString(expectedAddress), '"\n',
            '    }\n',
            '  }\n',
            '}\n'
        ));
        
        vm.writeFile("deployments/bmn-v2-mainnet-deployment.json", deploymentJson);
        console.log("\nDeployment info saved to deployments/bmn-v2-mainnet-deployment.json");
    }
    
    function deployOnChain(
        string memory chainName,
        string memory rpcUrl,
        uint256 chainId,
        uint256 deployerKey,
        address deployer,
        address expectedAddress
    ) internal {
        console.log(string(abi.encodePacked("\n--- Deploying on ", chainName, " ---")));
        console.log("RPC URL:", rpcUrl);
        console.log("Chain ID:", chainId);
        
        vm.createSelectFork(rpcUrl);
        require(block.chainid == chainId, "Chain ID mismatch");
        
        // Check if already deployed
        uint256 codeSize;
        assembly {
            codeSize := extcodesize(expectedAddress)
        }
        
        vm.startBroadcast(deployerKey);
        
        if (codeSize > 0) {
            console.log("Token already deployed at:", expectedAddress);
            BMNAccessTokenV2 token = BMNAccessTokenV2(expectedAddress);
            console.log("Name:", token.name());
            console.log("Symbol:", token.symbol());
            console.log("Decimals:", token.decimals());
            console.log("Owner:", token.owner());
            console.log("Total Supply:", token.totalSupply());
        } else {
            // Deploy with CREATE2
            BMNAccessTokenV2 token = new BMNAccessTokenV2{salt: SALT}(deployer);
            console.log("Token deployed at:", address(token));
            
            console.log("Deployment successful!");
            console.log("Name:", token.name());
            console.log("Symbol:", token.symbol());
            console.log("Decimals:", token.decimals());
            console.log("Owner:", token.owner());
            
            require(address(token) == expectedAddress, "Deployment address mismatch");
            require(token.owner() == deployer, "Owner not set correctly");
            require(token.decimals() == 18, "Decimals not 18");
            
            // Authorize test accounts
            console.log("\nAuthorizing test accounts...");
            
            // Alice
            address alice = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
            token.authorize(alice);
            console.log("Authorized Alice:", alice);
            
            // Bob (Resolver)
            address bob = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;
            token.authorize(bob);
            console.log("Authorized Bob:", bob);
            
            // Mainnet deployer (for future use)
            address mainnetDeployer = 0x5f29827e25dc174a6A51C99e6811Bbd7581285b0;
            if (mainnetDeployer != deployer) {
                token.authorize(mainnetDeployer);
                console.log("Authorized mainnet deployer:", mainnetDeployer);
            }
            
            // Mint initial supply to deployer
            uint256 initialSupply = 1000 * 10**18; // 1000 BMN with 18 decimals
            token.mint(deployer, initialSupply);
            console.log("Minted initial supply:", initialSupply / 10**18, "BMN to deployer");
            
            console.log("\nDeployment and setup complete!");
        }
        
        vm.stopBroadcast();
    }
}