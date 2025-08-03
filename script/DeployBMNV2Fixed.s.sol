// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { Script, console } from "forge-std/Script.sol";
import { BMNAccessTokenV2 } from "../contracts/BMNAccessTokenV2.sol";

contract DeployBMNV2Fixed is Script {
    // New salt to get a fresh address (avoiding the incorrectly deployed one)
    bytes32 constant SALT = keccak256("BMN_V2_CORRECT_DEPLOYMENT_2025_01_03");
    
    function run() external {
        uint256 deployerKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);
        
        // Calculate the init code hash
        bytes memory initCode = abi.encodePacked(
            type(BMNAccessTokenV2).creationCode,
            abi.encode(deployer) // Constructor parameter
        );
        bytes32 initCodeHash = keccak256(initCode);
        
        // Calculate expected address using CREATE2 formula
        address expectedAddress = address(uint160(uint256(keccak256(abi.encodePacked(
            bytes1(0xff),
            CREATE2_FACTORY,
            SALT,
            initCodeHash
        )))));
        
        console.log("=== BMN ACCESS TOKEN V2 FIXED DEPLOYMENT ===");
        console.log("Deployer:", deployer);
        console.log("CREATE2 Factory:", CREATE2_FACTORY);
        console.log("Salt:", vm.toString(abi.encodePacked(SALT)));
        console.log("Init code hash:", vm.toString(abi.encodePacked(initCodeHash)));
        console.log("Expected address:", expectedAddress);
        console.log("");
        
        // Deploy on Base mainnet
        deployOnChain("Base Mainnet", vm.envString("CHAIN_A_RPC_URL"), 8453, deployerKey, deployer, expectedAddress, initCode);
        
        // Deploy on Etherlink mainnet  
        deployOnChain("Etherlink Mainnet", vm.envString("CHAIN_B_RPC_URL"), 42793, deployerKey, deployer, expectedAddress, initCode);
        
        // Save deployment info
        string memory timestamp = vm.toString(block.timestamp);
        string memory deploymentJson = string(abi.encodePacked(
            '{\n',
            '  "deploymentTime": "', timestamp, '",\n',
            '  "deployer": "', vm.toString(deployer), '",\n',
            '  "create2Factory": "', vm.toString(CREATE2_FACTORY), '",\n',
            '  "salt": "', vm.toString(abi.encodePacked(SALT)), '",\n',
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
        
        // Create timestamp for filename
        string memory dateStr = "2025-01-03";
        vm.writeFile(
            string(abi.encodePacked("deployments/bmn-v2-fixed-deployment-", dateStr, ".json")), 
            deploymentJson
        );
        console.log("\nDeployment info saved to deployments/bmn-v2-fixed-deployment-", dateStr, ".json");
    }
    
    function deployOnChain(
        string memory chainName,
        string memory rpcUrl,
        uint256 chainId,
        uint256 deployerKey,
        address deployer,
        address expectedAddress,
        bytes memory initCode
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
            console.log("Deploying via CREATE2 factory...");
            
            // Deploy using CREATE2 factory
            (bool success,) = CREATE2_FACTORY.call(
                abi.encodePacked(SALT, initCode)
            );
            require(success, "CREATE2 deployment failed");
            
            // The contract should now be deployed at the expected address
            // Verify by checking code size
            uint256 deployedCodeSize;
            assembly {
                deployedCodeSize := extcodesize(expectedAddress)
            }
            require(deployedCodeSize > 0, "Contract not deployed at expected address");
            
            console.log("Token deployed at:", expectedAddress);
            
            BMNAccessTokenV2 token = BMNAccessTokenV2(expectedAddress);
            console.log("Deployment successful!");
            console.log("Name:", token.name());
            console.log("Symbol:", token.symbol());
            console.log("Decimals:", token.decimals());
            console.log("Owner:", token.owner());
            
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
            
            // Mint initial supply to deployer
            uint256 initialSupply = 1000 * 10**18; // 1000 BMN with 18 decimals
            token.mint(deployer, initialSupply);
            console.log("Minted initial supply:", initialSupply / 10**18, "BMN to deployer");
            
            // Test a transfer to verify it works
            console.log("\nTesting transfer functionality...");
            uint256 testAmount = 1 * 10**18; // 1 BMN
            token.transfer(alice, testAmount);
            uint256 aliceBalance = token.balanceOf(alice);
            console.log("Alice balance after test transfer:", aliceBalance / 10**18, "BMN");
            require(aliceBalance == testAmount, "Transfer test failed!");
            
            console.log("\nDeployment and verification complete!");
        }
        
        vm.stopBroadcast();
    }
}