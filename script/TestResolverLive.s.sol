// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { CrossChainResolverV2 } from "../contracts/CrossChainResolverV2.sol";
import { Timelocks, TimelocksLib } from "../contracts/libraries/TimelocksLib.sol";

contract TestResolverLive is Script {
    using TimelocksLib for Timelocks;

    // Deployed addresses from HACKATHON-DEPLOYMENT-RESULTS.md
    address constant BASE_RESOLVER = 0xeaee1Fd7a1Fe2BC10f83391Df456Fe841602bc77;
    address constant ETHERLINK_RESOLVER = 0x3bCACdBEC5DdF9Ec29da0E04a7d846845396A354;
    address constant BMN_TOKEN = 0x9C32618CeeC96b9DC0b7c0976c4b4cf2Ee452988;
    
    uint256 constant SWAP_AMOUNT = 10 ether;
    uint256 constant SAFETY_DEPOSIT = 0.001 ether;
    
    function run() external {
        uint256 aliceKey = vm.envUint("ALICE_PRIVATE_KEY");
        address alice = vm.addr(aliceKey);
        address bob = vm.envAddress("BOB_ADDRESS");
        
        console.log("=== Testing CrossChainResolverV2 ===");
        console.log("Alice:", alice);
        console.log("Bob:", bob);
        
        // Generate secret and hashlock
        bytes32 secret = keccak256(abi.encodePacked("hackathon-test-", block.timestamp));
        bytes32 hashlock = keccak256(abi.encodePacked(secret));
        
        console.log("Secret:", vm.toString(secret));
        console.log("Hashlock:", vm.toString(hashlock));
        
        // Create timelocks (30 minute test window)
        Timelocks timelocks = TimelocksLib.encode({
            srcWithdrawal: 0,
            srcPublicWithdrawal: 600,       // 10 minutes
            srcCancellation: 1800,           // 30 minutes  
            srcPublicCancellation: 2100,     // 35 minutes
            dstWithdrawal: 0,
            dstPublicWithdrawal: 600,       // 10 minutes
            dstCancellation: 1200           // 20 minutes
        });
        
        // Check which chain we're on
        uint256 chainId = block.chainid;
        if (chainId == 8453) {
            console.log("\nInitiating swap on Base...");
            testInitiateSwap(aliceKey, alice, bob, hashlock, timelocks);
        } else if (chainId == 42793) {
            console.log("\nTesting on Etherlink - use Base to initiate");
            console.log("Run this script with --rpc-url $BASE_RPC_URL first");
        } else {
            revert("Unsupported chain");
        }
    }
    
    function testInitiateSwap(
        uint256 aliceKey,
        address alice,
        address bob,
        bytes32 hashlock,
        Timelocks timelocks
    ) internal {
        CrossChainResolverV2 resolver = CrossChainResolverV2(BASE_RESOLVER);
        IERC20 bmn = IERC20(BMN_TOKEN);
        
        vm.startBroadcast(aliceKey);
        
        // Check balances
        uint256 aliceBalance = bmn.balanceOf(alice);
        uint256 resolverBalance = bmn.balanceOf(address(resolver));
        
        console.log("\nBalances:");
        console.log("Alice BMN:", aliceBalance / 1e18, "tokens");
        console.log("Resolver BMN:", resolverBalance / 1e18, "tokens");
        
        if (aliceBalance < SWAP_AMOUNT) {
            console.log("ERROR: Alice needs at least", SWAP_AMOUNT / 1e18, "BMN tokens");
            vm.stopBroadcast();
            return;
        }
        
        // Approve resolver
        console.log("\nApproving resolver for", SWAP_AMOUNT / 1e18, "BMN...");
        bmn.approve(address(resolver), SWAP_AMOUNT);
        
        // Initiate swap
        console.log("\nInitiating swap...");
        bytes32 swapId = resolver.initiateSwap{value: SAFETY_DEPOSIT}(
            hashlock,
            bob,
            address(bmn),
            SWAP_AMOUNT,
            42793, // Etherlink chain ID
            timelocks
        );
        
        console.log("Swap initiated!");
        console.log("Swap ID:", vm.toString(swapId));
        
        vm.stopBroadcast();
        
        console.log("\n=== Next Steps ===");
        console.log("1. Monitor SwapInitiated event on Base");
        console.log("2. Call createDestinationEscrow on Etherlink resolver");
        console.log("3. Use the secret to complete withdrawals");
        console.log("\nSecret for withdrawal:", vm.toString(secret));
    }
}