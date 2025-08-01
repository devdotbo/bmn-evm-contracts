// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { IOrderMixin, LimitOrderProtocol } from "limit-order-protocol/contracts/LimitOrderProtocol.sol";
import { Address, AddressLib } from "solidity-utils/contracts/libraries/AddressLib.sol";
import { MakerTraits } from "limit-order-protocol/contracts/libraries/MakerTraitsLib.sol";
import { Clones } from "openzeppelin-contracts/contracts/proxy/Clones.sol";

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

    // Fork IDs to reuse forks instead of creating new ones
    uint256 chainAFork;
    uint256 chainBFork;

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

        // Create forks for both chains
        chainAFork = vm.createFork("http://localhost:8545");
        chainBFork = vm.createFork("http://localhost:8546");

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

        // Step 2: Create source escrow on Chain A
        console.log("\n--- Step 2: Creating Source Escrow on Chain A ---");
        IBaseEscrow.Immutables memory srcImmutables = createSrcImmutables(
            chainA,
            orderHash,
            hashlock
        );
        (address srcEscrow, IBaseEscrow.Immutables memory srcImmutablesWithTimestamp) = createSrcEscrowOnChainA(chainA, srcImmutables);
        console.log("Source escrow created at:", srcEscrow);

        // Step 3: Switch to Chain B and create destination escrow (Bob as resolver)
        console.log("\n--- Step 3: Creating Destination Escrow on Chain B ---");
        createDstEscrowOnChainB(chainB, chainA, orderHash, hashlock);

        // Step 4: Back to Chain A - Bob withdraws with secret from source
        console.log("\n--- Step 4: Withdrawing from Source Escrow ---");
        withdrawFromSrcEscrow(chainA, srcEscrow, srcImmutablesWithTimestamp, secret);

        // Step 5: Switch to Chain B - Alice withdraws from destination
        console.log("\n--- Step 5: Withdrawing from Destination Escrow ---");
        withdrawFromDstEscrow(chainB, chainA, orderHash, hashlock, secret);

        console.log("\n========================================");
        console.log("Cross-Chain Swap Test Complete!");
        console.log("========================================");
    }

    function createOrderOnChainA(Deployment memory chainA, bytes32 hashlock) internal returns (bytes32) {
        // Switch to Chain A
        vm.selectFork(chainAFork);
        
        // Create order as Alice
        vm.startBroadcast(ALICE_KEY);
        
        // Approve tokens for the order
        IERC20(chainA.tokenA).approve(chainA.limitOrderProtocol, SWAP_AMOUNT);
        
        // Create order data
        IOrderMixin.Order memory order = IOrderMixin.Order({
            salt: uint256(keccak256(abi.encodePacked(block.timestamp, "test"))),
            maker: Address.wrap(uint160(chainA.alice)),
            receiver: Address.wrap(uint160(chainA.alice)),
            makerAsset: Address.wrap(uint160(chainA.tokenA)),
            takerAsset: Address.wrap(uint160(chainA.tokenA)), // Same token for simplicity in testing
            makingAmount: SWAP_AMOUNT,
            takingAmount: SWAP_AMOUNT,
            makerTraits: MakerTraits.wrap(0)
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

    function createSrcEscrowOnChainA(
        Deployment memory chainA,
        IBaseEscrow.Immutables memory srcImmutables
    ) internal returns (address, IBaseEscrow.Immutables memory) {
        // In the real flow, the limit order protocol would deploy the source escrow
        // For testing, we'll simulate this by deploying from the factory address
        
        // Update timelocks with deployment timestamp
        srcImmutables.timelocks = srcImmutables.timelocks.setDeployedAt(block.timestamp);
        
        // Get the expected escrow address from factory
        address expectedEscrow = EscrowFactory(chainA.factory).addressOfEscrowSrc(srcImmutables);
        console.log("Expected source escrow address:", expectedEscrow);
        
        // First, Alice needs to send the safety deposit to the future escrow address
        vm.startBroadcast(ALICE_KEY);
        (bool success,) = expectedEscrow.call{value: SAFETY_DEPOSIT}("");
        require(success, "Failed to pre-fund safety deposit");
        vm.stopBroadcast();
        
        // Deploy the escrow from the factory address to match CREATE2 expectations
        vm.startPrank(chainA.factory);
        
        bytes32 salt = srcImmutables.hashMem();
        address impl = EscrowFactory(chainA.factory).ESCROW_SRC_IMPLEMENTATION();
        
        // Deploy using the same Clones library that the factory uses
        // The safety deposit is already at the address and will be part of the deployed contract
        address escrow = Clones.cloneDeterministic(impl, salt);
        console.log("Deployed source escrow at:", escrow);
        require(escrow == expectedEscrow, "Escrow address mismatch");
        
        vm.stopPrank();
        
        // Transfer tokens to the escrow (Alice needs to do this as she has the tokens)
        vm.startBroadcast(ALICE_KEY);
        IERC20(chainA.tokenA).transfer(escrow, SWAP_AMOUNT);
        vm.stopBroadcast();
        
        console.log("Funded with", SWAP_AMOUNT / 1e18, "Token A");
        
        return (escrow, srcImmutables);
    }

    function createDstEscrowOnChainB(
        Deployment memory chainB,
        Deployment memory chainA,
        bytes32 orderHash,
        bytes32 hashlock
    ) internal {
        // Switch to Chain B
        vm.selectFork(chainBFork);
        
        // Create destination immutables
        // On destination chain: Alice is the maker (recipient), Bob is the taker (resolver)
        IBaseEscrow.Immutables memory dstImmutables = IBaseEscrow.Immutables({
            orderHash: orderHash,
            hashlock: hashlock,
            maker: Address.wrap(uint160(chainA.alice)), // Alice is maker (recipient) on dst
            taker: Address.wrap(uint160(chainA.bob)), // Bob is taker (resolver) on dst
            token: Address.wrap(uint160(chainB.tokenB)),
            amount: SWAP_AMOUNT,
            safetyDeposit: SAFETY_DEPOSIT,
            timelocks: createTimelocks()
        });
        
        // Get expected escrow address using our prediction function
        address expectedEscrow = predictDstEscrowAddress(chainB, dstImmutables);
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
        address srcEscrow,
        IBaseEscrow.Immutables memory srcImmutables,
        bytes32 secret
    ) internal {
        // Switch back to Chain A
        vm.selectFork(chainAFork);
        
        // Bob withdraws from source escrow
        vm.startBroadcast(BOB_KEY);
        
        // Check balance before
        uint256 bobBalanceBefore = IERC20(chainA.tokenA).balanceOf(chainA.bob);
        console.log("Bob's Token A balance before:", bobBalanceBefore / 1e18);
        
        // Debug: Check escrow state
        console.log("Checking escrow at:", srcEscrow);
        console.log("Escrow has code:", srcEscrow.code.length > 0);
        console.log("Escrow token balance:", IERC20(chainA.tokenA).balanceOf(srcEscrow) / 1e18);
        
        // Verify we're in the correct withdrawal window
        uint256 currentTime = block.timestamp;
        uint256 withdrawalStart = srcImmutables.timelocks.get(TimelocksLib.Stage.SrcWithdrawal);
        uint256 cancellationStart = srcImmutables.timelocks.get(TimelocksLib.Stage.SrcCancellation);
        console.log("Current time:", currentTime);
        console.log("Withdrawal window:", withdrawalStart, "-", cancellationStart);
        
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
        vm.selectFork(chainBFork);
        
        // Create destination immutables (same as when creating)
        // On destination chain: Alice is the maker (recipient), Bob is the taker (resolver)
        IBaseEscrow.Immutables memory dstImmutables = IBaseEscrow.Immutables({
            orderHash: orderHash,
            hashlock: hashlock,
            maker: Address.wrap(uint160(chainA.alice)), // Alice is maker (recipient) on dst
            taker: Address.wrap(uint160(chainA.bob)), // Bob is taker (resolver) on dst
            token: Address.wrap(uint160(chainB.tokenB)),
            amount: SWAP_AMOUNT,
            safetyDeposit: SAFETY_DEPOSIT,
            timelocks: createTimelocks()
        });
        
        address dstEscrow = predictDstEscrowAddress(chainB, dstImmutables);
        
        // Debug: Check escrow state
        console.log("Checking destination escrow at:", dstEscrow);
        console.log("Escrow has code:", dstEscrow.code.length > 0);
        console.log("Escrow token balance:", IERC20(chainB.tokenB).balanceOf(dstEscrow) / 1e18);
        console.log("Escrow ETH balance:", dstEscrow.balance / 1e18);
        
        // Bob (resolver/taker) withdraws from destination escrow, which sends tokens to Alice (maker)
        vm.startBroadcast(BOB_KEY);
        
        // Check balances before
        uint256 aliceBalanceBefore = IERC20(chainB.tokenB).balanceOf(chainA.alice);
        uint256 bobBalanceBefore = IERC20(chainB.tokenB).balanceOf(chainA.bob);
        console.log("Alice's Token B balance before:", aliceBalanceBefore / 1e18);
        console.log("Bob's Token B balance before:", bobBalanceBefore / 1e18);
        
        try IBaseEscrow(dstEscrow).withdraw(secret, dstImmutables) {
            console.log("Withdrawal successful");
        } catch Error(string memory reason) {
            console.log("Withdrawal failed:", reason);
            revert(reason);
        } catch (bytes memory lowLevelData) {
            console.log("Withdrawal failed with low-level error");
            console.logBytes(lowLevelData);
            revert("Low-level error during withdrawal");
        }
        
        // Check balances after
        uint256 aliceBalanceAfter = IERC20(chainB.tokenB).balanceOf(chainA.alice);
        uint256 bobBalanceAfter = IERC20(chainB.tokenB).balanceOf(chainA.bob);
        console.log("Alice's Token B balance after:", aliceBalanceAfter / 1e18);
        console.log("Bob's Token B balance after:", bobBalanceAfter / 1e18);
        console.log("Alice received:", (aliceBalanceAfter - aliceBalanceBefore) / 1e18, "Token B");
        console.log("Bob received:", (bobBalanceAfter - bobBalanceBefore) / 1e18, "Token B");
        
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
            maker: Address.wrap(uint160(chainA.alice)),
            taker: Address.wrap(uint160(chainA.bob)),
            token: Address.wrap(uint160(chainA.tokenA)),
            amount: SWAP_AMOUNT,
            safetyDeposit: SAFETY_DEPOSIT,
            timelocks: createTimelocks()
        });
    }

    function createTimelocks() internal pure returns (Timelocks) {
        uint256 packed = 0;
        
        // Cast to uint256 before shifting to avoid truncation
        packed |= uint256(uint32(SRC_WITHDRAWAL_START));
        packed |= uint256(uint32(SRC_PUBLIC_WITHDRAWAL_START)) << 32;
        packed |= uint256(uint32(SRC_CANCELLATION_START)) << 64;
        packed |= uint256(uint32(SRC_PUBLIC_CANCELLATION_START)) << 96;
        packed |= uint256(uint32(DST_WITHDRAWAL_START)) << 128;
        packed |= uint256(uint32(DST_PUBLIC_WITHDRAWAL_START)) << 160;
        packed |= uint256(uint32(DST_CANCELLATION_START)) << 192;
        // deployedAt will be set by the factory during deployment
        
        return Timelocks.wrap(packed);
    }

    function predictDstEscrowAddress(
        Deployment memory chainB,
        IBaseEscrow.Immutables memory immutables
    ) internal view returns (address) {
        // Simulate what the factory does: update timelocks with current block.timestamp
        immutables.timelocks = immutables.timelocks.setDeployedAt(block.timestamp);
        return EscrowFactory(chainB.factory).addressOfEscrowDst(immutables);
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