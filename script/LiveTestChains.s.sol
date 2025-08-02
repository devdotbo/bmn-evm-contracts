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
 * @title LiveTestChains
 * @notice Script to test cross-chain atomic swap on live chains (no forks)
 * @dev This script must be run in multiple steps, switching between chains
 */
contract LiveTestChains is Script {
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

    // State file for cross-chain coordination  
    string constant STATE_FILE = "deployments/test-state.json";

    function run() external {
        string memory action = vm.envOr("ACTION", string(""));
        
        if (bytes(action).length == 0) {
            console.log("========================================");
            console.log("Live Cross-Chain Atomic Swap Test");
            console.log("========================================");
            console.log("");
            console.log("Usage:");
            console.log("  ACTION=create-order forge script script/LiveTestChains.s.sol --rpc-url http://localhost:8545 --broadcast");
            console.log("  ACTION=create-src-escrow forge script script/LiveTestChains.s.sol --rpc-url http://localhost:8545 --broadcast");
            console.log("  ACTION=create-dst-escrow forge script script/LiveTestChains.s.sol --rpc-url http://localhost:8546 --broadcast");
            console.log("  ACTION=withdraw-src forge script script/LiveTestChains.s.sol --rpc-url http://localhost:8545 --broadcast");
            console.log("  ACTION=withdraw-dst forge script script/LiveTestChains.s.sol --rpc-url http://localhost:8546 --broadcast");
            console.log("  ACTION=check-balances forge script script/LiveTestChains.s.sol --rpc-url http://localhost:8545");
            return;
        }

        if (keccak256(bytes(action)) == keccak256(bytes("create-order"))) {
            createOrder();
        } else if (keccak256(bytes(action)) == keccak256(bytes("create-src-escrow"))) {
            createSrcEscrow();
        } else if (keccak256(bytes(action)) == keccak256(bytes("create-dst-escrow"))) {
            createDstEscrow();
        } else if (keccak256(bytes(action)) == keccak256(bytes("withdraw-src"))) {
            withdrawSrc();
        } else if (keccak256(bytes(action)) == keccak256(bytes("withdraw-dst"))) {
            withdrawDst();
        } else if (keccak256(bytes(action)) == keccak256(bytes("check-balances"))) {
            checkBalances();
        } else {
            revert(string.concat("Unknown action: ", action));
        }
    }

    function createOrder() internal {
        console.log("--- Step 1: Creating Order on Chain A ---");
        
        Deployment memory chainA = loadDeployment("deployments/chainA.json");
        require(block.chainid == chainA.chainId, "Must run on Chain A");

        // Generate secret for the swap
        bytes32 secret = keccak256(abi.encodePacked("test_secret", block.timestamp));
        bytes32 hashlock = keccak256(abi.encodePacked(secret));
        
        vm.startBroadcast(ALICE_KEY);
        
        // Approve tokens for the order
        IERC20(chainA.tokenA).approve(chainA.limitOrderProtocol, SWAP_AMOUNT);
        
        // Create order data
        IOrderMixin.Order memory order = IOrderMixin.Order({
            salt: uint256(keccak256(abi.encodePacked(block.timestamp, "test"))),
            maker: Address.wrap(uint160(chainA.alice)),
            receiver: Address.wrap(uint160(chainA.alice)),
            makerAsset: Address.wrap(uint160(chainA.tokenA)),
            takerAsset: Address.wrap(uint160(chainA.tokenA)),
            makingAmount: SWAP_AMOUNT,
            takingAmount: SWAP_AMOUNT,
            makerTraits: MakerTraits.wrap(0)
        });
        
        bytes32 orderHash = keccak256(abi.encode(order));
        
        vm.stopBroadcast();

        // Save state
        string memory json = string.concat(
            '{\n',
            '  "secret": "', vm.toString(secret), '",\n',
            '  "hashlock": "', vm.toString(hashlock), '",\n',
            '  "orderHash": "', vm.toString(orderHash), '",\n',
            '  "timestamp": ', vm.toString(block.timestamp), '\n',
            '}'
        );
        vm.writeFile(STATE_FILE, json);

        console.log("Order created with hash:", vm.toString(orderHash));
        console.log("State saved to:", STATE_FILE);
    }

    function createSrcEscrow() internal {
        console.log("--- Step 2: Creating Source Escrow on Chain A ---");
        
        Deployment memory chainA = loadDeployment("deployments/chainA.json");
        require(block.chainid == chainA.chainId, "Must run on Chain A");

        // Load state
        string memory json = vm.readFile(STATE_FILE);
        bytes32 orderHash = vm.parseJsonBytes32(json, ".orderHash");
        bytes32 hashlock = vm.parseJsonBytes32(json, ".hashlock");

        IBaseEscrow.Immutables memory srcImmutables = IBaseEscrow.Immutables({
            orderHash: orderHash,
            hashlock: hashlock,
            maker: Address.wrap(uint160(chainA.alice)),
            taker: Address.wrap(uint160(chainA.bob)),
            token: Address.wrap(uint160(chainA.tokenA)),
            amount: SWAP_AMOUNT,
            safetyDeposit: SAFETY_DEPOSIT,
            timelocks: createTimelocks()
        });

        // Update timelocks with deployment timestamp
        srcImmutables.timelocks = srcImmutables.timelocks.setDeployedAt(block.timestamp);
        
        // Get expected escrow address
        address expectedEscrow = EscrowFactory(chainA.factory).addressOfEscrowSrc(srcImmutables);
        
        // Pre-fund safety deposit
        vm.startBroadcast(ALICE_KEY);
        (bool success,) = expectedEscrow.call{value: SAFETY_DEPOSIT}("");
        require(success, "Failed to pre-fund safety deposit");
        vm.stopBroadcast();
        
        // Deploy escrow from factory
        vm.startPrank(chainA.factory);
        bytes32 salt = srcImmutables.hashMem();
        address impl = EscrowFactory(chainA.factory).ESCROW_SRC_IMPLEMENTATION();
        address escrow = Clones.cloneDeterministic(impl, salt);
        require(escrow == expectedEscrow, "Escrow address mismatch");
        vm.stopPrank();
        
        // Transfer tokens to escrow
        vm.startBroadcast(ALICE_KEY);
        IERC20(chainA.tokenA).transfer(escrow, SWAP_AMOUNT);
        vm.stopBroadcast();

        // Update state file - read existing JSON and add new fields
        json = vm.readFile(STATE_FILE);
        // Extract existing content by removing the closing brace
        bytes memory jsonBytes = bytes(json);
        bytes memory existingJson = new bytes(jsonBytes.length - 2); // Remove "}\n"
        for (uint i = 0; i < jsonBytes.length - 2; i++) {
            existingJson[i] = jsonBytes[i];
        }
        
        string memory updatedJson = string.concat(
            string(existingJson),
            ',\n  "srcEscrow": "', vm.toString(escrow), '",',
            '\n  "srcDeployTime": ', vm.toString(block.timestamp),
            '\n}'
        );
        vm.writeFile(STATE_FILE, updatedJson);

        console.log("Source escrow created at:", escrow);
    }

    function createDstEscrow() internal {
        console.log("--- Step 3: Creating Destination Escrow on Chain B ---");
        
        Deployment memory chainB = loadDeployment("deployments/chainB.json");
        Deployment memory chainA = loadDeployment("deployments/chainA.json");
        require(block.chainid == chainB.chainId, "Must run on Chain B");

        // Load state
        string memory json = vm.readFile(STATE_FILE);
        bytes32 orderHash = vm.parseJsonBytes32(json, ".orderHash");
        bytes32 hashlock = vm.parseJsonBytes32(json, ".hashlock");
        uint256 srcDeployTime = vm.parseJsonUint(json, ".srcDeployTime");

        // Calculate time elapsed since source escrow deployment
        uint256 timeElapsed = block.timestamp > srcDeployTime ? block.timestamp - srcDeployTime : 0;
        
        console.log("Current block.timestamp:", block.timestamp);
        console.log("srcDeployTime:", srcDeployTime);
        console.log("Time elapsed:", timeElapsed);
        console.log("srcCancellationTimestamp:", srcDeployTime + SRC_CANCELLATION_START);
        
        // Create timelocks adjusted for destination chain
        // Ensure DST_CANCELLATION aligns with SRC_CANCELLATION
        Timelocks adjustedTimelocks = createTimelocksForDst(timeElapsed);
        
        IBaseEscrow.Immutables memory dstImmutables = IBaseEscrow.Immutables({
            orderHash: orderHash,
            hashlock: hashlock,
            maker: Address.wrap(uint160(chainA.alice)),
            taker: Address.wrap(uint160(chainA.bob)),
            token: Address.wrap(uint160(chainB.tokenB)),
            amount: SWAP_AMOUNT,
            safetyDeposit: SAFETY_DEPOSIT,
            timelocks: adjustedTimelocks
        });

        vm.startBroadcast(BOB_KEY);
        
        // Approve tokens
        IERC20(chainB.tokenB).approve(chainB.factory, SWAP_AMOUNT);
        
        // Create escrow with safety deposit
        EscrowFactory(chainB.factory).createDstEscrow{value: SAFETY_DEPOSIT}(
            dstImmutables,
            srcDeployTime + SRC_CANCELLATION_START
        );
        
        vm.stopBroadcast();

        // Update timelocks for address calculation
        dstImmutables.timelocks = dstImmutables.timelocks.setDeployedAt(block.timestamp);
        address dstEscrow = EscrowFactory(chainB.factory).addressOfEscrowDst(dstImmutables);

        console.log("Destination escrow created at:", dstEscrow);
        
        // Debug: show what the destination cancellation time will be
        uint256 dstCancellationTime = dstImmutables.timelocks.get(TimelocksLib.Stage.DstCancellation);
        console.log("DstCancellation will be at:", dstCancellationTime);
        
        // Update state file with dstEscrow address
        string memory updatedState = string.concat(
            '{',
            '"secret": "', vm.toString(bytes32(vm.parseJsonBytes32(json, ".secret"))), '",',
            '"hashlock": "', vm.toString(hashlock), '",',
            '"orderHash": "', vm.toString(orderHash), '",',
            '"timestamp": ', vm.toString(vm.parseJsonUint(json, ".timestamp")), ',',
            '"srcEscrow": "', vm.toString(vm.parseJsonAddress(json, ".srcEscrow")), '",',
            '"srcDeployTime": ', vm.toString(srcDeployTime), ',',
            '"dstEscrow": "', vm.toString(dstEscrow), '"',
            '}'
        );
        vm.writeFile(STATE_FILE, updatedState);
        console.log("State file updated with dstEscrow address");
    }

    function withdrawSrc() internal {
        console.log("--- Step 4: Withdrawing from Source Escrow ---");
        
        Deployment memory chainA = loadDeployment("deployments/chainA.json");
        require(block.chainid == chainA.chainId, "Must run on Chain A");

        // Load state
        string memory json = vm.readFile(STATE_FILE);
        bytes32 secret = vm.parseJsonBytes32(json, ".secret");
        bytes32 orderHash = vm.parseJsonBytes32(json, ".orderHash");
        bytes32 hashlock = vm.parseJsonBytes32(json, ".hashlock");
        address srcEscrow = vm.parseJsonAddress(json, ".srcEscrow");
        uint256 srcDeployTime = vm.parseJsonUint(json, ".srcDeployTime");

        IBaseEscrow.Immutables memory srcImmutables = IBaseEscrow.Immutables({
            orderHash: orderHash,
            hashlock: hashlock,
            maker: Address.wrap(uint160(chainA.alice)),
            taker: Address.wrap(uint160(chainA.bob)),
            token: Address.wrap(uint160(chainA.tokenA)),
            amount: SWAP_AMOUNT,
            safetyDeposit: SAFETY_DEPOSIT,
            timelocks: createTimelocks().setDeployedAt(srcDeployTime)
        });

        vm.startBroadcast(BOB_KEY);
        
        uint256 bobBalanceBefore = IERC20(chainA.tokenA).balanceOf(chainA.bob);
        
        // Withdraw with secret
        IBaseEscrow(srcEscrow).withdraw(secret, srcImmutables);
        
        uint256 bobBalanceAfter = IERC20(chainA.tokenA).balanceOf(chainA.bob);
        
        vm.stopBroadcast();

        console.log("Bob received:", (bobBalanceAfter - bobBalanceBefore) / 1e18, "Token A");
    }

    function withdrawDst() internal {
        console.log("--- Step 5: Withdrawing from Destination Escrow ---");
        
        Deployment memory chainB = loadDeployment("deployments/chainB.json");
        Deployment memory chainA = loadDeployment("deployments/chainA.json");
        require(block.chainid == chainB.chainId, "Must run on Chain B");

        // Load state
        string memory json = vm.readFile(STATE_FILE);
        bytes32 secret = vm.parseJsonBytes32(json, ".secret");
        bytes32 orderHash = vm.parseJsonBytes32(json, ".orderHash");
        bytes32 hashlock = vm.parseJsonBytes32(json, ".hashlock");
        address dstEscrow = vm.parseJsonAddress(json, ".dstEscrow");

        IBaseEscrow.Immutables memory dstImmutables = IBaseEscrow.Immutables({
            orderHash: orderHash,
            hashlock: hashlock,
            maker: Address.wrap(uint160(chainA.alice)),
            taker: Address.wrap(uint160(chainA.bob)),
            token: Address.wrap(uint160(chainB.tokenB)),
            amount: SWAP_AMOUNT,
            safetyDeposit: SAFETY_DEPOSIT,
            timelocks: createTimelocks().setDeployedAt(block.timestamp)
        });

        vm.startBroadcast(BOB_KEY);
        
        uint256 aliceBalanceBefore = IERC20(chainB.tokenB).balanceOf(chainA.alice);
        
        // Withdraw (sends tokens to Alice)
        IBaseEscrow(dstEscrow).withdraw(secret, dstImmutables);
        
        uint256 aliceBalanceAfter = IERC20(chainB.tokenB).balanceOf(chainA.alice);
        
        vm.stopBroadcast();

        console.log("Alice received:", (aliceBalanceAfter - aliceBalanceBefore) / 1e18, "Token B");
        console.log("Cross-Chain Swap Complete!");
    }

    function checkBalances() internal view {
        Deployment memory deployment = loadDeployment(
            block.chainid == 1337 ? "deployments/chainA.json" : "deployments/chainB.json"
        );

        console.log("=== Current Balances on Chain", block.chainid, "===");
        
        // Alice balances
        uint256 aliceTokenA = IERC20(deployment.tokenA).balanceOf(deployment.alice);
        uint256 aliceTokenB = IERC20(deployment.tokenB).balanceOf(deployment.alice);
        console.log("Alice:");
        console.log("  Token A:", aliceTokenA / 1e18);
        console.log("  Token B:", aliceTokenB / 1e18);
        
        // Bob balances
        uint256 bobTokenA = IERC20(deployment.tokenA).balanceOf(deployment.bob);
        uint256 bobTokenB = IERC20(deployment.tokenB).balanceOf(deployment.bob);
        console.log("Bob:");
        console.log("  Token A:", bobTokenA / 1e18);
        console.log("  Token B:", bobTokenB / 1e18);
    }

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

    function createTimelocksForDst(uint256 timeElapsed) internal pure returns (Timelocks) {
        uint256 packed = 0;
        
        // Source timelocks remain the same
        packed |= uint256(uint32(SRC_WITHDRAWAL_START));
        packed |= uint256(uint32(SRC_PUBLIC_WITHDRAWAL_START)) << 32;
        packed |= uint256(uint32(SRC_CANCELLATION_START)) << 64;
        packed |= uint256(uint32(SRC_PUBLIC_CANCELLATION_START)) << 96;
        
        // Adjust destination timelocks to account for time elapsed
        // This ensures DST_CANCELLATION aligns with SRC_CANCELLATION in absolute time
        uint256 adjustedDstCancellation = DST_CANCELLATION_START > timeElapsed ? 
            DST_CANCELLATION_START - timeElapsed : 0;
        
        packed |= uint256(uint32(DST_WITHDRAWAL_START)) << 128;
        packed |= uint256(uint32(DST_PUBLIC_WITHDRAWAL_START)) << 160;
        packed |= uint256(uint32(adjustedDstCancellation)) << 192;
        
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