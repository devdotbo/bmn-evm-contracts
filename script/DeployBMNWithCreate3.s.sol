// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { Script, console } from "forge-std/Script.sol";
import { BMNAccessTokenV2 } from "../contracts/BMNAccessTokenV2.sol";
import { Create3Factory } from "../contracts/Create3Factory.sol";

/**
 * @title DeployBMNWithCreate3
 * @notice Deploy BMN token using CREATE3 for deterministic cross-chain address
 * @dev Uses CREATE3 factory for deployment - same address on all chains regardless of nonce
 */
contract DeployBMNWithCreate3 is Script {
    // CREATE3 Factory address (deployed via CREATE2)
    address constant CREATE3_FACTORY = address(0); // Will be computed in constructor
    
    // Salt for BMN token deployment
    bytes32 constant BMN_SALT = keccak256("BMN_ACCESS_TOKEN_V3_CREATE3");
    
    // Chain configurations
    struct ChainConfig {
        string name;
        string rpcUrl;
        uint256 chainId;
    }
    
    function run() external {
        uint256 deployerKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);
        
        // First, calculate CREATE3 factory address
        address create3Factory = calculateCreate3FactoryAddress(deployer);
        
        console.log("=== BMN TOKEN DEPLOYMENT WITH CREATE3 ===");
        console.log("Deployer:", deployer);
        console.log("CREATE3 Factory:", create3Factory);
        console.log("Salt:", vm.toString(abi.encodePacked(BMN_SALT)));
        
        // Get expected BMN token address from CREATE3 factory
        vm.createSelectFork(vm.envString("BASE_RPC_URL"));
        Create3Factory factory = Create3Factory(create3Factory);
        address expectedBMNAddress = factory.getDeploymentAddress(deployer, BMN_SALT);
        
        console.log("Expected BMN Address:", expectedBMNAddress);
        console.log("");
        
        // Prepare creation code
        bytes memory creationCode = abi.encodePacked(
            type(BMNAccessTokenV2).creationCode,
            abi.encode(deployer) // Constructor parameter
        );
        
        // Deploy on Base mainnet
        ChainConfig memory baseConfig = ChainConfig({
            name: "Base Mainnet",
            rpcUrl: vm.envString("BASE_RPC_URL"),
            chainId: 8453
        });
        deployOnChain(baseConfig, deployerKey, deployer, create3Factory, expectedBMNAddress, creationCode);
        
        // Deploy on Etherlink mainnet
        ChainConfig memory etherlinkConfig = ChainConfig({
            name: "Etherlink Mainnet",
            rpcUrl: vm.envString("ETHERLINK_RPC_URL"),
            chainId: 42793
        });
        deployOnChain(etherlinkConfig, deployerKey, deployer, create3Factory, expectedBMNAddress, creationCode);
        
        // Save deployment info
        saveDeploymentInfo(deployer, create3Factory, expectedBMNAddress);
    }
    
    function calculateCreate3FactoryAddress(address deployer) internal pure returns (address) {
        // This should match the address from DeployCreate3Factory.s.sol
        bytes32 factorySalt = keccak256("BMN_CREATE3_FACTORY_V1");
        address create2Factory = 0x4e59b44847b379578588920cA78FbF26c0B4956C;
        
        bytes memory initCode = abi.encodePacked(
            type(Create3Factory).creationCode,
            abi.encode(deployer)
        );
        
        return address(uint160(uint256(keccak256(abi.encodePacked(
            bytes1(0xff),
            create2Factory,
            factorySalt,
            keccak256(initCode)
        )))));
    }
    
    function deployOnChain(
        ChainConfig memory config,
        uint256 deployerKey,
        address deployer,
        address create3Factory,
        address expectedBMNAddress,
        bytes memory creationCode
    ) internal {
        console.log(string(abi.encodePacked("\n--- Deploying on ", config.name, " ---")));
        console.log("RPC URL:", config.rpcUrl);
        console.log("Chain ID:", config.chainId);
        
        vm.createSelectFork(config.rpcUrl);
        require(block.chainid == config.chainId, "Chain ID mismatch");
        
        // Check if BMN already deployed
        uint256 codeSize;
        assembly {
            codeSize := extcodesize(expectedBMNAddress)
        }
        
        vm.startBroadcast(deployerKey);
        
        if (codeSize > 0) {
            console.log("BMN token already deployed at:", expectedBMNAddress);
            BMNAccessTokenV2 token = BMNAccessTokenV2(expectedBMNAddress);
            console.log("Name:", token.name());
            console.log("Symbol:", token.symbol());
            console.log("Decimals:", token.decimals());
            console.log("Owner:", token.owner());
            console.log("Total Supply:", token.totalSupply());
        } else {
            console.log("Deploying BMN token via CREATE3...");
            
            // Deploy using CREATE3 factory
            Create3Factory factory = Create3Factory(create3Factory);
            address deployed = factory.deploy(BMN_SALT, creationCode);
            
            require(deployed == expectedBMNAddress, "Deployment address mismatch");
            
            console.log("BMN token deployed at:", deployed);
            
            BMNAccessTokenV2 token = BMNAccessTokenV2(deployed);
            console.log("Deployment successful!");
            console.log("Name:", token.name());
            console.log("Symbol:", token.symbol());
            console.log("Decimals:", token.decimals());
            console.log("Owner:", token.owner());
            
            require(token.owner() == deployer, "Owner not set correctly");
            require(token.decimals() == 18, "Decimals not 18");
            
            // Setup initial configuration
            setupToken(token, deployer);
        }
        
        vm.stopBroadcast();
    }
    
    function setupToken(BMNAccessTokenV2 token, address deployer) internal {
        console.log("\nSetting up token...");
        
        // Authorize test accounts
        address alice = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
        token.authorize(alice);
        console.log("Authorized Alice:", alice);
        
        address bob = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;
        token.authorize(bob);
        console.log("Authorized Bob:", bob);
        
        // Mint initial supply
        uint256 initialSupply = 1000 * 10**18; // 1000 BMN
        token.mint(deployer, initialSupply);
        console.log("Minted initial supply:", initialSupply / 10**18, "BMN to deployer");
        
        // Test transfer
        uint256 testAmount = 1 * 10**18; // 1 BMN
        token.transfer(alice, testAmount);
        uint256 aliceBalance = token.balanceOf(alice);
        console.log("Alice balance after test transfer:", aliceBalance / 10**18, "BMN");
        require(aliceBalance == testAmount, "Transfer test failed!");
        
        console.log("\nToken setup complete!");
    }
    
    function saveDeploymentInfo(
        address deployer,
        address create3Factory,
        address bmnAddress
    ) internal {
        string memory timestamp = vm.toString(block.timestamp);
        string memory deploymentJson = string(abi.encodePacked(
            '{\n',
            '  "deploymentTime": "', timestamp, '",\n',
            '  "deployer": "', vm.toString(deployer), '",\n',
            '  "create3Factory": "', vm.toString(create3Factory), '",\n',
            '  "salt": "', vm.toString(abi.encodePacked(BMN_SALT)), '",\n',
            '  "bmnTokenAddress": "', vm.toString(bmnAddress), '",\n',
            '  "tokenDetails": {\n',
            '    "name": "BMN Access Token V2",\n',
            '    "symbol": "BMN",\n',
            '    "decimals": 18\n',
            '  },\n',
            '  "chains": {\n',
            '    "base_mainnet": {\n',
            '      "chainId": 8453,\n',
            '      "address": "', vm.toString(bmnAddress), '"\n',
            '    },\n',
            '    "etherlink_mainnet": {\n',
            '      "chainId": 42793,\n',
            '      "address": "', vm.toString(bmnAddress), '"\n',
            '    }\n',
            '  }\n',
            '}\n'
        ));
        
        string memory dateStr = "2025-01-08";
        vm.writeFile(
            string(abi.encodePacked("deployments/bmn-create3-deployment-", dateStr, ".json")), 
            deploymentJson
        );
        console.log("\nDeployment info saved to deployments/bmn-create3-deployment-", dateStr, ".json");
    }
}