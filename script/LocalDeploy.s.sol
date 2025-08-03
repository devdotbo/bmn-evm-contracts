// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import "../contracts/test/TestEscrowFactory.sol";
import "../contracts/EscrowSrc.sol";
import "../contracts/EscrowDst.sol";
import { TokenMock } from "solidity-utils/contracts/mocks/TokenMock.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

/**
 * @title LocalDeploy
 * @notice Deployment script for local development using TestEscrowFactory
 * @dev This script deploys test tokens and factory for local Anvil chains
 */
contract LocalDeploy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("=== Local Development Deployment ===");
        console.log("Deployer:", deployer);
        console.log("Chain ID:", block.chainid);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy mock tokens
        TokenMock tokenA = new TokenMock("Token A", "TKA");
        TokenMock tokenB = new TokenMock("Token B", "TKB");
        console.log("Token A deployed at:", address(tokenA));
        console.log("Token B deployed at:", address(tokenB));
        
        // Deploy mock contracts for factory dependencies
        address limitOrderProtocol = address(new TokenMock("Mock LOP", "LOP"));
        IERC20 feeToken = IERC20(address(new TokenMock("Fee Token", "FEE")));
        IERC20 accessToken = IERC20(address(new TokenMock("Access Token", "ACCESS")));
        
        console.log("Mock LOP:", limitOrderProtocol);
        console.log("Fee Token:", address(feeToken));
        console.log("Access Token:", address(accessToken));
        
        // Deploy escrow implementations
        EscrowSrc srcImpl = new EscrowSrc(86400, accessToken); // 1 day rescue delay
        EscrowDst dstImpl = new EscrowDst(86400); // 1 day rescue delay
        
        console.log("EscrowSrc implementation:", address(srcImpl));
        console.log("EscrowDst implementation:", address(dstImpl));
        
        // Deploy TestEscrowFactory
        TestEscrowFactory factory = new TestEscrowFactory(
            limitOrderProtocol,
            feeToken,
            accessToken,
            deployer, // owner
            86400,    // rescueDelaySrc: 1 day
            86400     // rescueDelayDst: 1 day
        );
        
        console.log("TestEscrowFactory deployed at:", address(factory));
        
        // Set implementations
        factory.setEscrowImplementations(address(srcImpl), address(dstImpl));
        console.log("Implementations set in factory");
        
        // Fund test accounts
        address alice = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8; // Anvil account 1
        address bob = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;   // Anvil account 2
        
        // Mint tokens to Alice and Bob
        tokenA.mint(alice, 1000 ether);
        tokenA.mint(bob, 500 ether);
        tokenB.mint(alice, 100 ether);
        tokenB.mint(bob, 1000 ether);
        
        console.log("\nTest accounts funded:");
        console.log("Alice TKA balance:", tokenA.balanceOf(alice) / 1e18);
        console.log("Alice TKB balance:", tokenB.balanceOf(alice) / 1e18);
        console.log("Bob TKA balance:", tokenA.balanceOf(bob) / 1e18);
        console.log("Bob TKB balance:", tokenB.balanceOf(bob) / 1e18);
        
        vm.stopBroadcast();
        
        // Save deployment info
        string memory chainIdStr = vm.toString(block.chainid);
        string memory deploymentInfo = string(abi.encodePacked(
            "CHAIN_ID=", chainIdStr, "\n",
            "FACTORY_ADDRESS=", vm.toString(address(factory)), "\n",
            "TOKEN_A=", vm.toString(address(tokenA)), "\n",
            "TOKEN_B=", vm.toString(address(tokenB)), "\n",
            "ESCROW_SRC_IMPL=", vm.toString(address(srcImpl)), "\n",
            "ESCROW_DST_IMPL=", vm.toString(address(dstImpl)), "\n",
            "ALICE=", vm.toString(alice), "\n",
            "BOB=", vm.toString(bob), "\n"
        ));
        
        string memory filename = string(abi.encodePacked(
            "deployments/local-",
            chainIdStr,
            ".env"
        ));
        
        vm.writeFile(filename, deploymentInfo);
        console.log("\nDeployment info saved to:", filename);
        console.log("\n=== Deployment Complete ===");
    }
}