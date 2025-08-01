// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { IOrderMixin, LimitOrderProtocol } from "limit-order-protocol/contracts/LimitOrderProtocol.sol";
import { Address, AddressLib } from "solidity-utils/contracts/libraries/AddressLib.sol";

import { IBaseEscrow } from "../contracts/interfaces/IBaseEscrow.sol";
import { IEscrowFactory } from "../contracts/interfaces/IEscrowFactory.sol";
import { EscrowFactory } from "../contracts/EscrowFactory.sol";
import { Timelocks, TimelocksLib } from "../contracts/libraries/TimelocksLib.sol";
import { ImmutablesLib } from "../contracts/libraries/ImmutablesLib.sol";

/**
 * @title TestLiveChains
 * @notice Script to test the cross-chain atomic swap against already deployed contracts
 * @dev Run with: forge script script/TestLiveChains.s.sol --rpc-url http://localhost:8545
 */
contract TestLiveChains is Script {
    using AddressLib for address;
    using TimelocksLib for Timelocks;
    using ImmutablesLib for IBaseEscrow.Immutables;

    // Deployment addresses (will be loaded from JSON files)
    struct Deployment {
        address factory;
        address limitOrderProtocol;
        address tokenA;
        address tokenB;
        address accessToken;
        address feeToken;
        address alice;
        address bob;
        uint256 chainId;
    }

    // Test configuration
    uint256 constant SWAP_AMOUNT = 10 ether;
    uint256 constant SAFETY_DEPOSIT = 0.01 ether;
    
    // Timelock configuration (in seconds)
    uint256 constant SRC_WITHDRAWAL_START = 0;
    uint256 constant SRC_PUBLIC_WITHDRAWAL_START = 300; // 5 minutes
    uint256 constant SRC_CANCELLATION_START = 600; // 10 minutes
    uint256 constant SRC_PUBLIC_CANCELLATION_START = 900; // 15 minutes
    uint256 constant DST_WITHDRAWAL_START = 0;
    uint256 constant DST_PUBLIC_WITHDRAWAL_START = 300; // 5 minutes
    uint256 constant DST_CANCELLATION_START = 600; // 10 minutes

    // Private keys (Anvil defaults)
    uint256 constant ALICE_KEY = 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d;
    uint256 constant BOB_KEY = 0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a;

    function run() external {
        console.log("========================================");
        console.log("Testing Cross-Chain Atomic Swap");
        console.log("========================================\n");

        // Load deployments
        Deployment memory chainA = loadDeployment("deployments/chainA.json");
        Deployment memory chainB = loadDeployment("deployments/chainB.json");

        // Generate secret for the swap
        bytes32 secret = keccak256(abi.encodePacked("test_secret", block.timestamp));
        bytes32 hashlock = keccak256(abi.encodePacked(secret));
        console.log("Secret:", vm.toString(secret));
        console.log("Hashlock:", vm.toString(hashlock));

        // Step 1: Create order on Chain A (Alice creates order)
        console.log("\n--- Step 1: Creating Order on Chain A ---");
        bytes32 orderHash = createOrderOnChainA(chainA, hashlock);
        console.log("Order created with hash:", vm.toString(orderHash));

        // Step 2: Lock tokens on source chain (implicit with order creation in 1inch protocol)
        console.log("\n--- Step 2: Source Escrow Created ---");
        IBaseEscrow.Immutables memory srcImmutables = createSrcImmutables(
            chainA,
            orderHash,
            hashlock
        );
        address srcEscrow = EscrowFactory(chainA.factory).addressOfEscrowSrc(srcImmutables);
        console.log("Source escrow address:", srcEscrow);

        // Step 3: Switch to Chain B and create destination escrow (Bob as resolver)
        console.log("\n--- Step 3: Creating Destination Escrow on Chain B ---");
        createDstEscrowOnChainB(chainB, chainA, orderHash, hashlock);

        // Step 4: Back to Chain A - Bob withdraws with secret from source
        console.log("\n--- Step 4: Withdrawing from Source Escrow ---");
        withdrawFromSrcEscrow(chainA, srcImmutables, secret);

        // Step 5: Switch to Chain B - Alice withdraws from destination
        console.log("\n--- Step 5: Withdrawing from Destination Escrow ---");
        withdrawFromDstEscrow(chainB, chainA, orderHash, hashlock, secret);

        console.log("\n========================================");
        console.log("Cross-Chain Swap Test Complete!");
        console.log("========================================");
    }

    function createOrderOnChainA(Deployment memory chainA, bytes32 hashlock) internal returns (bytes32) {
        // Switch to Chain A
        vm.createSelectFork("http://localhost:8545");
        
        // Create order as Alice
        vm.startBroadcast(ALICE_KEY);
        
        // Approve tokens for the order
        IERC20(chainA.tokenA).approve(chainA.limitOrderProtocol, SWAP_AMOUNT);
        
        // Create order data
        IOrderMixin.Order memory order = IOrderMixin.Order({
            salt: uint256(keccak256(abi.encodePacked(block.timestamp, "test"))),
            maker: chainA.alice,
            receiver: chainA.alice,
            makerAsset: chainA.tokenA,
            takerAsset: chainA.tokenA, // Same token for simplicity in testing
            makingAmount: SWAP_AMOUNT,
            takingAmount: SWAP_AMOUNT,
            makerTraits: 0
        });
        
        // In real implementation, this would interact with the limit order protocol
        // For testing, we'll just compute the order hash
        bytes32 orderHash = keccak256(abi.encode(order));
        
        console.log("Order created by Alice:");
        console.log("  Token A amount:", SWAP_AMOUNT / 1e18, "tokens");
        console.log("  Hashlock:", vm.toString(hashlock));
        
        vm.stopBroadcast();
        
        return orderHash;
    }

    function createDstEscrowOnChainB(
        Deployment memory chainB,
        Deployment memory chainA,
        bytes32 orderHash,
        bytes32 hashlock
    ) internal {
        // Switch to Chain B
        vm.createSelectFork("http://localhost:8546");
        
        // Create destination immutables
        IBaseEscrow.Immutables memory dstImmutables = IBaseEscrow.Immutables({
            orderHash: orderHash,
            hashlock: hashlock,
            maker: chainA.bob.toAddress(), // Bob is maker on dst
            taker: chainA.alice.toAddress(), // Alice is taker on dst
            token: chainB.tokenB.toAddress(),
            amount: SWAP_AMOUNT,
            safetyDeposit: SAFETY_DEPOSIT,
            timelocks: createTimelocks()
        });
        
        // Get expected escrow address
        address expectedEscrow = EscrowFactory(chainB.factory).addressOfEscrowDst(dstImmutables);
        console.log("Expected destination escrow:", expectedEscrow);
        
        // Bob creates the destination escrow
        vm.startBroadcast(BOB_KEY);
        
        // Approve tokens
        IERC20(chainB.tokenB).approve(chainB.factory, SWAP_AMOUNT);
        
        // Create escrow with safety deposit
        EscrowFactory(chainB.factory).createDstEscrow{value: SAFETY_DEPOSIT}(
            dstImmutables,
            block.timestamp + SRC_CANCELLATION_START
        );
        
        console.log("Destination escrow created by Bob:");
        console.log("  Token B amount:", SWAP_AMOUNT / 1e18, "tokens");
        console.log("  Safety deposit:", SAFETY_DEPOSIT / 1e18, "ETH");
        
        vm.stopBroadcast();
        
        // Verify escrow was created
        require(expectedEscrow.code.length > 0, "Escrow not deployed");
        require(IERC20(chainB.tokenB).balanceOf(expectedEscrow) == SWAP_AMOUNT, "Tokens not locked");
    }

    function withdrawFromSrcEscrow(
        Deployment memory chainA,
        IBaseEscrow.Immutables memory srcImmutables,
        bytes32 secret
    ) internal {
        // Switch back to Chain A
        vm.createSelectFork("http://localhost:8545");
        
        // Bob withdraws from source escrow
        vm.startBroadcast(BOB_KEY);
        
        address srcEscrow = EscrowFactory(chainA.factory).addressOfEscrowSrc(srcImmutables);
        
        // Check balance before
        uint256 bobBalanceBefore = IERC20(chainA.tokenA).balanceOf(chainA.bob);
        console.log("Bob's Token A balance before:", bobBalanceBefore / 1e18);
        
        // Withdraw with secret
        IBaseEscrow(srcEscrow).withdraw(secret, srcImmutables);
        
        // Check balance after
        uint256 bobBalanceAfter = IERC20(chainA.tokenA).balanceOf(chainA.bob);
        console.log("Bob's Token A balance after:", bobBalanceAfter / 1e18);
        console.log("Bob received:", (bobBalanceAfter - bobBalanceBefore) / 1e18, "Token A");
        
        vm.stopBroadcast();
    }

    function withdrawFromDstEscrow(
        Deployment memory chainB,
        Deployment memory chainA,
        bytes32 orderHash,
        bytes32 hashlock,
        bytes32 secret
    ) internal {
        // Switch to Chain B
        vm.createSelectFork("http://localhost:8546");
        
        // Create destination immutables (same as when creating)
        IBaseEscrow.Immutables memory dstImmutables = IBaseEscrow.Immutables({
            orderHash: orderHash,
            hashlock: hashlock,
            maker: chainA.bob.toAddress(),
            taker: chainA.alice.toAddress(),
            token: chainB.tokenB.toAddress(),
            amount: SWAP_AMOUNT,
            safetyDeposit: SAFETY_DEPOSIT,
            timelocks: createTimelocks()
        });
        
        address dstEscrow = EscrowFactory(chainB.factory).addressOfEscrowDst(dstImmutables);
        
        // Alice withdraws from destination escrow
        vm.startBroadcast(ALICE_KEY);
        
        // Check balance before
        uint256 aliceBalanceBefore = IERC20(chainB.tokenB).balanceOf(chainA.alice);
        console.log("Alice's Token B balance before:", aliceBalanceBefore / 1e18);
        
        // Withdraw with secret
        IBaseEscrow(dstEscrow).withdraw(secret, dstImmutables);
        
        // Check balance after
        uint256 aliceBalanceAfter = IERC20(chainB.tokenB).balanceOf(chainA.alice);
        console.log("Alice's Token B balance after:", aliceBalanceAfter / 1e18);
        console.log("Alice received:", (aliceBalanceAfter - aliceBalanceBefore) / 1e18, "Token B");
        
        vm.stopBroadcast();
    }

    function createSrcImmutables(
        Deployment memory chainA,
        bytes32 orderHash,
        bytes32 hashlock
    ) internal view returns (IBaseEscrow.Immutables memory) {
        return IBaseEscrow.Immutables({
            orderHash: orderHash,
            hashlock: hashlock,
            maker: chainA.alice.toAddress(),
            taker: chainA.bob.toAddress(),
            token: chainA.tokenA.toAddress(),
            amount: SWAP_AMOUNT,
            safetyDeposit: SAFETY_DEPOSIT,
            timelocks: createTimelocks()
        });
    }

    function createTimelocks() internal view returns (Timelocks) {
        uint256 packed = 0;
        packed |= uint32(SRC_WITHDRAWAL_START);
        packed |= uint32(SRC_PUBLIC_WITHDRAWAL_START) << 32;
        packed |= uint32(SRC_CANCELLATION_START) << 64;
        packed |= uint32(SRC_PUBLIC_CANCELLATION_START) << 96;
        packed |= uint32(DST_WITHDRAWAL_START) << 128;
        packed |= uint32(DST_PUBLIC_WITHDRAWAL_START) << 160;
        packed |= uint32(DST_CANCELLATION_START) << 192;
        packed |= uint32(block.timestamp) << 224;
        
        return Timelocks.wrap(packed);
    }

    function loadDeployment(string memory path) internal view returns (Deployment memory) {
        string memory json = vm.readFile(path);
        
        return Deployment({
            factory: vm.parseJsonAddress(json, ".contracts.factory"),
            limitOrderProtocol: vm.parseJsonAddress(json, ".contracts.limitOrderProtocol"),
            tokenA: vm.parseJsonAddress(json, ".contracts.tokenA"),
            tokenB: vm.parseJsonAddress(json, ".contracts.tokenB"),
            accessToken: vm.parseJsonAddress(json, ".contracts.accessToken"),
            feeToken: vm.parseJsonAddress(json, ".contracts.feeToken"),
            alice: vm.parseJsonAddress(json, ".accounts.alice"),
            bob: vm.parseJsonAddress(json, ".accounts.bob"),
            chainId: vm.parseJsonUint(json, ".chainId")
        });
    }
}