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
import { TestEscrowFactory } from "../contracts/test/TestEscrowFactory.sol";
import { Timelocks, TimelocksLib } from "../contracts/libraries/TimelocksLib.sol";
import { ImmutablesLib } from "../contracts/libraries/ImmutablesLib.sol";

/**
 * @title LiveTestMainnet
 * @notice Script to test cross-chain atomic swap on mainnet (Base + Etherlink)
 * @dev This script must be run in multiple steps, switching between chains
 */
contract LiveTestMainnet is Script {
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
    uint256 constant SAFETY_DEPOSIT = 0.0001 ether; // Very small deposit for mainnet test
    
    // Timelock configuration (in seconds) - production values
    uint256 constant SRC_WITHDRAWAL_START = 0;
    uint256 constant SRC_PUBLIC_WITHDRAWAL_START = 300; // 5 minutes
    uint256 constant SRC_CANCELLATION_START = 900; // 15 minutes
    uint256 constant SRC_PUBLIC_CANCELLATION_START = 1200; // 20 minutes
    uint256 constant DST_WITHDRAWAL_START = 0;
    uint256 constant DST_PUBLIC_WITHDRAWAL_START = 300; // 5 minutes
    uint256 constant DST_CANCELLATION_START = 900; // 15 minutes

    // State file for cross-chain coordination  
    string constant STATE_FILE = "deployments/mainnet-test-state.json";

    function run() external {
        string memory action = vm.envOr("ACTION", string(""));
        
        if (bytes(action).length == 0) {
            console.log("========================================");
            console.log("Live Mainnet Cross-Chain Atomic Swap Test");
            console.log("========================================");
            console.log("");
            console.log("Usage:");
            console.log("  ACTION=create-order forge script script/LiveTestMainnet.s.sol --rpc-url <BASE_RPC> --broadcast");
            console.log("  ACTION=create-src-escrow forge script script/LiveTestMainnet.s.sol --rpc-url <BASE_RPC> --broadcast");
            console.log("  ACTION=create-dst-escrow forge script script/LiveTestMainnet.s.sol --rpc-url <ETHERLINK_RPC> --broadcast");
            console.log("  ACTION=withdraw-src forge script script/LiveTestMainnet.s.sol --rpc-url <BASE_RPC> --broadcast");
            console.log("  ACTION=withdraw-dst forge script script/LiveTestMainnet.s.sol --rpc-url <ETHERLINK_RPC> --broadcast");
            console.log("  ACTION=check-balances forge script script/LiveTestMainnet.s.sol --rpc-url <BASE_RPC>");
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
        console.log("--- Step 1: Creating Order on Base Mainnet ---");
        
        Deployment memory base = loadDeployment("deployments/baseMainnet.json");
        require(base.chainId == 8453, "Not on Base mainnet");

        // Get Alice's private key from environment
        uint256 aliceKey = vm.envUint("ALICE_PRIVATE_KEY");
        address alice = vm.addr(aliceKey);
        require(alice == base.alice, "Alice address mismatch");

        vm.startBroadcast(aliceKey);

        // Generate secret and compute hashlock
        bytes32 secret = keccak256(abi.encodePacked(block.timestamp, alice, "mainnet-swap-test"));
        bytes32 hashlock = keccak256(abi.encodePacked(secret));
        
        console.log("Secret:", vm.toString(secret));
        console.log("Hashlock:", vm.toString(hashlock));

        // State to save
        string memory json = "state";
        vm.serializeBytes32(json, "secret", secret);
        vm.serializeBytes32(json, "hashlock", hashlock);
        vm.serializeUint(json, "timestamp", block.timestamp);
        string memory stateJson = vm.serializeAddress(json, "alice", alice);
        vm.writeJson(stateJson, STATE_FILE);

        console.log("State saved to:", STATE_FILE);
        vm.stopBroadcast();
    }

    function createSrcEscrow() internal {
        console.log("--- Step 2: Creating Source Escrow on Base Mainnet ---");
        
        Deployment memory base = loadDeployment("deployments/baseMainnetTest.json");
        require(base.chainId == 8453, "Not on Base mainnet");
        
        // Load test state
        string memory stateJson = vm.readFile(STATE_FILE);
        bytes32 hashlock = vm.parseJsonBytes32(stateJson, ".hashlock");
        
        // Get Alice's private key from environment
        uint256 aliceKey = vm.envUint("ALICE_PRIVATE_KEY");
        address alice = vm.addr(aliceKey);
        
        // Get Bob's address from environment
        address bob = vm.envAddress("BOB_RESOLVER");

        vm.startBroadcast(aliceKey);

        // Approve token transfer
        IERC20(base.tokenA).approve(base.factory, SWAP_AMOUNT);
        console.log("Approved", SWAP_AMOUNT / 1e18, "TKA to factory");

        // Create immutables for source escrow
        IBaseEscrow.Immutables memory srcImmutables = IBaseEscrow.Immutables({
            orderHash: bytes32(0), // Not using order hash for direct creation
            hashlock: hashlock,
            maker: Address.wrap(uint160(alice)),
            taker: Address.wrap(uint160(bob)),
            token: Address.wrap(uint160(base.tokenA)),
            amount: SWAP_AMOUNT,
            safetyDeposit: SAFETY_DEPOSIT,
            timelocks: createTimelocks()
        });

        // Cast factory to TestEscrowFactory
        TestEscrowFactory testFactory = TestEscrowFactory(base.factory);
        
        // Deploy source escrow using test factory
        address srcEscrow = testFactory.createSrcEscrowForTesting(srcImmutables, SWAP_AMOUNT);
        
        console.log("Source escrow deployed at:", srcEscrow);
        
        // Note: Safety deposit is handled internally by the escrow contract
        // The safetyDeposit field in immutables specifies the required amount

        // Create destination immutables for saving
        IBaseEscrow.Immutables memory dstImmutables = IBaseEscrow.Immutables({
            orderHash: bytes32(0),
            hashlock: hashlock,
            maker: Address.wrap(uint160(bob)), // Bob is maker on destination
            taker: Address.wrap(uint160(alice)), // Alice is taker on destination
            token: Address.wrap(uint160(base.tokenB)),
            amount: SWAP_AMOUNT,
            safetyDeposit: SAFETY_DEPOSIT,
            timelocks: createTimelocks()
        });

        // Update state file
        string memory json = "state";
        string memory newState = vm.readFile(STATE_FILE);
        vm.serializeString(json, "existing", newState);
        vm.serializeAddress(json, "srcEscrow", srcEscrow);
        vm.serializeBytes(json, "srcImmutables", abi.encode(srcImmutables));
        vm.serializeBytes(json, "dstImmutables", abi.encode(dstImmutables));
        string memory updatedJson = vm.serializeUint(json, "srcDeployTime", block.timestamp);
        vm.writeJson(updatedJson, STATE_FILE);

        vm.stopBroadcast();
    }

    function createDstEscrow() internal {
        console.log("--- Step 3: Creating Destination Escrow on Etherlink Mainnet ---");
        
        Deployment memory etherlink = loadDeployment("deployments/etherlinkMainnetTest.json");
        require(etherlink.chainId == 42793, "Not on Etherlink mainnet");
        
        // Load test state
        string memory stateJson = vm.readFile(STATE_FILE);
        bytes memory dstImmutablesData = vm.parseJsonBytes(stateJson, ".dstImmutables");
        IBaseEscrow.Immutables memory dstImmutables = abi.decode(dstImmutablesData, (IBaseEscrow.Immutables));
        
        // Get Bob's private key from environment
        uint256 bobKey = vm.envUint("RESOLVER_PRIVATE_KEY");
        address bob = vm.addr(bobKey);

        vm.startBroadcast(bobKey);

        // Update timelocks with current deployment timestamp
        dstImmutables.timelocks = dstImmutables.timelocks.setDeployedAt(block.timestamp);

        // Calculate expected destination escrow address
        address expectedDstEscrow = Clones.predictDeterministicAddress(
            TestEscrowFactory(etherlink.factory).ESCROW_DST_IMPLEMENTATION(),
            dstImmutables.hashMem(),
            etherlink.factory
        );
        
        console.log("Destination escrow will be at:", expectedDstEscrow);

        // Pre-fund destination escrow with tokens
        IERC20(etherlink.tokenB).transfer(expectedDstEscrow, SWAP_AMOUNT);
        console.log("Sent", SWAP_AMOUNT / 1e18, "TKB to destination escrow");

        // Deploy destination escrow using factory's createDstEscrow
        // Bob provides safety deposit when creating destination escrow
        console.log("Bob providing safety deposit:", SAFETY_DEPOSIT / 1e18, "ETH");
        uint256 srcCancellationTimestamp = dstImmutables.timelocks.get(TimelocksLib.Stage.SrcCancellation);
        IEscrowFactory(etherlink.factory).createDstEscrow{value: SAFETY_DEPOSIT}(dstImmutables, srcCancellationTimestamp);
        
        console.log("Destination escrow deployed!");

        // Update state file
        string memory json = "state";
        string memory newState = vm.readFile(STATE_FILE);
        vm.serializeString(json, "existing", newState);
        vm.serializeAddress(json, "dstEscrow", expectedDstEscrow);
        string memory updatedJson = vm.serializeUint(json, "dstDeployTime", block.timestamp);
        vm.writeJson(updatedJson, STATE_FILE);

        vm.stopBroadcast();
    }

    function withdrawDst() internal {
        console.log("--- Step 4: Withdraw from Destination Escrow (Alice reveals secret) ---");
        
        Deployment memory etherlink = loadDeployment("deployments/etherlinkMainnetTest.json");
        require(etherlink.chainId == 42793, "Not on Etherlink mainnet");
        
        // Load test state
        string memory stateJson = vm.readFile(STATE_FILE);
        address dstEscrow = vm.parseJsonAddress(stateJson, ".dstEscrow");
        bytes32 secret = vm.parseJsonBytes32(stateJson, ".secret");
        
        // Get Alice's private key from environment
        uint256 aliceKey = vm.envUint("ALICE_PRIVATE_KEY");
        address alice = vm.addr(aliceKey);

        vm.startBroadcast(aliceKey);

        // Check balance before
        uint256 balanceBefore = IERC20(etherlink.tokenB).balanceOf(alice);
        console.log("Alice TKB balance before:", balanceBefore / 1e18);

        // Load destination immutables from state
        bytes memory dstImmutablesData = vm.parseJsonBytes(stateJson, ".dstImmutables");
        IBaseEscrow.Immutables memory dstImmutables = abi.decode(dstImmutablesData, (IBaseEscrow.Immutables));
        
        // Update timelocks with deployment timestamp from state
        uint256 dstDeployTime = vm.parseJsonUint(stateJson, ".dstDeployTime");
        dstImmutables.timelocks = dstImmutables.timelocks.setDeployedAt(dstDeployTime);
        
        // Withdraw from destination escrow
        IBaseEscrow(dstEscrow).withdraw(secret, dstImmutables);
        
        // Check balance after
        uint256 balanceAfter = IERC20(etherlink.tokenB).balanceOf(alice);
        console.log("Alice TKB balance after:", balanceAfter / 1e18);
        console.log("Alice received:", (balanceAfter - balanceBefore) / 1e18, "TKB");

        vm.stopBroadcast();
    }

    function withdrawSrc() internal {
        console.log("--- Step 5: Withdraw from Source Escrow (Bob uses revealed secret) ---");
        
        Deployment memory base = loadDeployment("deployments/baseMainnetTest.json");
        require(base.chainId == 8453, "Not on Base mainnet");
        
        // Load test state
        string memory stateJson = vm.readFile(STATE_FILE);
        address srcEscrow = vm.parseJsonAddress(stateJson, ".srcEscrow");
        bytes32 secret = vm.parseJsonBytes32(stateJson, ".secret");
        
        // Get Bob's private key from environment
        uint256 bobKey = vm.envUint("RESOLVER_PRIVATE_KEY");
        address bob = vm.addr(bobKey);

        vm.startBroadcast(bobKey);

        console.log("Using secret:", vm.toString(secret));

        // Check balance before
        uint256 balanceBefore = IERC20(base.tokenA).balanceOf(bob);
        console.log("Bob TKA balance before:", balanceBefore / 1e18);

        // Load source immutables from state
        bytes memory srcImmutablesData = vm.parseJsonBytes(stateJson, ".srcImmutables");
        IBaseEscrow.Immutables memory srcImmutables = abi.decode(srcImmutablesData, (IBaseEscrow.Immutables));
        
        // Update timelocks with deployment timestamp from state
        uint256 srcDeployTime = vm.parseJsonUint(stateJson, ".srcDeployTime");
        srcImmutables.timelocks = srcImmutables.timelocks.setDeployedAt(srcDeployTime);
        
        // Withdraw from source escrow
        IBaseEscrow(srcEscrow).withdraw(secret, srcImmutables);
        
        // Check balance after
        uint256 balanceAfter = IERC20(base.tokenA).balanceOf(bob);
        console.log("Bob TKA balance after:", balanceAfter / 1e18);
        console.log("Bob received:", (balanceAfter - balanceBefore) / 1e18, "TKA");

        vm.stopBroadcast();
    }

    function checkBalances() internal view {
        console.log("--- Checking Balances ---");
        
        // Load the regular deployment files for token addresses
        Deployment memory base = loadDeployment("deployments/baseMainnet.json");
        
        // Get addresses from environment
        address alice = vm.envAddress("ALICE");
        address bob = vm.envAddress("BOB_RESOLVER");
        
        console.log("\n=== Base Mainnet ===");
        console.log("Alice TKA:", IERC20(base.tokenA).balanceOf(alice) / 1e18);
        console.log("Bob TKA:", IERC20(base.tokenA).balanceOf(bob) / 1e18);
        
        console.log("\n=== Etherlink Mainnet ===");
        // Note: On Etherlink, we need to use the same token addresses as Base
        // The tokens are the same across both chains (same addresses due to CREATE2)
        console.log("Alice TKB:", IERC20(base.tokenB).balanceOf(alice) / 1e18);
        console.log("Bob TKB:", IERC20(base.tokenB).balanceOf(bob) / 1e18);
    }

    function loadDeployment(string memory path) internal view returns (Deployment memory) {
        string memory json = vm.readFile(path);
        
        Deployment memory deployment;
        deployment.factory = vm.parseJsonAddress(json, ".contracts.factory");
        deployment.limitOrderProtocol = vm.parseJsonAddress(json, ".contracts.limitOrderProtocol");
        deployment.tokenA = vm.parseJsonAddress(json, ".contracts.tokenA");
        deployment.tokenB = vm.parseJsonAddress(json, ".contracts.tokenB");
        deployment.accessToken = vm.parseJsonAddress(json, ".contracts.accessToken");
        deployment.feeToken = vm.parseJsonAddress(json, ".contracts.feeToken");
        deployment.alice = vm.parseJsonAddress(json, ".accounts.alice");
        deployment.bob = vm.parseJsonAddress(json, ".accounts.bob");
        deployment.chainId = vm.parseJsonUint(json, ".chainId");
        
        return deployment;
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
}