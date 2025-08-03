// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import "../contracts/CrossChainResolverV2.sol";
import "../contracts/test/TestEscrowFactory.sol";
import { TokenMock } from "solidity-utils/contracts/mocks/TokenMock.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract DeployCrossChainResolver is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("Deploying CrossChainResolverV2 with deployer:", deployer);
        console.log("Chain ID:", block.chainid);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Check if we already have a factory deployed
        address factoryAddress = vm.envOr("FACTORY_ADDRESS", address(0));
        
        if (factoryAddress == address(0)) {
            console.log("No factory address provided, deploying TestEscrowFactory...");
            
            // Deploy mock contracts for factory dependencies
            address limitOrderProtocol = address(new TokenMock("Mock LOP", "LOP"));
            IERC20 feeToken = IERC20(address(new TokenMock("Fee Token", "FEE")));
            IERC20 accessToken = IERC20(address(new TokenMock("Access Token", "ACCESS")));
            
            // Deploy TestEscrowFactory
            TestEscrowFactory factory = new TestEscrowFactory(
                limitOrderProtocol,
                feeToken,
                accessToken,
                deployer, // owner
                86400,    // rescueDelaySrc: 1 day
                86400     // rescueDelayDst: 1 day
            );
            
            factoryAddress = address(factory);
            console.log("TestEscrowFactory deployed at:", factoryAddress);
        } else {
            console.log("Using existing factory at:", factoryAddress);
        }
        
        // Deploy CrossChainResolverV2
        CrossChainResolverV2 resolver = new CrossChainResolverV2(
            ITestEscrowFactory(factoryAddress)
        );
        
        console.log("CrossChainResolverV2 deployed at:", address(resolver));
        console.log("Owner:", resolver.owner());
        console.log("Factory:", address(resolver.factory()));
        
        vm.stopBroadcast();
        
        // Save deployment info
        string memory deploymentInfo = string(abi.encodePacked(
            "CHAIN_ID=", vm.toString(block.chainid), "\n",
            "FACTORY_ADDRESS=", vm.toString(factoryAddress), "\n",
            "RESOLVER_ADDRESS=", vm.toString(address(resolver)), "\n",
            "DEPLOYER_ADDRESS=", vm.toString(deployer), "\n"
        ));
        
        string memory filename = string(abi.encodePacked(
            "deployments/crosschain-resolver-",
            vm.toString(block.chainid),
            ".env"
        ));
        
        vm.writeFile(filename, deploymentInfo);
        console.log("Deployment info saved to:", filename);
    }
}