// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import "../contracts/CrossChainResolverV2.sol";
import { TokenMock } from "solidity-utils/contracts/mocks/TokenMock.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { TimelocksLib, Timelocks } from "../contracts/libraries/TimelocksLib.sol";

contract TestCrossChainResolver is Script {
    using TimelocksLib for Timelocks;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        // Load resolver address from environment or command line
        address resolverAddress = vm.envAddress("RESOLVER_ADDRESS");
        CrossChainResolverV2 resolver = CrossChainResolverV2(resolverAddress);
        
        console.log("Testing CrossChainResolver at:", resolverAddress);
        console.log("Chain ID:", block.chainid);
        console.log("Deployer:", deployer);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy a test token if needed
        address tokenAddress = vm.envOr("TEST_TOKEN", address(0));
        if (tokenAddress == address(0)) {
            TokenMock testToken = new TokenMock("Test Token", "TEST");
            tokenAddress = address(testToken);
            console.log("Deployed test token at:", tokenAddress);
            
            // Mint tokens to deployer
            testToken.mint(deployer, 1000 * 10**18);
            console.log("Minted 1000 TEST tokens to deployer");
        }
        
        IERC20 token = IERC20(tokenAddress);
        
        // Test parameters
        bytes32 secret = bytes32(uint256(12345));
        bytes32 hashlock = keccak256(abi.encodePacked(secret));
        address taker = vm.envOr("TAKER_ADDRESS", address(0x1234567890123456789012345678901234567890));
        uint256 amount = 10 * 10**18; // 10 tokens
        uint256 dstChainId = block.chainid == 8453 ? 42793 : 8453; // Swap between Base and Etherlink
        
        // Create timelocks (1 hour for each stage)
        uint256 packed = 0;
        packed |= uint256(uint32(300));    // srcWithdrawal: 5 minutes
        packed |= uint256(uint32(600)) << 32;    // srcPublicWithdrawal: 10 minutes
        packed |= uint256(uint32(900)) << 64;    // srcCancellation: 15 minutes
        packed |= uint256(uint32(1200)) << 96;   // srcPublicCancellation: 20 minutes
        packed |= uint256(uint32(300)) << 128;   // dstWithdrawal: 5 minutes
        packed |= uint256(uint32(600)) << 160;   // dstPublicWithdrawal: 10 minutes
        packed |= uint256(uint32(900)) << 192;   // dstCancellation: 15 minutes
        
        Timelocks timelocks = Timelocks.wrap(packed);
        
        console.log("\n=== Test Parameters ===");
        console.log("Token:", tokenAddress);
        console.log("Amount:", amount / 10**18, "tokens");
        console.log("Maker:", deployer);
        console.log("Taker:", taker);
        console.log("Secret:", uint256(secret));
        console.log("Hashlock:", uint256(hashlock));
        console.log("Destination Chain:", dstChainId);
        
        // Approve resolver to spend tokens
        console.log("\nApproving resolver to spend tokens...");
        token.approve(address(resolver), amount);
        
        // Initiate swap
        console.log("\nInitiating swap...");
        uint256 safetyDeposit = 0.01 ether;
        
        (bytes32 swapId, address srcEscrow) = resolver.initiateSwap{value: safetyDeposit}(
            hashlock,
            taker,
            tokenAddress,
            amount,
            dstChainId,
            timelocks
        );
        
        console.log("\n=== Swap Created ===");
        console.log("Swap ID:", uint256(swapId));
        console.log("Source Escrow:", srcEscrow);
        
        // Get swap details
        CrossChainResolverV2.SwapData memory swap = resolver.getSwap(swapId);
        console.log("\n=== Swap Details ===");
        console.log("Maker:", swap.maker);
        console.log("Taker:", swap.taker);
        console.log("Amount:", swap.amount);
        console.log("Source Chain:", swap.srcChainId);
        console.log("Destination Chain:", swap.dstChainId);
        console.log("Source Escrow:", swap.srcEscrow);
        
        vm.stopBroadcast();
        
        console.log("\n=== Next Steps ===");
        console.log("1. On destination chain, call createDestinationEscrow() with:");
        console.log("   - Swap ID:", uint256(swapId));
        console.log("   - Maker:", deployer);
        console.log("   - Taker:", taker);
        console.log("   - Amount:", amount);
        console.log("   - Hashlock:", uint256(hashlock));
        console.log("   - Source Timestamp:", block.timestamp);
        console.log("\n2. After destination escrow is created, reveal secret to withdraw");
        console.log("   - Secret:", uint256(secret));
    }
}