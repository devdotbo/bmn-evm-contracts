// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import "../contracts/SimplifiedEscrowFactory.sol";
import "../contracts/interfaces/IBaseEscrow.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { Address, AddressLib } from "solidity-utils/contracts/libraries/AddressLib.sol";
import { ImmutablesLib } from "../contracts/libraries/ImmutablesLib.sol";
import { Timelocks, TimelocksLib } from "../contracts/libraries/TimelocksLib.sol";

/**
 * @title TestBMNProtocol
 * @notice Comprehensive testing script for BMN Protocol on mainnet
 * @dev Run with: forge script script/TestBMNProtocol.s.sol --rpc-url $RPC_URL --broadcast
 */
contract TestBMNProtocol is Script {
    using AddressLib for Address;
    using ImmutablesLib for IBaseEscrow.Immutables;
    using TimelocksLib for Timelocks;
    
    // Test configuration
    struct TestConfig {
        address factory;
        address tokenA;
        address tokenB;
        uint256 amountA;
        uint256 amountB;
        address maker;
        address resolver;
        bytes32 secret;
        bytes32 hashlock;
    }
    
    TestConfig public config;
    
    // Test results tracking
    bool public resolverValidationPassed;
    bool public pauseMechanismPassed;
    bool public escrowCreationPassed;
    bool public withdrawalPassed;
    bool public cancellationPassed;
    
    function setUp() public {
        // Load factory address from deployment
        string memory chainName = _getChainName();
        string memory deploymentPath = string.concat(
            "deployments/",
            chainName,
            "-secure-factory.json"
        );
        
        // Try to read deployment file
        try vm.readFile(deploymentPath) returns (string memory json) {
            config.factory = vm.parseJsonAddress(json, ".factory");
            console.log("Loaded factory from deployment:", config.factory);
        } catch {
            console.log("No deployment found, using deployed addresses");
            // Newly deployed addresses
            if (block.chainid == 8453) { // Base
                config.factory = 0xd599b1543467433F5A6f195Ccc4E01FcbF5AA157;
            } else if (block.chainid == 10) { // Optimism
                config.factory = 0xA6342E61d1a0897A31a1ABAFB4B1669C0A5eaa56;
            }
        }
        
        // Test configuration
        config.tokenA = address(0); // Use native ETH for testing
        config.tokenB = address(0); // Use native ETH for testing
        config.amountA = 0.001 ether; // Small test amount
        config.amountB = 0.001 ether; // Small test amount
        config.maker = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266; // Test wallet
        config.resolver = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC; // Test resolver
        config.secret = keccak256("test_secret_123");
        config.hashlock = keccak256(abi.encodePacked(config.secret));
    }
    
    function run() public {
        console.log("=== BMN Protocol Mainnet Testing ===");
        console.log("Chain ID:", block.chainid);
        console.log("Factory:", config.factory);
        console.log("");
        
        // Run test suite
        testResolverValidation();
        testEmergencyPause();
        testEscrowCreation();
        testWithdrawal();
        testCancellation();
        
        // Print results
        printTestResults();
    }
    
    /**
     * @notice Test 1: Resolver Validation
     */
    function testResolverValidation() public {
        console.log("[TEST 1] Resolver Validation");
        
        SimplifiedEscrowFactory factory = SimplifiedEscrowFactory(config.factory);
        
        // Check if owner is whitelisted
        bool ownerWhitelisted = factory.whitelistedResolvers(config.maker);
        console.log("  Owner whitelisted:", ownerWhitelisted);
        
        // Try to create escrow with non-whitelisted address
        uint256 privateKey = vm.envUint("TEST_PRIVATE_KEY_NON_WHITELISTED");
        vm.startBroadcast(privateKey);
        
        IBaseEscrow.Immutables memory immutables = _createTestImmutables();
        
        try factory.createDstEscrow{value: config.amountB}(immutables) {
            console.log("  [FAIL] Non-whitelisted resolver could create escrow!");
            resolverValidationPassed = false;
        } catch {
            console.log("  [PASS] Non-whitelisted resolver rejected");
            resolverValidationPassed = true;
        }
        
        vm.stopBroadcast();
    }
    
    /**
     * @notice Test 2: Emergency Pause Mechanism
     */
    function testEmergencyPause() public {
        console.log("\n[TEST 2] Emergency Pause Mechanism");
        
        SimplifiedEscrowFactory factory = SimplifiedEscrowFactory(config.factory);
        uint256 ownerKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        
        vm.startBroadcast(ownerKey);
        
        // Test pause
        factory.pause();
        bool isPaused = factory.emergencyPaused();
        console.log("  Protocol paused:", isPaused);
        
        if (!isPaused) {
            console.log("  [FAIL] Pause did not work");
            pauseMechanismPassed = false;
            vm.stopBroadcast();
            return;
        }
        
        // Try to create escrow while paused
        IBaseEscrow.Immutables memory immutables = _createTestImmutables();
        
        try factory.createDstEscrow{value: config.amountB}(immutables) {
            console.log("  [FAIL] Could create escrow while paused!");
            pauseMechanismPassed = false;
        } catch {
            console.log("  [PASS] Escrow creation blocked while paused");
            pauseMechanismPassed = true;
        }
        
        // Unpause
        factory.unpause();
        isPaused = factory.emergencyPaused();
        console.log("  Protocol unpaused:", !isPaused);
        
        vm.stopBroadcast();
    }
    
    /**
     * @notice Test 3: Escrow Creation
     */
    function testEscrowCreation() public {
        console.log("\n[TEST 3] Escrow Creation");
        
        SimplifiedEscrowFactory factory = SimplifiedEscrowFactory(config.factory);
        uint256 resolverKey = vm.envUint("DEPLOYER_PRIVATE_KEY"); // Using owner as resolver for test
        
        vm.startBroadcast(resolverKey);
        
        IBaseEscrow.Immutables memory immutables = _createTestImmutables();
        
        // Calculate expected address
        address expectedAddress = factory.addressOfEscrow(immutables, false);
        console.log("  Expected escrow address:", expectedAddress);
        
        // Create destination escrow
        try factory.createDstEscrow{value: config.amountB + 0.01 ether}(immutables) returns (address escrow) {
            console.log("  [PASS] Escrow created at:", escrow);
            console.log("  Address matches prediction:", escrow == expectedAddress);
            escrowCreationPassed = true;
            
            // Check balance
            uint256 escrowBalance = escrow.balance;
            console.log("  Escrow balance:", escrowBalance);
        } catch Error(string memory reason) {
            console.log("  [FAIL] Escrow creation failed:", reason);
            escrowCreationPassed = false;
        }
        
        vm.stopBroadcast();
    }
    
    /**
     * @notice Test 4: Withdrawal Flow
     */
    function testWithdrawal() public {
        console.log("\n[TEST 4] Withdrawal Flow");
        console.log("  [INFO] This test requires manual execution on live escrows");
        console.log("  Steps to test withdrawal:");
        console.log("  1. Create matching escrows on both chains");
        console.log("  2. Reveal secret on destination chain");
        console.log("  3. Use revealed secret to withdraw on source chain");
        console.log("  4. Verify both withdrawals succeeded");
        withdrawalPassed = true; // Mark as passed for now
    }
    
    /**
     * @notice Test 5: Cancellation Flow
     */
    function testCancellation() public {
        console.log("\n[TEST 5] Cancellation Flow");
        console.log("  [INFO] This test requires waiting for timelock expiry");
        console.log("  Steps to test cancellation:");
        console.log("  1. Create escrow with short timelock (for testing)");
        console.log("  2. Wait for cancellation timelock to expire");
        console.log("  3. Call cancel() function");
        console.log("  4. Verify funds returned to maker/resolver");
        cancellationPassed = true; // Mark as passed for now
    }
    
    /**
     * @notice Print test results summary
     */
    function printTestResults() public view {
        console.log("\n=== TEST RESULTS SUMMARY ===");
        console.log("Resolver Validation:", resolverValidationPassed ? "[PASS]" : "[FAIL]");
        console.log("Emergency Pause:", pauseMechanismPassed ? "[PASS]" : "[FAIL]");
        console.log("Escrow Creation:", escrowCreationPassed ? "[PASS]" : "[FAIL]");
        console.log("Withdrawal Flow:", withdrawalPassed ? "[MANUAL]" : "[PENDING]");
        console.log("Cancellation Flow:", cancellationPassed ? "[MANUAL]" : "[PENDING]");
        
        uint256 passedTests = 0;
        if (resolverValidationPassed) passedTests++;
        if (pauseMechanismPassed) passedTests++;
        if (escrowCreationPassed) passedTests++;
        
        console.log("\nAutomated Tests Passed:", passedTests, "/ 3");
        
        if (passedTests == 3) {
            console.log("\n[SUCCESS] All automated tests passed!");
            console.log("Protocol is ready for limited mainnet testing with small amounts.");
        } else {
            console.log("\n[WARNING] Some tests failed. Review and fix before mainnet use.");
        }
        
        console.log("\n=== RECOMMENDATIONS ===");
        console.log("1. Start with 0.001 ETH test transactions");
        console.log("2. Monitor all events carefully");
        console.log("3. Have emergency pause ready");
        console.log("4. Test between known wallets first");
        console.log("5. Gradually increase amounts only after successful tests");
    }
    
    /**
     * @notice Helper: Create test immutables
     */
    function _createTestImmutables() internal view returns (IBaseEscrow.Immutables memory) {
        // Timelocks is a simple struct wrapping uint256, no memory needed
        Timelocks timelocks = Timelocks({
            timelocks: uint256(0)
        });
        
        // Set reasonable test timelocks (all in seconds from deployment)
        timelocks = timelocks.setTimelock(TimelocksLib.Stage.SrcWithdrawal, 300); // 5 minutes
        timelocks = timelocks.setTimelock(TimelocksLib.Stage.SrcPublicWithdrawal, 600); // 10 minutes
        timelocks = timelocks.setTimelock(TimelocksLib.Stage.SrcCancellation, 900); // 15 minutes
        timelocks = timelocks.setTimelock(TimelocksLib.Stage.SrcPublicCancellation, 1200); // 20 minutes
        timelocks = timelocks.setTimelock(TimelocksLib.Stage.DstWithdrawal, 300); // 5 minutes
        timelocks = timelocks.setTimelock(TimelocksLib.Stage.DstCancellation, 900); // 15 minutes
        
        return IBaseEscrow.Immutables({
            orderHash: keccak256("test_order"),
            hashlock: config.hashlock,
            maker: Address.wrap(uint160(config.maker)),
            taker: Address.wrap(uint160(config.resolver)),
            token: Address.wrap(uint160(config.tokenB)),
            amount: config.amountB,
            safetyDeposit: 0.01 ether,
            timelocks: timelocks
        });
    }
    
    /**
     * @notice Helper: Get chain name
     */
    function _getChainName() internal view returns (string memory) {
        uint256 chainId = block.chainid;
        if (chainId == 8453) return "base";
        if (chainId == 10) return "optimism";
        if (chainId == 42793) return "etherlink";
        if (chainId == 31337) return "local";
        return "unknown";
    }
}