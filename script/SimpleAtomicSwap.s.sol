// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import "../contracts/SimplifiedEscrowFactory.sol";
import "../contracts/interfaces/IBaseEscrow.sol";
import "../contracts/libraries/ImmutablesLib.sol";
import "../contracts/libraries/TimelocksLib.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { Address } from "solidity-utils/contracts/libraries/AddressLib.sol";

contract SimpleAtomicSwap is Script {
    using ImmutablesLib for IBaseEscrow.Immutables;
    
    // Contracts
    address constant BMN_TOKEN = 0x8287CD2aC7E227D9D927F998EB600a0683a832A1;
    address constant BASE_FACTORY = 0xd599b1543467433F5A6f195Ccc4E01FcbF5AA157;
    address constant OPTIMISM_FACTORY = 0xA6342E61d1a0897A31a1ABAFB4B1669C0A5eaa56;
    
    // Accounts
    address constant ALICE = 0xBC3FCC00aa973FF47a967e387c1B1E7654D8F07E;
    address constant RESOLVER = 0xc18c3C96E20FaD1c656a5c4ed2F4f7871BD42be1;
    
    // Swap amount: 100 BMN tokens
    uint256 constant SWAP_AMOUNT = 100 * 1e18;
    
    // Secret for hashlock
    bytes32 constant SECRET = keccak256("BMN_ATOMIC_SWAP_2025");
    bytes32 constant HASHLOCK = keccak256(abi.encode(SECRET));
    
    function run() external {
        console.log("\n============================================");
        console.log("       BMN ATOMIC SWAP DEMONSTRATION");
        console.log("============================================\n");
        
        console.log("Testing atomic swap between Base and Optimism");
        console.log("Alice (Base): %s", ALICE);
        console.log("Resolver (Optimism): %s", RESOLVER);
        console.log("Amount: 100 BMN tokens\n");
        
        // Get private keys
        uint256 aliceKey = vm.envUint("ALICE_PRIVATE_KEY");
        uint256 resolverKey = vm.envUint("RESOLVER_PRIVATE_KEY");
        
        // Create timelocks
        uint256 packedTimelocks = 
            (3600) |           // srcWithdrawal: 1 hour
            (7200 << 32) |     // srcPublicWithdrawal: 2 hours
            (10800 << 64) |    // srcCancellation: 3 hours
            (14400 << 96) |    // srcPublicCancellation: 4 hours
            (3600 << 128) |    // dstWithdrawal: 1 hour
            (7200 << 160) |    // dstPublicWithdrawal: 2 hours
            (10800 << 192);    // dstCancellation: 3 hours
        
        // Create escrow parameters
        IBaseEscrow.Immutables memory immutables = IBaseEscrow.Immutables({
            orderHash: keccak256("BMN_ATOMIC_SWAP_ORDER_001"),
            hashlock: HASHLOCK,
            maker: Address.wrap(uint160(ALICE)),
            taker: Address.wrap(uint160(RESOLVER)),
            token: Address.wrap(uint160(BMN_TOKEN)),
            amount: SWAP_AMOUNT,
            safetyDeposit: 0,
            timelocks: Timelocks.wrap(packedTimelocks)
        });
        
        // Step 1: Check initial balances
        console.log("=== INITIAL BALANCES ===");
        vm.createSelectFork("https://base.rpc.thirdweb.com");
        checkBalances();
        
        // Step 2: Create source escrow on Base
        console.log("\n=== CREATING SOURCE ESCROW ON BASE ===");
        vm.createSelectFork("https://base.rpc.thirdweb.com");
        // Note: In the real deployment, Alice has the tokens, not the script runner
        // For demo purposes, we're using the funded account
        vm.startBroadcast(aliceKey);
        
        IERC20(BMN_TOKEN).approve(BASE_FACTORY, SWAP_AMOUNT);
        SimplifiedEscrowFactory baseFactory = SimplifiedEscrowFactory(BASE_FACTORY);
        address srcEscrow = baseFactory.createSrcEscrow(immutables, ALICE, BMN_TOKEN, SWAP_AMOUNT);
        
        console.log("Source escrow created at: %s", srcEscrow);
        vm.stopBroadcast();
        
        // Step 3: Create destination escrow on Optimism
        console.log("\n=== CREATING DESTINATION ESCROW ON OPTIMISM ===");
        vm.createSelectFork("https://mainnet.optimism.io");
        vm.startBroadcast(resolverKey);
        
        IERC20(BMN_TOKEN).approve(OPTIMISM_FACTORY, SWAP_AMOUNT);
        SimplifiedEscrowFactory optimismFactory = SimplifiedEscrowFactory(OPTIMISM_FACTORY);
        address dstEscrow = optimismFactory.createDstEscrow(immutables);
        
        console.log("Destination escrow created at: %s", dstEscrow);
        vm.stopBroadcast();
        
        // Step 4: Check final state
        console.log("\n=== ESCROWS CREATED SUCCESSFULLY ===");
        console.log("Both escrows are now locked with the same hashlock");
        console.log("Next steps (to be executed manually):");
        console.log("1. Alice reveals secret on Optimism to withdraw");
        console.log("2. Resolver uses revealed secret on Base to withdraw");
        console.log("3. Atomic swap completes!");
        
        // Final balances
        console.log("\n=== FINAL BALANCES (after escrow creation) ===");
        checkBalances();
    }
    
    function checkBalances() internal view {
        // Check Base balances
        uint256 aliceBase = IERC20(BMN_TOKEN).balanceOf(ALICE);
        uint256 resolverBase = IERC20(BMN_TOKEN).balanceOf(RESOLVER);
        
        console.log("Alice:");
        console.log("  Base: %s BMN", aliceBase / 1e18);
        console.log("Resolver:");
        console.log("  Base: %s BMN", resolverBase / 1e18);
    }
}