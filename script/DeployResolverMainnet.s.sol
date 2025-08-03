// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import "../contracts/CrossChainResolverV2.sol";
import "../contracts/test/TestEscrowFactory.sol";
import { TokenMock } from "solidity-utils/contracts/mocks/TokenMock.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract DeployResolverMainnet is Script {
    // Chain IDs
    uint256 constant BASE_MAINNET = 8453;
    uint256 constant ETHERLINK_MAINNET = 42793;
    
    // BMN Token addresses (from previous deployments)
    address constant BMN_TOKEN_BASE = 0x9C32618CeeC96b9DC0b7c0976c4b4cf2Ee452988;
    address constant BMN_TOKEN_ETHERLINK = 0x9C32618CeeC96b9DC0b7c0976c4b4cf2Ee452988;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("=== Deploying CrossChain Infrastructure ===");
        console.log("Deployer:", deployer);
        console.log("Chain ID:", block.chainid);
        
        // Validate we're on the right chain
        require(
            block.chainid == BASE_MAINNET || block.chainid == ETHERLINK_MAINNET,
            "Must deploy on Base or Etherlink mainnet"
        );
        
        string memory chainName = block.chainid == BASE_MAINNET ? "Base" : "Etherlink";
        console.log("Deploying on:", chainName);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy TestEscrowFactory
        console.log("\n1. Deploying TestEscrowFactory...");
        
        // For hackathon, use simple mock tokens for fees and access
        // In production, these would be real tokens
        address limitOrderProtocol = deployer; // Simplified for hackathon
        IERC20 feeToken = IERC20(address(new TokenMock("Fee Token", "FEE")));
        IERC20 accessToken = IERC20(address(new TokenMock("Access Token", "ACCESS")));
        
        TestEscrowFactory factory = new TestEscrowFactory(
            limitOrderProtocol,
            feeToken,
            accessToken,
            deployer,  // owner
            3600,      // rescueDelaySrc: 1 hour (shorter for hackathon)
            3600       // rescueDelayDst: 1 hour
        );
        
        console.log("TestEscrowFactory deployed at:", address(factory));
        console.log("- Fee Token:", address(feeToken));
        console.log("- Access Token:", address(accessToken));
        
        // Deploy CrossChainResolverV2
        console.log("\n2. Deploying CrossChainResolverV2...");
        CrossChainResolverV2 resolver = new CrossChainResolverV2(
            ITestEscrowFactory(address(factory))
        );
        
        console.log("CrossChainResolverV2 deployed at:", address(resolver));
        
        // Mint some access tokens to the resolver owner for testing
        console.log("\n3. Minting access tokens for testing...");
        TokenMock(address(accessToken)).mint(deployer, 1000 * 10**18);
        console.log("Minted 1000 ACCESS tokens to deployer");
        
        vm.stopBroadcast();
        
        // Save deployment addresses
        console.log("\n=== Deployment Summary ===");
        console.log(string(abi.encodePacked("Chain: ", chainName, " (", vm.toString(block.chainid), ")")));
        console.log("Factory:", address(factory));
        console.log("Resolver:", address(resolver));
        console.log("Fee Token:", address(feeToken));
        console.log("Access Token:", address(accessToken));
        console.log("BMN Token:", block.chainid == BASE_MAINNET ? BMN_TOKEN_BASE : BMN_TOKEN_ETHERLINK);
        
        // Save to file
        string memory deploymentInfo = string(abi.encodePacked(
            "# ", chainName, " Mainnet Deployment\n",
            "CHAIN_ID=", vm.toString(block.chainid), "\n",
            "CHAIN_NAME=", chainName, "\n",
            "FACTORY_ADDRESS=", vm.toString(address(factory)), "\n",
            "RESOLVER_ADDRESS=", vm.toString(address(resolver)), "\n",
            "FEE_TOKEN_ADDRESS=", vm.toString(address(feeToken)), "\n",
            "ACCESS_TOKEN_ADDRESS=", vm.toString(address(accessToken)), "\n",
            "BMN_TOKEN_ADDRESS=", vm.toString(block.chainid == BASE_MAINNET ? BMN_TOKEN_BASE : BMN_TOKEN_ETHERLINK), "\n",
            "DEPLOYER_ADDRESS=", vm.toString(deployer), "\n",
            "DEPLOYMENT_TIMESTAMP=", vm.toString(block.timestamp), "\n"
        ));
        
        string memory filename = string(abi.encodePacked(
            "deployments/mainnet-",
            chainName,
            "-resolver.env"
        ));
        
        vm.writeFile(filename, deploymentInfo);
        console.log("\nDeployment info saved to:", filename);
        
        // Output commands for verification
        console.log("\n=== Next Steps ===");
        console.log("1. Verify contracts on explorer:");
        console.log("   Factory verification:");
        console.log("   forge verify-contract", address(factory), "contracts/test/TestEscrowFactory.sol:TestEscrowFactory --chain", chainName);
        console.log("\n   Resolver verification:");
        console.log("   forge verify-contract", address(resolver), "contracts/CrossChainResolverV2.sol:CrossChainResolverV2 --chain", chainName);
        
        console.log("\n2. Fund resolver with BMN tokens on both chains");
        console.log("3. Test cross-chain swap functionality");
    }
}