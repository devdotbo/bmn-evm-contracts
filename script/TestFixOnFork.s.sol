// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { TestEscrowFactory } from "../contracts/test/TestEscrowFactory.sol";
import { IBaseEscrow } from "../contracts/interfaces/IBaseEscrow.sol";
import { EscrowDst } from "../contracts/EscrowDst.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Timelocks, TimelocksLib } from "../contracts/libraries/TimelocksLib.sol";
import { Address, AddressLib } from "solidity-utils/contracts/libraries/AddressLib.sol";
import { ImmutablesLib } from "../contracts/libraries/ImmutablesLib.sol";

contract TestFixOnFork is Script {
    using TimelocksLib for Timelocks;
    using AddressLib for Address;
    using ImmutablesLib for IBaseEscrow.Immutables;
    
    // Test configuration
    uint256 constant SWAP_AMOUNT = 10 ether;
    uint256 constant SAFETY_DEPOSIT = 0.0001 ether;
    
    // Timelock configuration (same as mainnet test)
    uint32 constant SRC_WITHDRAWAL_START = 0;
    uint32 constant SRC_PUBLIC_WITHDRAWAL_START = 300;
    uint32 constant SRC_CANCELLATION_START = 0;
    uint32 constant SRC_PUBLIC_CANCELLATION_START = 1200;
    uint32 constant DST_WITHDRAWAL_START = 900;
    uint32 constant DST_PUBLIC_WITHDRAWAL_START = 300;
    uint32 constant DST_CANCELLATION_START = 0;
    
    function createTimelocks() internal pure returns (Timelocks) {
        uint256 packed = 0;
        
        packed |= uint256(uint32(SRC_WITHDRAWAL_START));
        packed |= uint256(uint32(SRC_PUBLIC_WITHDRAWAL_START)) << 32;
        packed |= uint256(uint32(SRC_CANCELLATION_START)) << 64;
        packed |= uint256(uint32(SRC_PUBLIC_CANCELLATION_START)) << 96;
        packed |= uint256(uint32(DST_WITHDRAWAL_START)) << 128;
        packed |= uint256(uint32(DST_PUBLIC_WITHDRAWAL_START)) << 160;
        packed |= uint256(uint32(DST_CANCELLATION_START)) << 192;
        
        return Timelocks.wrap(packed);
    }
    
    function run() external {
        // Fork from mainnet at current block
        uint256 forkId = vm.createFork(vm.envString("CHAIN_B_RPC_URL"));
        vm.selectFork(forkId);
        
        console.log("Testing CREATE2 fix on Etherlink mainnet fork...");
        console.log("Block number:", block.number);
        
        // Load existing deployment
        string memory deploymentPath = "deployments/etherlinkMainnetTest.json";
        string memory json = vm.readFile(deploymentPath);
        
        address oldFactory = vm.parseJsonAddress(json, ".TestEscrowFactory");
        address tokenB = vm.parseJsonAddress(json, ".TokenB");
        
        console.log("\nExisting factory:", oldFactory);
        console.log("Token B:", tokenB);
        
        // Deploy new factory with the fix
        uint256 deployerKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);
        
        vm.startBroadcast(deployerKey);
        
        TestEscrowFactory newFactory = new TestEscrowFactory(
            address(0), // No limit order protocol needed for test
            IERC20(tokenB), // Use token as fee token
            IERC20(tokenB), // Use token as access token
            deployer,
            86400, // 1 day rescue delay
            86400
        );
        
        console.log("\nNew factory with fix deployed at:", address(newFactory));
        
        vm.stopBroadcast();
        
        // Now test the fix
        console.log("\n=== Testing Address Prediction ===");
        
        // Create test immutables
        bytes32 hashlock = keccak256("test_secret");
        IBaseEscrow.Immutables memory immutables = IBaseEscrow.Immutables({
            orderHash: bytes32(0),
            hashlock: hashlock,
            maker: Address.wrap(uint160(deployer)),
            taker: Address.wrap(uint160(0x240E2588e35FB9D3D60B283B45108a49972FFFd8)),
            token: Address.wrap(uint160(tokenB)),
            amount: SWAP_AMOUNT,
            safetyDeposit: SAFETY_DEPOSIT,
            timelocks: createTimelocks()
        });
        
        // Get predicted address
        address predictedDst = newFactory.addressOfEscrowDst(immutables);
        console.log("Predicted destination escrow:", predictedDst);
        
        // Deploy escrow
        vm.startBroadcast(deployerKey);
        
        // Fund the factory with tokens
        vm.prank(0x240E2588e35FB9D3D60B283B45108a49972FFFd8); // Bob has tokens
        IERC20(tokenB).transfer(address(newFactory), SWAP_AMOUNT);
        
        // Deploy destination escrow
        address deployedDst = newFactory.createDstEscrow{value: SAFETY_DEPOSIT}(immutables);
        console.log("Actually deployed escrow:", deployedDst);
        
        vm.stopBroadcast();
        
        // Check if they match
        if (predictedDst == deployedDst) {
            console.log("\n✅ SUCCESS! Address prediction matches deployment!");
            console.log("The CREATE2 fix works correctly.");
            
            // Test withdraw to ensure escrow validation works
            console.log("\n=== Testing Withdraw ===");
            
            vm.startBroadcast(deployerKey);
            
            // Set the correct timelocks with deployment timestamp
            immutables.timelocks = immutables.timelocks.setDeployedAt(block.timestamp);
            
            try EscrowDst(deployedDst).withdraw(bytes32("test_secret"), immutables) {
                console.log("✅ Withdraw successful! The fix is complete!");
            } catch Error(string memory reason) {
                console.log("❌ Withdraw failed:", reason);
            }
            
            vm.stopBroadcast();
        } else {
            console.log("\n❌ FAILED! Address mismatch!");
            console.log("Expected:", predictedDst);
            console.log("Got:", deployedDst);
        }
    }
}