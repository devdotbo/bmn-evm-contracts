// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { EscrowFactory } from "../contracts/EscrowFactory.sol";
import { TestEscrowFactory } from "../contracts/test/TestEscrowFactory.sol";
import { TokenMock } from "../contracts/mocks/TokenMock.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DeployFixed is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        
        // Get existing deployment info
        string memory deploymentPath = string(abi.encodePacked("deployments/", vm.envString("DEPLOYMENT_NAME"), ".json"));
        string memory json = vm.readFile(deploymentPath);
        
        address limitOrderProtocol = vm.parseJsonAddress(json, ".LimitOrderProtocol");
        address feeToken = vm.parseJsonAddress(json, ".FeeToken"); 
        address accessToken = vm.parseJsonAddress(json, ".AccessToken");
        
        vm.startBroadcast(deployerPrivateKey);
        
        address deployer = vm.addr(deployerPrivateKey);
        console.log("Deployer:", deployer);
        console.log("Chain ID:", block.chainid);
        
        // Deploy the fixed factory
        bool deployTestFactory = vm.envBool("DEPLOY_TEST_FACTORY");
        address factory;
        
        if (deployTestFactory) {
            console.log("Deploying TestEscrowFactory (with CREATE2 fix)...");
            TestEscrowFactory testFactory = new TestEscrowFactory(
                limitOrderProtocol,
                IERC20(feeToken),
                IERC20(accessToken),
                deployer,
                86400, // 1 day rescue delay for source
                86400  // 1 day rescue delay for destination
            );
            factory = address(testFactory);
            console.log("TestEscrowFactory deployed at:", factory);
        } else {
            console.log("Deploying EscrowFactory (with CREATE2 fix)...");
            EscrowFactory regularFactory = new EscrowFactory(
                limitOrderProtocol,
                IERC20(feeToken),
                IERC20(accessToken),
                deployer,
                86400, // 1 day rescue delay for source
                86400  // 1 day rescue delay for destination
            );
            factory = address(regularFactory);
            console.log("EscrowFactory deployed at:", factory);
        }
        
        // Get implementation addresses
        address srcImpl = EscrowFactory(factory).ESCROW_SRC_IMPLEMENTATION();
        address dstImpl = EscrowFactory(factory).ESCROW_DST_IMPLEMENTATION();
        
        console.log("EscrowSrc implementation:", srcImpl);
        console.log("EscrowDst implementation:", dstImpl);
        
        vm.stopBroadcast();
        
        // Save to deployment file
        string memory factoryKey = deployTestFactory ? "TestEscrowFactoryFixed" : "EscrowFactoryFixed";
        vm.writeJson(vm.toString(factory), deploymentPath, string(abi.encodePacked(".", factoryKey)));
        vm.writeJson(vm.toString(srcImpl), deploymentPath, string(abi.encodePacked(".", factoryKey, "SrcImpl")));
        vm.writeJson(vm.toString(dstImpl), deploymentPath, string(abi.encodePacked(".", factoryKey, "DstImpl")));
        
        console.log("\nDeployment complete!");
        console.log("Updated deployment file:", deploymentPath);
    }
}