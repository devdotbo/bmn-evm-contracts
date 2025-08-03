// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { IBaseEscrow } from "../contracts/interfaces/IBaseEscrow.sol";
import { IEscrowFactory } from "../contracts/interfaces/IEscrowFactory.sol";
import { CrossChainEscrowFactory } from "../contracts/CrossChainEscrowFactory.sol";
import { Timelocks, TimelocksLib } from "../contracts/libraries/TimelocksLib.sol";
import { ImmutablesLib } from "../contracts/libraries/ImmutablesLib.sol";
import { Address, AddressLib } from "solidity-utils/contracts/libraries/AddressLib.sol";

/**
 * @title TestCrossChainSwap
 * @notice Script to test atomic swap using the newly deployed CrossChainEscrowFactory
 * @dev Run with different actions to execute each step of the swap
 */
contract TestCrossChainSwap is Script {
    using AddressLib for address;
    using TimelocksLib for Timelocks;
    using ImmutablesLib for IBaseEscrow.Immutables;

    // Deployed contract addresses (same on both chains)
    address constant FACTORY = 0xc72ed1E8a0649e51Cd046a0FfccC8f8c0bf385Fa;
    address constant BMN_TOKEN = 0x8287CD2aC7E227D9D927F998EB600a0683a832A1; // BMN V1 with 6 decimals
    
    // Test accounts from .env
    address constant ALICE = 0x240E2588e35FB9D3D60B283B45108a49972FFFd8;
    address constant BOB = 0xfdF1dDeB176BEA06c7430166e67E615bC312b7B5;
    
    // Test parameters
    uint256 constant SWAP_AMOUNT = 10e6; // 10 BMN (6 decimals)
    uint256 constant SAFETY_DEPOSIT = 1e6; // 1 BMN safety deposit
    
    // Timelock configuration (in seconds)
    uint256 constant SRC_WITHDRAWAL_START = 0;
    uint256 constant SRC_PUBLIC_WITHDRAWAL_START = 300; // 5 minutes
    uint256 constant SRC_CANCELLATION_START = 900; // 15 minutes
    uint256 constant SRC_PUBLIC_CANCELLATION_START = 1200; // 20 minutes
    uint256 constant DST_WITHDRAWAL_START = 0;
    uint256 constant DST_PUBLIC_WITHDRAWAL_START = 300; // 5 minutes
    uint256 constant DST_CANCELLATION_START = 900; // 15 minutes
    
    // State file for coordination
    string constant STATE_FILE = "deployments/crosschain-swap-state.json";

    function run() external {
        string memory action = vm.envOr("ACTION", string(""));
        
        if (bytes(action).length == 0) {
            console.log("========================================");
            console.log("Cross-Chain Atomic Swap Test");
            console.log("========================================");
            console.log("");
            console.log("Usage:");
            console.log("  ACTION=create-src forge script script/TestCrossChainSwap.s.sol --rpc-url <BASE_RPC> --broadcast");
            console.log("  ACTION=create-dst forge script script/TestCrossChainSwap.s.sol --rpc-url <ETHERLINK_RPC> --broadcast");
            console.log("  ACTION=withdraw-dst forge script script/TestCrossChainSwap.s.sol --rpc-url <ETHERLINK_RPC> --broadcast");
            console.log("  ACTION=withdraw-src forge script script/TestCrossChainSwap.s.sol --rpc-url <BASE_RPC> --broadcast");
            console.log("  ACTION=check-balances forge script script/TestCrossChainSwap.s.sol --rpc-url <RPC>");
            return;
        }

        if (keccak256(bytes(action)) == keccak256(bytes("create-src"))) {
            createSrcEscrow();
        } else if (keccak256(bytes(action)) == keccak256(bytes("create-dst"))) {
            createDstEscrow();
        } else if (keccak256(bytes(action)) == keccak256(bytes("withdraw-dst"))) {
            withdrawDst();
        } else if (keccak256(bytes(action)) == keccak256(bytes("withdraw-src"))) {
            withdrawSrc();
        } else if (keccak256(bytes(action)) == keccak256(bytes("check-balances"))) {
            checkBalances();
        } else {
            revert(string.concat("Unknown action: ", action));
        }
    }

    function createSrcEscrow() internal {
        console.log("--- Creating Source Escrow on Base ---");
        
        // Get Alice's private key
        uint256 aliceKey = vm.envUint("ALICE_PRIVATE_KEY");
        address alice = vm.addr(aliceKey);
        require(alice == ALICE, "Alice address mismatch");

        vm.startBroadcast(aliceKey);

        // Generate secret and hashlock
        bytes32 secret = keccak256(abi.encodePacked(block.timestamp, alice, "crosschain-test"));
        bytes32 hashlock = keccak256(abi.encodePacked(secret));
        
        console.log("Secret:", vm.toString(secret));
        console.log("Hashlock:", vm.toString(hashlock));

        // Check balance
        uint256 balance = IERC20(BMN_TOKEN).balanceOf(alice);
        console.log("Alice BMN balance:", balance / 1e6, "BMN");
        require(balance >= SWAP_AMOUNT, "Insufficient BMN balance");

        // Approve token transfer
        IERC20(BMN_TOKEN).approve(FACTORY, SWAP_AMOUNT);
        console.log("Approved", SWAP_AMOUNT / 1e6, "BMN to factory");

        // Create immutables for source escrow
        IBaseEscrow.Immutables memory srcImmutables = IBaseEscrow.Immutables({
            orderHash: bytes32(0), // Not using order hash
            hashlock: hashlock,
            maker: Address.wrap(uint160(alice)),
            taker: Address.wrap(uint160(BOB)),
            token: Address.wrap(uint160(BMN_TOKEN)),
            amount: SWAP_AMOUNT,
            safetyDeposit: SAFETY_DEPOSIT,
            timelocks: createTimelocks()
        });

        // Deploy source escrow
        address srcEscrow = IEscrowFactory(FACTORY).createSrcEscrow(srcImmutables, block.timestamp);
        console.log("Source escrow deployed at:", srcEscrow);

        // Save state
        string memory json = "state";
        vm.serializeBytes32(json, "secret", secret);
        vm.serializeBytes32(json, "hashlock", hashlock);
        vm.serializeAddress(json, "srcEscrow", srcEscrow);
        vm.serializeBytes(json, "srcImmutables", abi.encode(srcImmutables));
        vm.serializeUint(json, "srcDeployTime", block.timestamp);
        
        // Create destination immutables for Bob
        IBaseEscrow.Immutables memory dstImmutables = IBaseEscrow.Immutables({
            orderHash: bytes32(0),
            hashlock: hashlock,
            maker: Address.wrap(uint160(BOB)), // Bob is maker on destination
            taker: Address.wrap(uint160(alice)), // Alice is taker on destination
            token: Address.wrap(uint160(BMN_TOKEN)),
            amount: SWAP_AMOUNT,
            safetyDeposit: SAFETY_DEPOSIT,
            timelocks: createTimelocks()
        });
        
        string memory stateJson = vm.serializeBytes(json, "dstImmutables", abi.encode(dstImmutables));
        vm.writeJson(stateJson, STATE_FILE);
        
        console.log("State saved to:", STATE_FILE);
        vm.stopBroadcast();
    }

    function createDstEscrow() internal {
        console.log("--- Creating Destination Escrow on Etherlink ---");
        
        // Load state
        string memory stateJson = vm.readFile(STATE_FILE);
        bytes memory dstImmutablesData = vm.parseJsonBytes(stateJson, ".dstImmutables");
        IBaseEscrow.Immutables memory dstImmutables = abi.decode(dstImmutablesData, (IBaseEscrow.Immutables));
        
        // Get Bob's private key
        uint256 bobKey = vm.envUint("RESOLVER_PRIVATE_KEY");
        address bob = vm.addr(bobKey);
        require(bob == BOB, "Bob address mismatch");

        vm.startBroadcast(bobKey);

        // Check balance
        uint256 balance = IERC20(BMN_TOKEN).balanceOf(bob);
        console.log("Bob BMN balance:", balance / 1e6, "BMN");
        require(balance >= SWAP_AMOUNT, "Insufficient BMN balance");

        // Approve token transfer
        IERC20(BMN_TOKEN).approve(FACTORY, SWAP_AMOUNT);
        console.log("Approved", SWAP_AMOUNT / 1e6, "BMN to factory");

        // Update timelocks with current timestamp
        dstImmutables.timelocks = dstImmutables.timelocks.setDeployedAt(block.timestamp);

        // Deploy destination escrow (Bob provides safety deposit)
        console.log("Bob providing safety deposit:", SAFETY_DEPOSIT / 1e6, "BMN");
        uint256 srcCancellationTimestamp = dstImmutables.timelocks.get(TimelocksLib.Stage.SrcCancellation);
        address dstEscrow = IEscrowFactory(FACTORY).createDstEscrow{value: SAFETY_DEPOSIT}(
            dstImmutables, 
            srcCancellationTimestamp
        );
        
        console.log("Destination escrow deployed at:", dstEscrow);

        // Update state file
        string memory json = "state";
        string memory newState = vm.readFile(STATE_FILE);
        vm.serializeString(json, "existing", newState);
        vm.serializeAddress(json, "dstEscrow", dstEscrow);
        vm.serializeUint(json, "deployedTimelocks", Timelocks.unwrap(dstImmutables.timelocks));
        string memory updatedJson = vm.serializeUint(json, "dstDeployTime", block.timestamp);
        vm.writeJson(updatedJson, STATE_FILE);

        vm.stopBroadcast();
    }

    function withdrawDst() internal {
        console.log("--- Withdrawing from Destination Escrow (Alice reveals secret) ---");
        
        // Load state
        string memory stateJson = vm.readFile(STATE_FILE);
        address dstEscrow = vm.parseJsonAddress(stateJson, ".existing.dstEscrow");
        bytes32 secret = vm.parseJsonBytes32(stateJson, ".existing.secret");
        
        // Get Alice's private key
        uint256 aliceKey = vm.envUint("ALICE_PRIVATE_KEY");
        address alice = vm.addr(aliceKey);

        vm.startBroadcast(aliceKey);

        // Check balance before
        uint256 balanceBefore = IERC20(BMN_TOKEN).balanceOf(alice);
        console.log("Alice BMN balance before:", balanceBefore / 1e6);

        // Load destination immutables
        bytes memory dstImmutablesData = vm.parseJsonBytes(stateJson, ".existing.dstImmutables");
        IBaseEscrow.Immutables memory dstImmutables = abi.decode(dstImmutablesData, (IBaseEscrow.Immutables));
        
        // Use deployed timelocks
        uint256 deployedTimelocks = vm.parseJsonUint(stateJson, ".existing.deployedTimelocks");
        dstImmutables.timelocks = Timelocks.wrap(deployedTimelocks);
        
        // Withdraw
        IBaseEscrow(dstEscrow).withdraw(secret, dstImmutables);
        
        // Check balance after
        uint256 balanceAfter = IERC20(BMN_TOKEN).balanceOf(alice);
        console.log("Alice BMN balance after:", balanceAfter / 1e6);
        console.log("Alice received:", (balanceAfter - balanceBefore) / 1e6, "BMN");

        vm.stopBroadcast();
    }

    function withdrawSrc() internal {
        console.log("--- Withdrawing from Source Escrow (Bob uses revealed secret) ---");
        
        // Load state
        string memory stateJson = vm.readFile(STATE_FILE);
        address srcEscrow = vm.parseJsonAddress(stateJson, ".existing.srcEscrow");
        bytes32 secret = vm.parseJsonBytes32(stateJson, ".existing.secret");
        
        // Get Bob's private key
        uint256 bobKey = vm.envUint("RESOLVER_PRIVATE_KEY");
        address bob = vm.addr(bobKey);

        vm.startBroadcast(bobKey);

        console.log("Using secret:", vm.toString(secret));

        // Check balance before
        uint256 balanceBefore = IERC20(BMN_TOKEN).balanceOf(bob);
        console.log("Bob BMN balance before:", balanceBefore / 1e6);

        // Load source immutables
        bytes memory srcImmutablesData = vm.parseJsonBytes(stateJson, ".existing.srcImmutables");
        IBaseEscrow.Immutables memory srcImmutables = abi.decode(srcImmutablesData, (IBaseEscrow.Immutables));
        
        // Update timelocks with deployment timestamp
        uint256 srcDeployTime = vm.parseJsonUint(stateJson, ".existing.srcDeployTime");
        srcImmutables.timelocks = srcImmutables.timelocks.setDeployedAt(srcDeployTime);
        
        // Withdraw
        IBaseEscrow(srcEscrow).withdraw(secret, srcImmutables);
        
        // Check balance after
        uint256 balanceAfter = IERC20(BMN_TOKEN).balanceOf(bob);
        console.log("Bob BMN balance after:", balanceAfter / 1e6);
        console.log("Bob received:", (balanceAfter - balanceBefore) / 1e6, "BMN");

        vm.stopBroadcast();
    }

    function checkBalances() internal view {
        console.log("--- Checking BMN Balances ---");
        
        uint256 aliceBalance = IERC20(BMN_TOKEN).balanceOf(ALICE);
        uint256 bobBalance = IERC20(BMN_TOKEN).balanceOf(BOB);
        
        console.log("Alice BMN:", aliceBalance / 1e6);
        console.log("Bob BMN:", bobBalance / 1e6);
        
        console.log("\nFactory:", FACTORY);
        console.log("BMN Token:", BMN_TOKEN);
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