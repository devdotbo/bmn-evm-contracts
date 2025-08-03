// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { IBaseEscrow } from "../contracts/interfaces/IBaseEscrow.sol";
import { TimelocksLib, Timelocks } from "../contracts/libraries/TimelocksLib.sol";
import { AddressLib, Address } from "solidity-utils/contracts/libraries/AddressLib.sol";

/**
 * @title DeployMainnetFix
 * @notice Emergency fix to complete the stuck mainnet swap
 * @dev This script will help us complete the atomic swap that's stuck due to address mismatch
 */
contract DeployMainnetFix is Script {
    using TimelocksLib for Timelocks;
    using AddressLib for Address;
    
    // Known addresses from the current stuck swap
    address constant BMN_TOKEN = 0x8287CD2aC7E227D9D927F998EB600a0683a832A1;
    address constant SRC_ESCROW = 0xD36aAb77Ae4647F0085838c3a4a1eD08cD4e6B8A; // Base
    address constant DST_ESCROW = 0xBd0069d96c4bb6f7eE9352518CA5b4465b5Bc32A; // Etherlink
    
    // Known values
    bytes32 constant SECRET = 0x30dddfd090d174154369f259e749699d9656f53f28203c8063085b143c356bb5;
    bytes32 constant HASHLOCK = 0xf3be2ee03649fa7d2c8c61e7c10457198ed885ef8d44d13c97aef9bc0c5b394b;
    uint256 constant AMOUNT = 10 ether;
    uint256 constant SAFETY_DEPOSIT = 0.00001 ether;
    
    // Deployment timestamps from logs
    uint256 constant SRC_DEPLOY_TIME = 1754231199; // Base
    uint256 constant DST_DEPLOY_TIME = 1754231207; // Etherlink
    
    function run() external {
        string memory action = vm.envOr("ACTION", string(""));
        
        if (bytes(action).length == 0) {
            console.log("=== Mainnet Swap Recovery Tool ===");
            console.log("");
            console.log("Usage:");
            console.log("  ACTION=complete-dst forge script script/DeployMainnetFix.s.sol --rpc-url <ETHERLINK_RPC> --broadcast");
            console.log("  ACTION=complete-src forge script script/DeployMainnetFix.s.sol --rpc-url <BASE_RPC> --broadcast");
            console.log("  ACTION=check-status forge script script/DeployMainnetFix.s.sol --rpc-url <RPC>");
            return;
        }
        
        if (keccak256(bytes(action)) == keccak256(bytes("complete-dst"))) {
            completeDestinationWithdrawal();
        } else if (keccak256(bytes(action)) == keccak256(bytes("complete-src"))) {
            completeSourceWithdrawal();
        } else if (keccak256(bytes(action)) == keccak256(bytes("check-status"))) {
            checkStatus();
        }
    }
    
    function completeDestinationWithdrawal() internal {
        console.log("--- Completing Destination Withdrawal on Etherlink ---");
        
        // Get Alice's key
        uint256 aliceKey = vm.envUint("ALICE_PRIVATE_KEY");
        address alice = vm.addr(aliceKey);
        
        console.log("Alice address:", alice);
        console.log("Destination escrow:", DST_ESCROW);
        
        vm.startBroadcast(aliceKey);
        
        // Build immutables with exact deployment timestamp
        IBaseEscrow.Immutables memory immutables = IBaseEscrow.Immutables({
            orderHash: bytes32(0),
            hashlock: HASHLOCK,
            maker: Address.wrap(uint160(0xfdF1dDeB176BEA06c7430166e67E615bC312b7B5)), // Bob on dst
            taker: Address.wrap(uint160(alice)),
            token: Address.wrap(uint160(BMN_TOKEN)),
            amount: AMOUNT,
            safetyDeposit: SAFETY_DEPOSIT,
            timelocks: createTimelocks().setDeployedAt(DST_DEPLOY_TIME)
        });
        
        // Check balance before
        uint256 balanceBefore = IERC20(BMN_TOKEN).balanceOf(alice);
        console.log("Alice BMN balance before:", balanceBefore / 1e18);
        
        // Withdraw
        IBaseEscrow(DST_ESCROW).withdraw(SECRET, immutables);
        
        // Check balance after
        uint256 balanceAfter = IERC20(BMN_TOKEN).balanceOf(alice);
        console.log("Alice BMN balance after:", balanceAfter / 1e18);
        console.log("Alice received:", (balanceAfter - balanceBefore) / 1e18, "BMN");
        
        // Save revealed secret to state for source withdrawal
        string memory json = "state";
        vm.serializeBytes32(json, "revealedSecret", SECRET);
        vm.serializeUint(json, "dstWithdrawnAt", block.timestamp);
        string memory output = vm.serializeAddress(json, "dstWithdrawnTo", alice);
        vm.writeJson(output, "deployments/mainnet-recovery-state.json");
        
        vm.stopBroadcast();
        
        console.log("\n[SUCCESS] Destination withdrawal completed!");
        console.log("Secret revealed. Bob can now withdraw from source escrow on Base.");
    }
    
    function completeSourceWithdrawal() internal {
        console.log("--- Completing Source Withdrawal on Base ---");
        
        // Get Bob's key
        uint256 bobKey = vm.envUint("RESOLVER_PRIVATE_KEY");
        address bob = vm.addr(bobKey);
        
        console.log("Bob address:", bob);
        console.log("Source escrow:", SRC_ESCROW);
        console.log("Using secret:", vm.toString(SECRET));
        
        vm.startBroadcast(bobKey);
        
        // Build immutables with exact deployment timestamp
        IBaseEscrow.Immutables memory immutables = IBaseEscrow.Immutables({
            orderHash: bytes32(0),
            hashlock: HASHLOCK,
            maker: Address.wrap(uint160(0x240E2588e35FB9D3D60B283B45108a49972FFFd8)), // Alice on src
            taker: Address.wrap(uint160(bob)),
            token: Address.wrap(uint160(BMN_TOKEN)),
            amount: AMOUNT,
            safetyDeposit: SAFETY_DEPOSIT,
            timelocks: createTimelocks().setDeployedAt(SRC_DEPLOY_TIME)
        });
        
        // Check balance before
        uint256 balanceBefore = IERC20(BMN_TOKEN).balanceOf(bob);
        console.log("Bob BMN balance before:", balanceBefore / 1e18);
        
        // Withdraw
        IBaseEscrow(SRC_ESCROW).withdraw(SECRET, immutables);
        
        // Check balance after  
        uint256 balanceAfter = IERC20(BMN_TOKEN).balanceOf(bob);
        console.log("Bob BMN balance after:", balanceAfter / 1e18);
        console.log("Bob received:", (balanceAfter - balanceBefore) / 1e18, "BMN");
        
        vm.stopBroadcast();
        
        console.log("\n[SUCCESS] Source withdrawal completed!");
        console.log("Atomic swap completed successfully.");
    }
    
    function checkStatus() internal view {
        console.log("=== Swap Status Check ===");
        console.log("");
        
        console.log("Source Escrow (Base):", SRC_ESCROW);
        console.log("  Deployed at timestamp:", SRC_DEPLOY_TIME);
        console.log("  Current time:", block.timestamp);
        console.log("  Time elapsed:", block.timestamp - SRC_DEPLOY_TIME, "seconds");
        
        // Check if we're on Base or Etherlink
        uint256 chainId = block.chainid;
        if (chainId == 8453) {
            // Base
            uint256 srcBalance = IERC20(BMN_TOKEN).balanceOf(SRC_ESCROW);
            console.log("  BMN Balance:", srcBalance / 1e18);
            console.log("  Status:", srcBalance > 0 ? "LOCKED" : "WITHDRAWN/EMPTY");
        } else if (chainId == 42793) {
            // Etherlink
            console.log("\nDestination Escrow (Etherlink):", DST_ESCROW);
            console.log("  Deployed at timestamp:", DST_DEPLOY_TIME);
            uint256 dstBalance = IERC20(BMN_TOKEN).balanceOf(DST_ESCROW);
            console.log("  BMN Balance:", dstBalance / 1e18);
            console.log("  Status:", dstBalance > 0 ? "LOCKED" : "WITHDRAWN/EMPTY");
        }
        
        // Calculate timelock windows
        Timelocks timelocks = createTimelocks();
        console.log("\nTimelock Status (30-minute windows):");
        console.log("  Withdrawal window: 0-30 minutes");
        console.log("  Cancellation window: 30+ minutes");
        
        uint256 elapsedSrc = block.timestamp - SRC_DEPLOY_TIME;
        if (elapsedSrc < 1800) {
            console.log("  [OK] Still in withdrawal window for", (1800 - elapsedSrc) / 60, "more minutes");
        } else {
            console.log("  [WARNING] In cancellation period since", (elapsedSrc - 1800) / 60, "minutes ago");
        }
    }
    
    function createTimelocks() internal pure returns (Timelocks) {
        // Extended 30-minute timelocks
        uint256 packed = 0;
        packed |= uint256(uint32(0));      // SRC_WITHDRAWAL_START
        packed |= uint256(uint32(600)) << 32;  // SRC_PUBLIC_WITHDRAWAL_START (10 min)
        packed |= uint256(uint32(1800)) << 64; // SRC_CANCELLATION_START (30 min)
        packed |= uint256(uint32(2100)) << 96; // SRC_PUBLIC_CANCELLATION_START (35 min)
        packed |= uint256(uint32(0)) << 128;   // DST_WITHDRAWAL_START
        packed |= uint256(uint32(600)) << 160; // DST_PUBLIC_WITHDRAWAL_START (10 min)
        packed |= uint256(uint32(1800)) << 192; // DST_CANCELLATION_START (30 min)
        
        return Timelocks.wrap(packed);
    }
}