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
    uint256 constant SAFETY_DEPOSIT = 0.01 ether; // Small deposit for mainnet
    
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
        
        Deployment memory base = loadDeployment("deployments/baseMainnet.json");
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

        // Setup timelock values
        Timelocks memory timelocks = Timelocks({
            srcWithdrawal: SRC_WITHDRAWAL_START,
            srcPublicWithdrawal: SRC_PUBLIC_WITHDRAWAL_START,
            srcCancellation: SRC_CANCELLATION_START,
            srcPublicCancellation: SRC_PUBLIC_CANCELLATION_START,
            dstWithdrawal: DST_WITHDRAWAL_START,
            dstPublicWithdrawal: DST_PUBLIC_WITHDRAWAL_START,
            dstCancellation: DST_CANCELLATION_START
        });

        // Create immutables for escrow
        IBaseEscrow.Immutables memory immutables = IBaseEscrow.Immutables({
            orderHash: bytes32(0), // Not using order hash for direct creation
            hashlock: hashlock,
            srcMaker: alice,
            srcToken: base.tokenA,
            srcAmount: SWAP_AMOUNT,
            srcBeneficiary: alice,
            srcCanceler: alice,
            dstMaker: bob,
            dstToken: base.tokenB,
            dstAmount: SWAP_AMOUNT,
            dstBeneficiary: alice,
            dstCanceler: bob,
            timelocks: timelocks.pack()
        });

        // Calculate escrow addresses
        (address srcEscrow, address dstEscrow) = IEscrowFactory(base.factory).computeEscrowAddresses(
            immutables
        );
        
        console.log("Source escrow will be at:", srcEscrow);
        console.log("Destination escrow will be at:", dstEscrow);

        // Pre-fund with safety deposit if needed
        if (SAFETY_DEPOSIT > 0) {
            (bool sent, ) = srcEscrow.call{value: SAFETY_DEPOSIT}("");
            require(sent, "Failed to send safety deposit");
            console.log("Sent", SAFETY_DEPOSIT / 1e18, "ETH safety deposit to source escrow");
        }

        // Deploy source escrow (TestEscrowFactory allows direct deployment)
        IEscrowFactory(base.factory).deployEscrow(immutables, false);
        
        console.log("Source escrow deployed!");

        // Update state file
        string memory json = "state";
        string memory newState = vm.readFile(STATE_FILE);
        vm.serializeString(json, "existing", newState);
        vm.serializeAddress(json, "srcEscrow", srcEscrow);
        vm.serializeAddress(json, "dstEscrow", dstEscrow);
        vm.serializeBytes(json, "immutables", abi.encode(immutables));
        string memory updatedJson = vm.serializeUint(json, "srcDeployTime", block.timestamp);
        vm.writeJson(updatedJson, STATE_FILE);

        vm.stopBroadcast();
    }

    function createDstEscrow() internal {
        console.log("--- Step 3: Creating Destination Escrow on Etherlink Mainnet ---");
        
        Deployment memory etherlink = loadDeployment("deployments/etherlinkMainnet.json");
        require(etherlink.chainId == 42793, "Not on Etherlink mainnet");
        
        // Load test state
        string memory stateJson = vm.readFile(STATE_FILE);
        address dstEscrow = vm.parseJsonAddress(stateJson, ".dstEscrow");
        bytes memory immutablesData = vm.parseJsonBytes(stateJson, ".immutables");
        IBaseEscrow.Immutables memory immutables = abi.decode(immutablesData, (IBaseEscrow.Immutables));
        
        // Get Bob's private key from environment
        uint256 bobKey = vm.envUint("RESOLVER_PRIVATE_KEY");
        address bob = vm.addr(bobKey);

        vm.startBroadcast(bobKey);

        // Pre-fund destination escrow with tokens and safety deposit
        IERC20(etherlink.tokenB).transfer(dstEscrow, SWAP_AMOUNT);
        console.log("Sent", SWAP_AMOUNT / 1e18, "TKB to destination escrow");
        
        if (SAFETY_DEPOSIT > 0) {
            (bool sent, ) = dstEscrow.call{value: SAFETY_DEPOSIT}("");
            require(sent, "Failed to send safety deposit");
            console.log("Sent", SAFETY_DEPOSIT / 1e18, "ETH safety deposit to destination escrow");
        }

        // Deploy destination escrow
        IEscrowFactory(etherlink.factory).deployEscrow(immutables, true);
        
        console.log("Destination escrow deployed at:", dstEscrow);

        // Update state file
        string memory json = "state";
        string memory newState = vm.readFile(STATE_FILE);
        vm.serializeString(json, "existing", newState);
        string memory updatedJson = vm.serializeUint(json, "dstDeployTime", block.timestamp);
        vm.writeJson(updatedJson, STATE_FILE);

        vm.stopBroadcast();
    }

    function withdrawDst() internal {
        console.log("--- Step 4: Withdraw from Destination Escrow (Alice reveals secret) ---");
        
        Deployment memory etherlink = loadDeployment("deployments/etherlinkMainnet.json");
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

        // Withdraw from destination escrow
        IBaseEscrow(dstEscrow).withdraw(secret);
        
        // Check balance after
        uint256 balanceAfter = IERC20(etherlink.tokenB).balanceOf(alice);
        console.log("Alice TKB balance after:", balanceAfter / 1e18);
        console.log("Alice received:", (balanceAfter - balanceBefore) / 1e18, "TKB");

        vm.stopBroadcast();
    }

    function withdrawSrc() internal {
        console.log("--- Step 5: Withdraw from Source Escrow (Bob uses revealed secret) ---");
        
        Deployment memory base = loadDeployment("deployments/baseMainnet.json");
        require(base.chainId == 8453, "Not on Base mainnet");
        
        // Load test state
        string memory stateJson = vm.readFile(STATE_FILE);
        address srcEscrow = vm.parseJsonAddress(stateJson, ".srcEscrow");
        address dstEscrow = vm.parseJsonAddress(stateJson, ".dstEscrow");
        
        // Get Bob's private key from environment
        uint256 bobKey = vm.envUint("RESOLVER_PRIVATE_KEY");
        address bob = vm.addr(bobKey);

        vm.startBroadcast(bobKey);

        // Get the revealed secret from destination escrow
        bytes32 secret = IBaseEscrow(dstEscrow).secret();
        require(secret != bytes32(0), "Secret not revealed yet");
        console.log("Retrieved secret from destination escrow");

        // Check balance before
        uint256 balanceBefore = IERC20(base.tokenA).balanceOf(bob);
        console.log("Bob TKA balance before:", balanceBefore / 1e18);

        // Withdraw from source escrow
        IBaseEscrow(srcEscrow).withdraw(secret);
        
        // Check balance after
        uint256 balanceAfter = IERC20(base.tokenA).balanceOf(bob);
        console.log("Bob TKA balance after:", balanceAfter / 1e18);
        console.log("Bob received:", (balanceAfter - balanceBefore) / 1e18, "TKA");

        vm.stopBroadcast();
    }

    function checkBalances() internal view {
        console.log("--- Checking Balances ---");
        
        // Try to load both deployments
        Deployment memory base = loadDeployment("deployments/baseMainnet.json");
        Deployment memory etherlink = loadDeployment("deployments/etherlinkMainnet.json");
        
        // Get addresses from environment
        address alice = vm.envAddress("ALICE");
        address bob = vm.envAddress("BOB_RESOLVER");
        
        console.log("\n=== Base Mainnet ===");
        console.log("Alice TKA:", IERC20(base.tokenA).balanceOf(alice) / 1e18);
        console.log("Bob TKA:", IERC20(base.tokenA).balanceOf(bob) / 1e18);
        
        console.log("\n=== Etherlink Mainnet ===");
        console.log("Alice TKB:", IERC20(etherlink.tokenB).balanceOf(alice) / 1e18);
        console.log("Bob TKB:", IERC20(etherlink.tokenB).balanceOf(bob) / 1e18);
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
}