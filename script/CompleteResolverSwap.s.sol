// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { CrossChainResolverV2 } from "../contracts/CrossChainResolverV2.sol";
import { Timelocks, TimelocksLib } from "../contracts/libraries/TimelocksLib.sol";

contract CompleteResolverSwap is Script {
    using TimelocksLib for Timelocks;

    // Deployed addresses
    address constant BASE_RESOLVER = 0xeaee1Fd7a1Fe2BC10f83391Df456Fe841602bc77;
    address constant ETHERLINK_RESOLVER = 0x3bCACdBEC5DdF9Ec29da0E04a7d846845396A354;
    address constant BMN_TOKEN = 0x8287CD2aC7E227D9D927F998EB600a0683a832A1;
    
    uint256 constant SWAP_AMOUNT = 10 ether;
    uint256 constant SAFETY_DEPOSIT = 0.001 ether;
    
    function run() external {
        // Get swap details from environment
        bytes32 swapId = vm.envBytes32("SWAP_ID");
        bytes32 secret = vm.envBytes32("SECRET");
        bytes32 hashlock = vm.envBytes32("HASHLOCK");
        
        // For testing, we use deployer as resolver since they own the contract
        uint256 resolverKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address resolver = vm.addr(resolverKey);
        
        // Bob is the taker in our test
        address bob = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;
        
        uint256 aliceKey = vm.envUint("ALICE_PRIVATE_KEY");
        address alice = vm.addr(aliceKey);
        
        console.log("=== Completing Cross-Chain Swap ===");
        console.log("Swap ID:");
        console.logBytes32(swapId);
        console.log("Alice:", alice);
        console.log("Bob (Taker):", bob);
        console.log("Resolver (Owner):", resolver);
        
        uint256 chainId = block.chainid;
        
        if (chainId == 42793) {
            // On Etherlink - create destination escrow
            createDestinationEscrow(resolverKey, swapId, secret, hashlock, alice, bob);
        } else if (chainId == 8453) {
            // On Base - withdraw from source (Alice)
            withdrawSource(aliceKey, swapId, secret);
        }
    }
    
    function createDestinationEscrow(
        uint256 resolverKey,
        bytes32 swapId,
        bytes32 secret,
        bytes32 hashlock,
        address alice,
        address bob
    ) internal {
        console.log("\n=== Creating Destination Escrow on Etherlink ===");
        
        CrossChainResolverV2 resolver = CrossChainResolverV2(ETHERLINK_RESOLVER);
        IERC20 bmn = IERC20(BMN_TOKEN);
        
        // Create same timelocks as source
        uint256 packed = 0;
        packed |= uint256(uint32(0));           // srcWithdrawal
        packed |= uint256(uint32(600)) << 32;   // srcPublicWithdrawal
        packed |= uint256(uint32(1800)) << 64;  // srcCancellation
        packed |= uint256(uint32(2100)) << 96;  // srcPublicCancellation
        packed |= uint256(uint32(0)) << 128;    // dstWithdrawal
        packed |= uint256(uint32(600)) << 160;  // dstPublicWithdrawal
        packed |= uint256(uint32(1200)) << 192; // dstCancellation
        
        Timelocks timelocks = Timelocks.wrap(packed);
        
        vm.startBroadcast(resolverKey);
        
        // Check resolver's balance
        uint256 resolverBalance = bmn.balanceOf(vm.addr(resolverKey));
        console.log("Resolver BMN balance:", resolverBalance / 1e18, "tokens");
        
        if (resolverBalance < SWAP_AMOUNT) {
            console.log("ERROR: Resolver needs at least", SWAP_AMOUNT / 1e18, "BMN tokens on Etherlink");
            vm.stopBroadcast();
            return;
        }
        
        // Approve resolver
        console.log("Approving resolver for", SWAP_AMOUNT / 1e18, "BMN...");
        bmn.approve(address(resolver), SWAP_AMOUNT);
        
        // Create destination escrow
        // Note: In production, srcTimestamp would come from monitoring the source chain event
        uint256 srcTimestamp = block.timestamp - 60; // Assume it was created 1 minute ago
        
        console.log("Creating destination escrow...");
        resolver.createDestinationEscrow{value: SAFETY_DEPOSIT}(
            swapId,
            alice,    // maker on source
            bob,      // taker on source (becomes maker on dst)
            address(bmn),
            SWAP_AMOUNT,
            hashlock,
            timelocks,
            srcTimestamp
        );
        
        console.log("Destination escrow created!");
        
        // Get the actual escrow address from the event/logs
        address actualDstEscrow = 0x48f8440ed56d856C65e339843354658259566191;
        console.log("Actual destination escrow:", actualDstEscrow);
        
        // Update swap data with actual escrow
        (CrossChainResolverV2.SwapData memory swapData) = resolver.swaps(swapId);
        console.log("Stored dst escrow:", swapData.dstEscrow);
        
        // Now withdraw to reveal the secret
        console.log("\nWithdrawing from destination escrow...");
        // Since Bob is now the deployer, we withdraw as the maker on destination
        resolver.withdraw(swapId, secret, false); // false = destination
        
        console.log("Secret revealed! Alice can now withdraw on Base.");
        
        vm.stopBroadcast();
    }
    
    function withdrawSource(uint256 aliceKey, bytes32 swapId, bytes32 secret) internal {
        console.log("\n=== Withdrawing from Source Escrow on Base ===");
        
        CrossChainResolverV2 resolver = CrossChainResolverV2(BASE_RESOLVER);
        
        vm.startBroadcast(aliceKey);
        
        console.log("Alice withdrawing with revealed secret...");
        resolver.withdraw(swapId, secret, true); // true = source
        
        console.log("Withdrawal complete! Swap successful!");
        
        vm.stopBroadcast();
    }
}