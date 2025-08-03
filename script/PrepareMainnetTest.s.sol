// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { TestEscrowFactory } from "../contracts/test/TestEscrowFactory.sol";
import { Constants } from "../contracts/Constants.sol";

/**
 * @title PrepareMainnetTest
 * @notice Deploys test infrastructure for mainnet cross-chain atomic swap testing
 * @dev Deploys:
 *      - TestEscrowFactory on both chains
 *      - Funds test accounts with ETH
 */
contract PrepareMainnetTest is Script {
    // Test configuration
    uint256 constant TEST_ETH = 0.005 ether; // For gas and safety deposits
    
    // Rescue delays
    uint32 constant RESCUE_DELAY = 86400; // 1 day
    
    function run() external {
        uint256 deployerKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);
        
        string memory action = vm.envString("ACTION");
        
        if (keccak256(bytes(action)) == keccak256(bytes("deploy-base"))) {
            deployBase(deployerKey);
        } else if (keccak256(bytes(action)) == keccak256(bytes("deploy-etherlink"))) {
            deployEtherlink(deployerKey);
        } else if (keccak256(bytes(action)) == keccak256(bytes("fund-accounts"))) {
            fundAccounts(deployerKey);
        } else if (keccak256(bytes(action)) == keccak256(bytes("check-setup"))) {
            checkSetup();
        } else {
            console.log("Usage:");
            console.log("  ACTION=deploy-base forge script script/PrepareMainnetTest.s.sol --rpc-url base --broadcast");
            console.log("  ACTION=deploy-etherlink forge script script/PrepareMainnetTest.s.sol --rpc-url etherlink --broadcast");
            console.log("  ACTION=fund-accounts forge script script/PrepareMainnetTest.s.sol --rpc-url <rpc> --broadcast");
            console.log("  ACTION=check-setup forge script script/PrepareMainnetTest.s.sol --rpc-url <rpc>");
        }
    }
    
    function deployBase(uint256 deployerKey) internal {
        console.log("=== Deploying on Base Mainnet ===");
        require(block.chainid == 8453, "Not on Base mainnet");
        
        vm.startBroadcast(deployerKey);
        
        // Deploy TestEscrowFactory
        TestEscrowFactory factory = new TestEscrowFactory(
            address(0), // No limit order protocol
            IERC20(address(0)), // No fee token
            IERC20(Constants.BMN_TOKEN), // BMN as access token
            vm.addr(deployerKey), // Owner
            RESCUE_DELAY,
            RESCUE_DELAY
        );
        console.log("TestEscrowFactory deployed at:", address(factory));
        console.log("  Src Implementation:", factory.ESCROW_SRC_IMPLEMENTATION());
        console.log("  Dst Implementation:", factory.ESCROW_DST_IMPLEMENTATION());
        
        // Save deployment
        string memory json = "deployment";
        vm.serializeUint(json, "chainId", block.chainid);
        vm.serializeAddress(json, "bmnToken", Constants.BMN_TOKEN);
        vm.serializeAddress(json, "factory", address(factory));
        vm.serializeAddress(json, "limitOrderProtocol", address(0));
        vm.serializeAddress(json, "accessToken", Constants.BMN_TOKEN);
        vm.serializeAddress(json, "feeToken", address(0));
        
        string memory accounts = "accounts";
        vm.serializeAddress(accounts, "alice", Constants.ALICE);
        vm.serializeAddress(accounts, "bob", Constants.BOB_RESOLVER);
        string memory accountsJson = vm.serializeAddress(accounts, "deployer", Constants.BMN_DEPLOYER);
        
        string memory contracts = "contracts";
        vm.serializeAddress(contracts, "factory", address(factory));
        vm.serializeAddress(contracts, "bmnToken", Constants.BMN_TOKEN);
        vm.serializeAddress(contracts, "limitOrderProtocol", address(0));
        vm.serializeAddress(contracts, "accessToken", Constants.BMN_TOKEN);
        string memory contractsJson = vm.serializeAddress(contracts, "feeToken", address(0));
        
        vm.serializeString(json, "accounts", accountsJson);
        vm.serializeString(json, "contracts", contractsJson);
        string memory finalJson = vm.serializeUint(json, "timestamp", block.timestamp);
        
        vm.writeJson(finalJson, "deployments/baseMainnetTest.json");
        
        vm.stopBroadcast();
    }
    
    function deployEtherlink(uint256 deployerKey) internal {
        console.log("=== Deploying on Etherlink Mainnet ===");
        require(block.chainid == 42793, "Not on Etherlink mainnet");
        
        vm.startBroadcast(deployerKey);
        
        // Deploy TestEscrowFactory
        TestEscrowFactory factory = new TestEscrowFactory(
            address(0), // No limit order protocol
            IERC20(address(0)), // No fee token
            IERC20(Constants.BMN_TOKEN), // BMN as access token
            vm.addr(deployerKey), // Owner
            RESCUE_DELAY,
            RESCUE_DELAY
        );
        console.log("TestEscrowFactory deployed at:", address(factory));
        console.log("  Src Implementation:", factory.ESCROW_SRC_IMPLEMENTATION());
        console.log("  Dst Implementation:", factory.ESCROW_DST_IMPLEMENTATION());
        
        // Save deployment
        string memory json = "deployment";
        vm.serializeUint(json, "chainId", block.chainid);
        vm.serializeAddress(json, "bmnToken", Constants.BMN_TOKEN);
        vm.serializeAddress(json, "factory", address(factory));
        vm.serializeAddress(json, "limitOrderProtocol", address(0));
        vm.serializeAddress(json, "accessToken", Constants.BMN_TOKEN);
        vm.serializeAddress(json, "feeToken", address(0));
        
        string memory accounts = "accounts";
        vm.serializeAddress(accounts, "alice", Constants.ALICE);
        vm.serializeAddress(accounts, "bob", Constants.BOB_RESOLVER);
        string memory accountsJson = vm.serializeAddress(accounts, "deployer", Constants.BMN_DEPLOYER);
        
        string memory contracts = "contracts";
        vm.serializeAddress(contracts, "factory", address(factory));
        vm.serializeAddress(contracts, "bmnToken", Constants.BMN_TOKEN);
        vm.serializeAddress(contracts, "limitOrderProtocol", address(0));
        vm.serializeAddress(contracts, "accessToken", Constants.BMN_TOKEN);
        string memory contractsJson = vm.serializeAddress(contracts, "feeToken", address(0));
        
        vm.serializeString(json, "accounts", accountsJson);
        vm.serializeString(json, "contracts", contractsJson);
        string memory finalJson = vm.serializeUint(json, "timestamp", block.timestamp);
        
        vm.writeJson(finalJson, "deployments/etherlinkMainnetTest.json");
        
        vm.stopBroadcast();
    }
    
    function fundAccounts(uint256 deployerKey) internal {
        console.log("=== Funding Test Accounts ===");
        
        address deployer = vm.addr(deployerKey);
        
        vm.startBroadcast(deployerKey);
        
        // Fund Alice and Bob with ETH for gas
        if (Constants.ALICE.balance < TEST_ETH) {
            payable(Constants.ALICE).transfer(TEST_ETH);
            console.log("Sent", TEST_ETH, "wei ETH to Alice");
        }
        
        if (Constants.BOB_RESOLVER.balance < TEST_ETH) {
            payable(Constants.BOB_RESOLVER).transfer(TEST_ETH);
            console.log("Sent", TEST_ETH, "wei ETH to Bob");
        }
        
        // Transfer BMN tokens for access control (only on Base for now)
        if (block.chainid == 8453) {
            IERC20 bmn = IERC20(Constants.BMN_TOKEN);
            uint256 aliceBMN = bmn.balanceOf(Constants.ALICE);
            uint256 bobBMN = bmn.balanceOf(Constants.BOB_RESOLVER);
            
            if (aliceBMN < 10 ether) {
                bmn.transfer(Constants.ALICE, 10 ether);
                console.log("Sent 10 BMN to Alice");
            }
            
            if (bobBMN < 10 ether) {
                bmn.transfer(Constants.BOB_RESOLVER, 10 ether);
                console.log("Sent 10 BMN to Bob");
            }
        } else {
            console.log("BMN token transfer skipped on non-Base chains");
        }
        
        vm.stopBroadcast();
    }
    
    function checkSetup() internal view {
        console.log("=== Checking Mainnet Test Setup ===");
        console.log("");
        
        uint256 chainId = block.chainid;
        string memory chainName = chainId == 8453 ? "Base" : chainId == 42793 ? "Etherlink" : "Unknown";
        
        console.log("Current chain:", chainName);
        console.log("Chain ID:", chainId);
        console.log("");
        
        // Check ETH balances
        console.log("ETH Balances:");
        console.log("  Alice:", Constants.ALICE.balance, "wei");
        console.log("  Bob:", Constants.BOB_RESOLVER.balance, "wei");
        console.log("");
        
        // Check BMN balances
        IERC20 bmn = IERC20(Constants.BMN_TOKEN);
        console.log("BMN Token Balances:");
        console.log("  Alice:", bmn.balanceOf(Constants.ALICE), "wei BMN");
        console.log("  Bob:", bmn.balanceOf(Constants.BOB_RESOLVER), "wei BMN");
        console.log("");
        
        // Try to load deployment files
        if (chainId == 8453) {
            try vm.readFile("deployments/baseMainnetTest.json") returns (string memory json) {
                address factory = vm.parseJsonAddress(json, ".contracts.factory");
                
                console.log("Base Deployment:");
                console.log("  Factory:", factory);
                console.log("  BMN Token:", Constants.BMN_TOKEN);
            } catch {
                console.log("[WARNING] Base deployment file not found");
            }
        } else if (chainId == 42793) {
            try vm.readFile("deployments/etherlinkMainnetTest.json") returns (string memory json) {
                address factory = vm.parseJsonAddress(json, ".contracts.factory");
                
                console.log("Etherlink Deployment:");
                console.log("  Factory:", factory);
                console.log("  BMN Token:", Constants.BMN_TOKEN);
            } catch {
                console.log("[WARNING] Etherlink deployment file not found");
            }
        }
        
        console.log("");
        console.log("Safety deposit amount: 0.00001 ETH (~$0.03-0.04)");
        console.log("Test swap amount: 10 tokens");
    }
}