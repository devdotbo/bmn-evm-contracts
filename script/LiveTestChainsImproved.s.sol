// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { Vm } from "forge-std/Vm.sol";
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
 * @title LiveTestChainsImproved
 * @notice Improved script using 1inch's same-transaction deployment pattern
 * @dev This avoids CREATE2 address mismatches by ensuring consistent timestamps
 */
contract LiveTestChainsImproved is Script {
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
    uint256 constant SAFETY_DEPOSIT = 0.001 ether; // Small deposit for testing
    
    // Timelock configuration (in seconds) - optimized for 1-second block time
    uint256 constant SRC_WITHDRAWAL_START = 0;
    uint256 constant SRC_PUBLIC_WITHDRAWAL_START = 10; // 10 seconds
    uint256 constant SRC_CANCELLATION_START = 30; // 30 seconds
    uint256 constant SRC_PUBLIC_CANCELLATION_START = 45; // 45 seconds
    uint256 constant DST_WITHDRAWAL_START = 0;
    uint256 constant DST_PUBLIC_WITHDRAWAL_START = 10; // 10 seconds
    uint256 constant DST_CANCELLATION_START = 30; // 30 seconds

    // Private keys (Anvil defaults)
    uint256 constant ALICE_KEY = 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d;
    uint256 constant BOB_KEY = 0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a;

    // State file for cross-chain coordination  
    string constant STATE_FILE = "deployments/test-state-improved.json";

    function run() external {
        string memory action = vm.envOr("ACTION", string(""));
        
        if (bytes(action).length == 0) {
            console.log("========================================");
            console.log("Improved Live Cross-Chain Test (1inch Pattern)");
            console.log("========================================");
            console.log("");
            console.log("Usage:");
            console.log("  ACTION=create-src-escrow forge script script/LiveTestChainsImproved.s.sol --rpc-url http://localhost:8545 --broadcast");
            console.log("  ACTION=create-dst-escrow forge script script/LiveTestChainsImproved.s.sol --rpc-url http://localhost:8546 --broadcast");
            console.log("  ACTION=withdraw-dst forge script script/LiveTestChainsImproved.s.sol --rpc-url http://localhost:8546 --broadcast");
            console.log("  ACTION=withdraw-src forge script script/LiveTestChainsImproved.s.sol --rpc-url http://localhost:8545 --broadcast");
            console.log("  ACTION=check-balances forge script script/LiveTestChainsImproved.s.sol --rpc-url http://localhost:8545");
            return;
        }

        if (keccak256(bytes(action)) == keccak256(bytes("create-src-escrow"))) {
            createSrcEscrowImproved();
        } else if (keccak256(bytes(action)) == keccak256(bytes("create-dst-escrow"))) {
            createDstEscrowImproved();
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

    /**
     * @notice Creates source escrow using 1inch's same-transaction pattern
     * @dev Pre-funds address and deploys in same transaction for consistent timestamps
     */
    function createSrcEscrowImproved() internal {
        console.log("--- Creating Source Escrow (Improved Pattern) ---");
        
        Deployment memory chainA = loadDeployment("deployments/chainA.json");
        require(block.chainid == chainA.chainId, "Must run on Chain A");

        // Generate secret for the swap
        bytes32 secret = keccak256(abi.encodePacked("improved_test_secret", block.timestamp));
        bytes32 hashlock = keccak256(abi.encodePacked(secret));
        bytes32 orderHash = keccak256(abi.encodePacked("test_order", block.timestamp));

        // Create immutables WITHOUT deployment timestamp (will be set in same tx)
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

        vm.startBroadcast(ALICE_KEY);
        
        // CRITICAL: Update timelocks with current block.timestamp IN THE SAME TRANSACTION
        srcImmutables.timelocks = srcImmutables.timelocks.setDeployedAt(block.timestamp);
        
        // Calculate expected address with the EXACT timestamp that will be used
        address expectedEscrow = EscrowFactory(chainA.factory).addressOfEscrowSrc(srcImmutables);
        console.log("Expected escrow address:", expectedEscrow);
        
        // Pre-fund the escrow address with safety deposit if needed
        if (SAFETY_DEPOSIT > 0) {
            (bool success,) = expectedEscrow.call{value: SAFETY_DEPOSIT}("");
            require(success, "Failed to pre-fund escrow with safety deposit");
            console.log("Pre-funded escrow with safety deposit:", SAFETY_DEPOSIT);
        }
        
        // Approve factory to take tokens
        IERC20(chainA.tokenA).approve(chainA.factory, SWAP_AMOUNT);
        
        // Create source escrow through test factory
        // The factory will use THE SAME block.timestamp when it calls setDeployedAt internally
        TestEscrowFactory testFactory = TestEscrowFactory(chainA.factory);
        address actualEscrow = testFactory.createSrcEscrowForTesting(srcImmutables, SWAP_AMOUNT);
        
        console.log("Actual escrow deployed at:", actualEscrow);
        
        // Verify addresses match
        require(actualEscrow == expectedEscrow, "Address mismatch despite same-transaction pattern!");
        console.log("SUCCESS: Addresses match! Pattern works correctly");
        
        vm.stopBroadcast();
        
        // Save state for next steps
        string memory json = string.concat(
            '{\n',
            '  "secret": "', vm.toString(secret), '",\n',
            '  "hashlock": "', vm.toString(hashlock), '",\n',
            '  "orderHash": "', vm.toString(orderHash), '",\n',
            '  "srcEscrow": "', vm.toString(actualEscrow), '",\n',
            '  "srcDeployTime": ', vm.toString(block.timestamp), '\n',
            '}'
        );
        vm.writeFile(STATE_FILE, json);
        console.log("State saved to:", STATE_FILE);
    }

    /**
     * @notice Creates destination escrow with improved pattern
     * @dev Uses event to get actual deployed address
     */
    function createDstEscrowImproved() internal {
        console.log("--- Creating Destination Escrow (Improved) ---");
        
        Deployment memory chainB = loadDeployment("deployments/chainB.json");
        require(block.chainid == chainB.chainId, "Must run on Chain B");

        // Load state
        string memory json = vm.readFile(STATE_FILE);
        bytes32 orderHash = vm.parseJsonBytes32(json, ".orderHash");
        bytes32 hashlock = vm.parseJsonBytes32(json, ".hashlock");
        uint256 srcDeployTime = vm.parseJsonUint(json, ".srcDeployTime");

        // Create destination immutables
        IBaseEscrow.Immutables memory dstImmutables = IBaseEscrow.Immutables({
            orderHash: orderHash,
            hashlock: hashlock,
            maker: Address.wrap(uint160(chainB.bob)), // Bob provides Token B
            taker: Address.wrap(uint160(chainB.alice)), // Alice withdraws with secret
            token: Address.wrap(uint160(chainB.tokenB)),
            amount: SWAP_AMOUNT,
            safetyDeposit: SAFETY_DEPOSIT,
            timelocks: createTimelocks()
        });

        vm.startBroadcast(BOB_KEY);
        
        // Approve tokens
        IERC20(chainB.tokenB).approve(chainB.factory, SWAP_AMOUNT);
        
        console.log("Bob's Token B balance before creating escrow:", IERC20(chainB.tokenB).balanceOf(chainB.bob) / 1e18);
        
        // Record logs to capture the DstEscrowCreated event
        vm.recordLogs();
        
        // Create destination escrow with safety deposit
        EscrowFactory(chainB.factory).createDstEscrow{value: SAFETY_DEPOSIT}(
            dstImmutables,
            srcDeployTime + SRC_CANCELLATION_START
        );
        
        console.log("Bob's Token B balance after creating escrow:", IERC20(chainB.tokenB).balanceOf(chainB.bob) / 1e18);
        
        // Get the actual deployed address from event
        Vm.Log[] memory logs = vm.getRecordedLogs();
        address actualDstEscrow = address(0);
        
        for (uint i = 0; i < logs.length; i++) {
            // DstEscrowCreated event signature (Address type is encoded as uint256)
            if (logs[i].topics[0] == keccak256("DstEscrowCreated(address,bytes32,uint256)")) {
                // Event data contains: address escrow, bytes32 hashlock, Address taker (uint256)
                // Decode the first 32 bytes as address (padded to 32 bytes)
                bytes memory data = logs[i].data;
                assembly {
                    actualDstEscrow := mload(add(data, 32))
                }
                console.log("Found DstEscrowCreated event with address:", actualDstEscrow);
                break;
            }
        }
        
        require(actualDstEscrow != address(0), "DstEscrowCreated event not found");
        
        // Also calculate what the factory thinks the address should be
        uint256 deployTimestamp = block.timestamp;
        dstImmutables.timelocks = dstImmutables.timelocks.setDeployedAt(deployTimestamp);
        address calculatedAddress = EscrowFactory(chainB.factory).addressOfEscrowDst(dstImmutables);
        
        console.log("Event-reported address:", actualDstEscrow);
        console.log("Factory-calculated address:", calculatedAddress);
        console.log("Addresses match:", actualDstEscrow == calculatedAddress);
        
        // Check escrow balance immediately after deployment
        uint256 escrowBalance = IERC20(chainB.tokenB).balanceOf(actualDstEscrow);
        console.log("Escrow Token B balance right after deployment:", escrowBalance / 1e18);
        require(escrowBalance == SWAP_AMOUNT, "Escrow doesn't have expected tokens!");
        
        vm.stopBroadcast();
        
        // Update state file with actual address from event
        string memory updatedState = string.concat(
            '{',
            '"secret": "', vm.toString(bytes32(vm.parseJsonBytes32(json, ".secret"))), '",',
            '"hashlock": "', vm.toString(hashlock), '",',
            '"orderHash": "', vm.toString(orderHash), '",',
            '"srcEscrow": "', vm.toString(vm.parseJsonAddress(json, ".srcEscrow")), '",',
            '"srcDeployTime": ', vm.toString(srcDeployTime), ',',
            '"dstEscrow": "', vm.toString(actualDstEscrow), '",', // Use event address
            '"dstDeployTime": ', vm.toString(deployTimestamp),
            '}'
        );
        vm.writeFile(STATE_FILE, updatedState);
        console.log("State file updated with actual destination escrow address");
    }

    // Withdraw functions remain the same
    function withdrawDst() internal {
        console.log("--- Withdrawing from Destination Escrow ---");
        
        Deployment memory chainB = loadDeployment("deployments/chainB.json");
        require(block.chainid == chainB.chainId, "Must run on Chain B");

        // Load state
        string memory json = vm.readFile(STATE_FILE);
        bytes32 secret = vm.parseJsonBytes32(json, ".secret");
        bytes32 orderHash = vm.parseJsonBytes32(json, ".orderHash");
        bytes32 hashlock = vm.parseJsonBytes32(json, ".hashlock");
        address dstEscrow = vm.parseJsonAddress(json, ".dstEscrow");
        uint256 dstDeployTime = vm.parseJsonUint(json, ".dstDeployTime");

        IBaseEscrow.Immutables memory dstImmutables = IBaseEscrow.Immutables({
            orderHash: orderHash,
            hashlock: hashlock,
            maker: Address.wrap(uint160(chainB.bob)),
            taker: Address.wrap(uint160(chainB.alice)),
            token: Address.wrap(uint160(chainB.tokenB)),
            amount: SWAP_AMOUNT,
            safetyDeposit: SAFETY_DEPOSIT,
            timelocks: createTimelocks().setDeployedAt(dstDeployTime)
        });

        vm.startBroadcast(ALICE_KEY);
        
        uint256 aliceBalanceBefore = IERC20(chainB.tokenB).balanceOf(chainB.alice);
        console.log("Alice balance before:", aliceBalanceBefore / 1e18);
        
        // Debug info before withdrawal
        console.log("Escrow address:", dstEscrow);
        console.log("Escrow token balance:", IERC20(chainB.tokenB).balanceOf(dstEscrow) / 1e18);
        console.log("Calling as Alice:", chainB.alice);
        
        // Withdraw reveals secret
        try IBaseEscrow(dstEscrow).withdraw(secret, dstImmutables) {
            uint256 aliceBalanceAfter = IERC20(chainB.tokenB).balanceOf(chainB.alice);
            console.log("Alice received:", (aliceBalanceAfter - aliceBalanceBefore) / 1e18, "Token B");
            
            // Verify Alice actually received tokens
            require(aliceBalanceAfter > aliceBalanceBefore, "Alice didn't receive tokens!");
        } catch Error(string memory reason) {
            console.log("Withdrawal failed:", reason);
            revert(string.concat("Destination withdrawal failed: ", reason));
        } catch (bytes memory) {
            console.log("Withdrawal failed with low-level error");
            revert("Destination withdrawal failed with low-level error");
        }
        
        vm.stopBroadcast();
    }

    function withdrawSrc() internal {
        console.log("--- Withdrawing from Source Escrow ---");
        
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
        console.log("Bob balance before:", bobBalanceBefore / 1e18);
        
        // Withdraw with revealed secret
        IBaseEscrow(srcEscrow).withdraw(secret, srcImmutables);
        
        uint256 bobBalanceAfter = IERC20(chainA.tokenA).balanceOf(chainA.bob);
        console.log("Bob received:", (bobBalanceAfter - bobBalanceBefore) / 1e18, "Token A");
        
        vm.stopBroadcast();
        
        console.log("SUCCESS: Cross-Chain Swap Complete!");
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