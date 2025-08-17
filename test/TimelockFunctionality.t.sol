// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { Test, console2 } from "forge-std/Test.sol";
import { Timelocks, TimelocksLib } from "../contracts/libraries/TimelocksLib.sol";

/**
 * @title TimelockFunctionalityTest
 * @notice Comprehensive test suite for the new TimelocksLib.pack() function and its integration
 * @dev Tests the complete lifecycle of timelocks from packing to usage in escrows
 */
contract TimelockFunctionalityTest is Test {
    using TimelocksLib for Timelocks;
    
    // Constants
    uint32 constant TIMESTAMP_TOLERANCE = 300; // 5 minutes tolerance
    uint32 constant DEPLOY_TIME = 1_700_000_000; // Example deployment timestamp
    uint256 constant RESCUE_DELAY = 604800; // 7 days in seconds
    
    // Test timelock values
    uint32 constant SRC_WITHDRAWAL = 3600; // 1 hour
    uint32 constant SRC_PUBLIC_WITHDRAWAL = 7200; // 2 hours
    uint32 constant SRC_CANCELLATION = 10800; // 3 hours
    uint32 constant SRC_PUBLIC_CANCELLATION = 14400; // 4 hours
    uint32 constant DST_WITHDRAWAL = 1800; // 30 minutes
    uint32 constant DST_PUBLIC_WITHDRAWAL = 5400; // 1.5 hours
    uint32 constant DST_CANCELLATION = 9000; // 2.5 hours
    
    // Test addresses
    address constant ALICE = address(0x1111);
    address constant BOB = address(0x2222);
    address constant RESOLVER = address(0x3333);
    
    function setUp() public {
        // Basic setup - no contract deployments needed for library tests
        vm.deal(ALICE, 10 ether);
        vm.deal(BOB, 10 ether);
    }
    
    /**
     * @notice Test 1: Pack function correctly packs all 7 timelock stages
     */
    function testPackFunction() public pure {
        TimelocksLib.TimelocksStruct memory timelocksStruct = TimelocksLib.TimelocksStruct({
            srcWithdrawal: SRC_WITHDRAWAL,
            srcPublicWithdrawal: SRC_PUBLIC_WITHDRAWAL,
            srcCancellation: SRC_CANCELLATION,
            srcPublicCancellation: SRC_PUBLIC_CANCELLATION,
            dstWithdrawal: DST_WITHDRAWAL,
            dstPublicWithdrawal: DST_PUBLIC_WITHDRAWAL,
            dstCancellation: DST_CANCELLATION
        });
        
        Timelocks packed = TimelocksLib.pack(timelocksStruct);
        
        // Verify raw packed value has correct bit layout
        uint256 rawValue = Timelocks.unwrap(packed);
        
        // Check each field is in the correct bit position
        assertEq(uint32(rawValue), SRC_WITHDRAWAL, "Bits 0-31: srcWithdrawal");
        assertEq(uint32(rawValue >> 32), SRC_PUBLIC_WITHDRAWAL, "Bits 32-63: srcPublicWithdrawal");
        assertEq(uint32(rawValue >> 64), SRC_CANCELLATION, "Bits 64-95: srcCancellation");
        assertEq(uint32(rawValue >> 96), SRC_PUBLIC_CANCELLATION, "Bits 96-127: srcPublicCancellation");
        assertEq(uint32(rawValue >> 128), DST_WITHDRAWAL, "Bits 128-159: dstWithdrawal");
        assertEq(uint32(rawValue >> 160), DST_PUBLIC_WITHDRAWAL, "Bits 160-191: dstPublicWithdrawal");
        assertEq(uint32(rawValue >> 192), DST_CANCELLATION, "Bits 192-223: dstCancellation");
        assertEq(uint32(rawValue >> 224), 0, "Bits 224-255: deployedAt (not set yet)");
    }
    
    /**
     * @notice Test 2: SetDeployedAt function correctly sets deployment timestamp
     */
    function testSetDeployedAt() public pure {
        TimelocksLib.TimelocksStruct memory timelocksStruct = TimelocksLib.TimelocksStruct({
            srcWithdrawal: SRC_WITHDRAWAL,
            srcPublicWithdrawal: SRC_PUBLIC_WITHDRAWAL,
            srcCancellation: SRC_CANCELLATION,
            srcPublicCancellation: SRC_PUBLIC_CANCELLATION,
            dstWithdrawal: DST_WITHDRAWAL,
            dstPublicWithdrawal: DST_PUBLIC_WITHDRAWAL,
            dstCancellation: DST_CANCELLATION
        });
        
        Timelocks packed = TimelocksLib.pack(timelocksStruct);
        
        // Set deployment timestamp
        packed = packed.setDeployedAt(DEPLOY_TIME);
        
        // Verify deployment timestamp is set correctly
        uint256 rawValue = Timelocks.unwrap(packed);
        uint32 extractedDeployTime = uint32(rawValue >> 224);
        assertEq(extractedDeployTime, DEPLOY_TIME, "DeployedAt should be set in bits 224-255");
        
        // Verify timelock offsets are preserved
        assertEq(uint32(rawValue), SRC_WITHDRAWAL, "srcWithdrawal should be preserved");
        assertEq(uint32(rawValue >> 192), DST_CANCELLATION, "dstCancellation should be preserved");
        
        // Test overwriting deployment timestamp
        uint32 newDeployTime = DEPLOY_TIME + 1000;
        packed = packed.setDeployedAt(newDeployTime);
        rawValue = Timelocks.unwrap(packed);
        extractedDeployTime = uint32(rawValue >> 224);
        assertEq(extractedDeployTime, newDeployTime, "DeployedAt should be overwritten");
    }
    
    /**
     * @notice Test 3: Unpacking via get() returns correct absolute timestamps
     */
    function testUnpackingWithGet() public pure {
        TimelocksLib.TimelocksStruct memory timelocksStruct = TimelocksLib.TimelocksStruct({
            srcWithdrawal: SRC_WITHDRAWAL,
            srcPublicWithdrawal: SRC_PUBLIC_WITHDRAWAL,
            srcCancellation: SRC_CANCELLATION,
            srcPublicCancellation: SRC_PUBLIC_CANCELLATION,
            dstWithdrawal: DST_WITHDRAWAL,
            dstPublicWithdrawal: DST_PUBLIC_WITHDRAWAL,
            dstCancellation: DST_CANCELLATION
        });
        
        Timelocks packed = TimelocksLib.pack(timelocksStruct);
        packed = packed.setDeployedAt(DEPLOY_TIME);
        
        // Test each stage's absolute timestamp
        assertEq(
            packed.get(TimelocksLib.Stage.SrcWithdrawal),
            DEPLOY_TIME + SRC_WITHDRAWAL,
            "SrcWithdrawal absolute time"
        );
        assertEq(
            packed.get(TimelocksLib.Stage.SrcPublicWithdrawal),
            DEPLOY_TIME + SRC_PUBLIC_WITHDRAWAL,
            "SrcPublicWithdrawal absolute time"
        );
        assertEq(
            packed.get(TimelocksLib.Stage.SrcCancellation),
            DEPLOY_TIME + SRC_CANCELLATION,
            "SrcCancellation absolute time"
        );
        assertEq(
            packed.get(TimelocksLib.Stage.SrcPublicCancellation),
            DEPLOY_TIME + SRC_PUBLIC_CANCELLATION,
            "SrcPublicCancellation absolute time"
        );
        assertEq(
            packed.get(TimelocksLib.Stage.DstWithdrawal),
            DEPLOY_TIME + DST_WITHDRAWAL,
            "DstWithdrawal absolute time"
        );
        assertEq(
            packed.get(TimelocksLib.Stage.DstPublicWithdrawal),
            DEPLOY_TIME + DST_PUBLIC_WITHDRAWAL,
            "DstPublicWithdrawal absolute time"
        );
        assertEq(
            packed.get(TimelocksLib.Stage.DstCancellation),
            DEPLOY_TIME + DST_CANCELLATION,
            "DstCancellation absolute time"
        );
    }
    
    /**
     * @notice Test 4: Maximum uint32 values handling
     */
    function testMaxValues() public pure {
        uint32 maxValue = type(uint32).max;
        
        TimelocksLib.TimelocksStruct memory timelocksStruct = TimelocksLib.TimelocksStruct({
            srcWithdrawal: maxValue,
            srcPublicWithdrawal: maxValue,
            srcCancellation: maxValue,
            srcPublicCancellation: maxValue,
            dstWithdrawal: maxValue,
            dstPublicWithdrawal: maxValue,
            dstCancellation: maxValue
        });
        
        Timelocks packed = TimelocksLib.pack(timelocksStruct);
        packed = packed.setDeployedAt(maxValue);
        
        // Verify packing preserves max values
        uint256 rawValue = Timelocks.unwrap(packed);
        assertEq(uint32(rawValue), maxValue, "Max srcWithdrawal");
        assertEq(uint32(rawValue >> 32), maxValue, "Max srcPublicWithdrawal");
        assertEq(uint32(rawValue >> 64), maxValue, "Max srcCancellation");
        assertEq(uint32(rawValue >> 96), maxValue, "Max srcPublicCancellation");
        assertEq(uint32(rawValue >> 128), maxValue, "Max dstWithdrawal");
        assertEq(uint32(rawValue >> 160), maxValue, "Max dstPublicWithdrawal");
        assertEq(uint32(rawValue >> 192), maxValue, "Max dstCancellation");
        assertEq(uint32(rawValue >> 224), maxValue, "Max deployedAt");
        
        // Test get() with max values (should not overflow)
        uint256 expectedTime = uint256(maxValue) + uint256(maxValue);
        assertEq(packed.get(TimelocksLib.Stage.SrcWithdrawal), expectedTime, "Max values should add without overflow");
        assertLt(expectedTime, type(uint64).max, "Result should fit in uint64");
    }
    
    /**
     * @notice Test 5: Zero values handling
     */
    function testZeroValues() public pure {
        TimelocksLib.TimelocksStruct memory timelocksStruct = TimelocksLib.TimelocksStruct({
            srcWithdrawal: 0,
            srcPublicWithdrawal: 0,
            srcCancellation: 0,
            srcPublicCancellation: 0,
            dstWithdrawal: 0,
            dstPublicWithdrawal: 0,
            dstCancellation: 0
        });
        
        Timelocks packed = TimelocksLib.pack(timelocksStruct);
        
        // Verify all bits are zero
        uint256 rawValue = Timelocks.unwrap(packed);
        assertEq(rawValue, 0, "All bits should be zero");
        
        // Set deployment time and verify get() returns deployedAt for all stages
        packed = packed.setDeployedAt(DEPLOY_TIME);
        
        assertEq(packed.get(TimelocksLib.Stage.SrcWithdrawal), DEPLOY_TIME, "Zero offset should return deployedAt");
        assertEq(packed.get(TimelocksLib.Stage.SrcPublicWithdrawal), DEPLOY_TIME, "Zero offset should return deployedAt");
        assertEq(packed.get(TimelocksLib.Stage.SrcCancellation), DEPLOY_TIME, "Zero offset should return deployedAt");
        assertEq(packed.get(TimelocksLib.Stage.SrcPublicCancellation), DEPLOY_TIME, "Zero offset should return deployedAt");
        assertEq(packed.get(TimelocksLib.Stage.DstWithdrawal), DEPLOY_TIME, "Zero offset should return deployedAt");
        assertEq(packed.get(TimelocksLib.Stage.DstPublicWithdrawal), DEPLOY_TIME, "Zero offset should return deployedAt");
        assertEq(packed.get(TimelocksLib.Stage.DstCancellation), DEPLOY_TIME, "Zero offset should return deployedAt");
    }
    
    /**
     * @notice Test 6: Timestamp tolerance handling (srcWithdrawal acts as tolerance)
     */
    function testTimestampTolerance() public pure {
        // In the SimplifiedEscrowFactory, srcWithdrawal is used as timestamp tolerance
        // This test verifies that the pack() function correctly handles this
        
        TimelocksLib.TimelocksStruct memory timelocksStruct = TimelocksLib.TimelocksStruct({
            srcWithdrawal: TIMESTAMP_TOLERANCE, // Acts as tolerance
            srcPublicWithdrawal: SRC_PUBLIC_WITHDRAWAL,
            srcCancellation: SRC_CANCELLATION,
            srcPublicCancellation: SRC_PUBLIC_CANCELLATION,
            dstWithdrawal: DST_WITHDRAWAL,
            dstPublicWithdrawal: DST_PUBLIC_WITHDRAWAL,
            dstCancellation: DST_CANCELLATION
        });
        
        Timelocks packed = TimelocksLib.pack(timelocksStruct);
        packed = packed.setDeployedAt(DEPLOY_TIME);
        
        // Verify srcWithdrawal stores the tolerance value
        uint256 rawValue = Timelocks.unwrap(packed);
        assertEq(uint32(rawValue), TIMESTAMP_TOLERANCE, "srcWithdrawal should store tolerance");
        
        // When used with get(), it adds tolerance to deployment time
        uint256 toleranceEnd = packed.get(TimelocksLib.Stage.SrcWithdrawal);
        assertEq(toleranceEnd, DEPLOY_TIME + TIMESTAMP_TOLERANCE, "Tolerance period end time");
        
        // Simulate checking if current time is within tolerance
        uint256 currentTime = DEPLOY_TIME + 100; // Within tolerance
        assertTrue(currentTime <= toleranceEnd, "Should be within tolerance period");
        
        currentTime = DEPLOY_TIME + TIMESTAMP_TOLERANCE + 1; // Outside tolerance
        assertTrue(currentTime > toleranceEnd, "Should be outside tolerance period");
    }
    
    /**
     * @notice Test 7: Rescue period calculation
     */
    function testRescueCalculation() public pure {
        TimelocksLib.TimelocksStruct memory timelocksStruct = TimelocksLib.TimelocksStruct({
            srcWithdrawal: SRC_WITHDRAWAL,
            srcPublicWithdrawal: SRC_PUBLIC_WITHDRAWAL,
            srcCancellation: SRC_CANCELLATION,
            srcPublicCancellation: SRC_PUBLIC_CANCELLATION,
            dstWithdrawal: DST_WITHDRAWAL,
            dstPublicWithdrawal: DST_PUBLIC_WITHDRAWAL,
            dstCancellation: DST_CANCELLATION
        });
        
        Timelocks packed = TimelocksLib.pack(timelocksStruct);
        packed = packed.setDeployedAt(DEPLOY_TIME);
        
        // Test rescue start calculation
        uint256 rescueStart = packed.rescueStart(RESCUE_DELAY);
        assertEq(rescueStart, DEPLOY_TIME + RESCUE_DELAY, "Rescue should start at deployedAt + delay");
        
        // Test with zero rescue delay
        rescueStart = packed.rescueStart(0);
        assertEq(rescueStart, DEPLOY_TIME, "Zero delay should return deployedAt");
        
        // Test with max rescue delay
        uint256 maxDelay = type(uint32).max;
        rescueStart = packed.rescueStart(maxDelay);
        assertEq(rescueStart, uint256(DEPLOY_TIME) + maxDelay, "Max delay should calculate correctly");
    }
    
    /**
     * @notice Test 8: Pack/unpack roundtrip preserves data
     */
    function testPackUnpackRoundtrip() public pure {
        // Original values
        TimelocksLib.TimelocksStruct memory original = TimelocksLib.TimelocksStruct({
            srcWithdrawal: 111,
            srcPublicWithdrawal: 222,
            srcCancellation: 333,
            srcPublicCancellation: 444,
            dstWithdrawal: 555,
            dstPublicWithdrawal: 666,
            dstCancellation: 777
        });
        
        // Pack
        Timelocks packed = TimelocksLib.pack(original);
        packed = packed.setDeployedAt(888);
        
        // Extract raw values
        uint256 rawValue = Timelocks.unwrap(packed);
        
        // Reconstruct struct from raw value
        TimelocksLib.TimelocksStruct memory reconstructed = TimelocksLib.TimelocksStruct({
            srcWithdrawal: uint32(rawValue),
            srcPublicWithdrawal: uint32(rawValue >> 32),
            srcCancellation: uint32(rawValue >> 64),
            srcPublicCancellation: uint32(rawValue >> 96),
            dstWithdrawal: uint32(rawValue >> 128),
            dstPublicWithdrawal: uint32(rawValue >> 160),
            dstCancellation: uint32(rawValue >> 192)
        });
        
        // Verify all values match
        assertEq(reconstructed.srcWithdrawal, original.srcWithdrawal, "srcWithdrawal roundtrip");
        assertEq(reconstructed.srcPublicWithdrawal, original.srcPublicWithdrawal, "srcPublicWithdrawal roundtrip");
        assertEq(reconstructed.srcCancellation, original.srcCancellation, "srcCancellation roundtrip");
        assertEq(reconstructed.srcPublicCancellation, original.srcPublicCancellation, "srcPublicCancellation roundtrip");
        assertEq(reconstructed.dstWithdrawal, original.dstWithdrawal, "dstWithdrawal roundtrip");
        assertEq(reconstructed.dstPublicWithdrawal, original.dstPublicWithdrawal, "dstPublicWithdrawal roundtrip");
        assertEq(reconstructed.dstCancellation, original.dstCancellation, "dstCancellation roundtrip");
        
        // Verify deployedAt
        assertEq(uint32(rawValue >> 224), 888, "deployedAt roundtrip");
    }
    
    /**
     * @notice Test 9: Simulated Factory Integration
     * @dev Tests how the pack() function would be used in a factory context
     */
    function testSimulatedFactoryUsage() public pure {
        // Simulate how SimplifiedEscrowFactory would use pack()
        
        // Factory receives individual timelock values from order parameters
        uint32 srcWithdrawal = TIMESTAMP_TOLERANCE; // Used as tolerance
        uint32 srcPublicWithdrawal = SRC_PUBLIC_WITHDRAWAL;
        uint32 srcCancellation = SRC_CANCELLATION;
        uint32 srcPublicCancellation = SRC_PUBLIC_CANCELLATION;
        uint32 dstWithdrawal = DST_WITHDRAWAL;
        uint32 dstPublicWithdrawal = DST_PUBLIC_WITHDRAWAL;
        uint32 dstCancellation = DST_CANCELLATION;
        
        // Factory creates the struct
        TimelocksLib.TimelocksStruct memory timelocksStruct = TimelocksLib.TimelocksStruct({
            srcWithdrawal: srcWithdrawal,
            srcPublicWithdrawal: srcPublicWithdrawal,
            srcCancellation: srcCancellation,
            srcPublicCancellation: srcPublicCancellation,
            dstWithdrawal: dstWithdrawal,
            dstPublicWithdrawal: dstPublicWithdrawal,
            dstCancellation: dstCancellation
        });
        
        // Factory calls pack()
        Timelocks packed = TimelocksLib.pack(timelocksStruct);
        
        // Factory sets deployment time (using a constant for pure function)
        uint32 deploymentTime = DEPLOY_TIME; // Using constant instead of block.timestamp
        packed = packed.setDeployedAt(deploymentTime);
        
        // Verify the packed value contains all information
        uint256 rawValue = Timelocks.unwrap(packed);
        
        // Check that all values are properly packed
        assertEq(uint32(rawValue), srcWithdrawal, "Factory: srcWithdrawal packed");
        assertEq(uint32(rawValue >> 32), srcPublicWithdrawal, "Factory: srcPublicWithdrawal packed");
        assertEq(uint32(rawValue >> 64), srcCancellation, "Factory: srcCancellation packed");
        assertEq(uint32(rawValue >> 96), srcPublicCancellation, "Factory: srcPublicCancellation packed");
        assertEq(uint32(rawValue >> 128), dstWithdrawal, "Factory: dstWithdrawal packed");
        assertEq(uint32(rawValue >> 160), dstPublicWithdrawal, "Factory: dstPublicWithdrawal packed");
        assertEq(uint32(rawValue >> 192), dstCancellation, "Factory: dstCancellation packed");
        assertEq(uint32(rawValue >> 224), deploymentTime, "Factory: deployedAt packed");
        
        // This packed value would then be passed to the escrow constructor
        // The escrow would use get() to retrieve absolute timestamps
        
        // Example: Check if current time is within tolerance window
        uint256 toleranceWindow = packed.get(TimelocksLib.Stage.SrcWithdrawal);
        assertTrue(toleranceWindow == deploymentTime + TIMESTAMP_TOLERANCE, "Tolerance window calculation");
    }
    
    /**
     * @notice Test 10: Backward compatibility verification
     * @dev Ensures the new pack() function maintains compatibility with existing usage
     */
    function testBackwardCompatibility() public pure {
        // Test that the pack() function produces the same result as manual bit manipulation
        TimelocksLib.TimelocksStruct memory timelocksStruct = TimelocksLib.TimelocksStruct({
            srcWithdrawal: SRC_WITHDRAWAL,
            srcPublicWithdrawal: SRC_PUBLIC_WITHDRAWAL,
            srcCancellation: SRC_CANCELLATION,
            srcPublicCancellation: SRC_PUBLIC_CANCELLATION,
            dstWithdrawal: DST_WITHDRAWAL,
            dstPublicWithdrawal: DST_PUBLIC_WITHDRAWAL,
            dstCancellation: DST_CANCELLATION
        });
        
        // Pack using the new function
        Timelocks packedNew = TimelocksLib.pack(timelocksStruct);
        packedNew = packedNew.setDeployedAt(DEPLOY_TIME);
        
        // Manual packing (old way)
        uint256 packedOld = 0;
        packedOld |= uint256(SRC_WITHDRAWAL);
        packedOld |= uint256(SRC_PUBLIC_WITHDRAWAL) << 32;
        packedOld |= uint256(SRC_CANCELLATION) << 64;
        packedOld |= uint256(SRC_PUBLIC_CANCELLATION) << 96;
        packedOld |= uint256(DST_WITHDRAWAL) << 128;
        packedOld |= uint256(DST_PUBLIC_WITHDRAWAL) << 160;
        packedOld |= uint256(DST_CANCELLATION) << 192;
        packedOld |= uint256(DEPLOY_TIME) << 224;
        
        // Verify both methods produce identical results
        assertEq(Timelocks.unwrap(packedNew), packedOld, "Pack() should match manual packing");
        
        // Verify get() functions work identically
        Timelocks oldTimelocks = Timelocks.wrap(packedOld);
        
        for (uint i = 0; i < 7; i++) {
            TimelocksLib.Stage stage = TimelocksLib.Stage(i);
            assertEq(
                packedNew.get(stage),
                oldTimelocks.get(stage),
                string.concat("Stage ", vm.toString(i), " should match")
            );
        }
        
        // Verify rescue calculation compatibility
        assertEq(
            packedNew.rescueStart(RESCUE_DELAY),
            oldTimelocks.rescueStart(RESCUE_DELAY),
            "Rescue calculation should match"
        );
    }
    
    /**
     * @notice Test 11: Edge case - different values for each stage
     */
    function testDifferentValuesPerStage() public pure {
        // Use fibonacci-like sequence to ensure each value is unique
        TimelocksLib.TimelocksStruct memory timelocksStruct = TimelocksLib.TimelocksStruct({
            srcWithdrawal: 1,
            srcPublicWithdrawal: 2,
            srcCancellation: 3,
            srcPublicCancellation: 5,
            dstWithdrawal: 8,
            dstPublicWithdrawal: 13,
            dstCancellation: 21
        });
        
        Timelocks packed = TimelocksLib.pack(timelocksStruct);
        packed = packed.setDeployedAt(34); // Continue the sequence
        
        // Verify each value is distinct and correctly packed
        uint256 rawValue = Timelocks.unwrap(packed);
        
        assertEq(uint32(rawValue), 1, "Unique value 1");
        assertEq(uint32(rawValue >> 32), 2, "Unique value 2");
        assertEq(uint32(rawValue >> 64), 3, "Unique value 3");
        assertEq(uint32(rawValue >> 96), 5, "Unique value 5");
        assertEq(uint32(rawValue >> 128), 8, "Unique value 8");
        assertEq(uint32(rawValue >> 160), 13, "Unique value 13");
        assertEq(uint32(rawValue >> 192), 21, "Unique value 21");
        assertEq(uint32(rawValue >> 224), 34, "Unique value 34");
        
        // Verify get() returns correct absolute times
        assertEq(packed.get(TimelocksLib.Stage.SrcWithdrawal), 35, "34 + 1");
        assertEq(packed.get(TimelocksLib.Stage.SrcPublicWithdrawal), 36, "34 + 2");
        assertEq(packed.get(TimelocksLib.Stage.SrcCancellation), 37, "34 + 3");
        assertEq(packed.get(TimelocksLib.Stage.SrcPublicCancellation), 39, "34 + 5");
        assertEq(packed.get(TimelocksLib.Stage.DstWithdrawal), 42, "34 + 8");
        assertEq(packed.get(TimelocksLib.Stage.DstPublicWithdrawal), 47, "34 + 13");
        assertEq(packed.get(TimelocksLib.Stage.DstCancellation), 55, "34 + 21");
    }
    
    /**
     * @notice Test 12: Fuzz testing pack function
     */
    function testFuzzPack(
        uint32 srcWithdrawal,
        uint32 srcPublicWithdrawal,
        uint32 srcCancellation,
        uint32 srcPublicCancellation,
        uint32 dstWithdrawal,
        uint32 dstPublicWithdrawal,
        uint32 dstCancellation,
        uint32 deployedAt
    ) public pure {
        TimelocksLib.TimelocksStruct memory timelocksStruct = TimelocksLib.TimelocksStruct({
            srcWithdrawal: srcWithdrawal,
            srcPublicWithdrawal: srcPublicWithdrawal,
            srcCancellation: srcCancellation,
            srcPublicCancellation: srcPublicCancellation,
            dstWithdrawal: dstWithdrawal,
            dstPublicWithdrawal: dstPublicWithdrawal,
            dstCancellation: dstCancellation
        });
        
        Timelocks packed = TimelocksLib.pack(timelocksStruct);
        packed = packed.setDeployedAt(deployedAt);
        
        // Verify all values are preserved
        uint256 rawValue = Timelocks.unwrap(packed);
        
        assertEq(uint32(rawValue), srcWithdrawal, "Fuzz: srcWithdrawal preserved");
        assertEq(uint32(rawValue >> 32), srcPublicWithdrawal, "Fuzz: srcPublicWithdrawal preserved");
        assertEq(uint32(rawValue >> 64), srcCancellation, "Fuzz: srcCancellation preserved");
        assertEq(uint32(rawValue >> 96), srcPublicCancellation, "Fuzz: srcPublicCancellation preserved");
        assertEq(uint32(rawValue >> 128), dstWithdrawal, "Fuzz: dstWithdrawal preserved");
        assertEq(uint32(rawValue >> 160), dstPublicWithdrawal, "Fuzz: dstPublicWithdrawal preserved");
        assertEq(uint32(rawValue >> 192), dstCancellation, "Fuzz: dstCancellation preserved");
        assertEq(uint32(rawValue >> 224), deployedAt, "Fuzz: deployedAt preserved");
        
        // Verify get() calculations
        assertEq(
            packed.get(TimelocksLib.Stage.SrcWithdrawal),
            uint256(deployedAt) + uint256(srcWithdrawal),
            "Fuzz: get() calculation correct"
        );
    }
    
    /**
     * @notice Test summary and documentation
     */
    function testDocumentationAndSummary() public pure {
        console2.log("=== Timelock Functionality Test Summary ===");
        console2.log("");
        console2.log("Test Coverage:");
        console2.log("1. pack() function correctly packs all 7 stages");
        console2.log("2. setDeployedAt() sets timestamp in bits 224-255");
        console2.log("3. get() returns correct absolute timestamps");
        console2.log("4. Maximum uint32 values handled without overflow");
        console2.log("5. Zero values handled correctly");
        console2.log("6. srcWithdrawal used as timestamp tolerance");
        console2.log("7. rescueStart() calculates rescue period correctly");
        console2.log("8. Pack/unpack roundtrip preserves all data");
        console2.log("9. Factory integration uses pack() correctly");
        console2.log("10. Backward compatibility maintained");
        console2.log("11. Unique values per stage handled correctly");
        console2.log("12. Fuzz testing confirms robustness");
        console2.log("");
        console2.log("Key Findings:");
        console2.log("- Bit layout: 7 stages (32 bits each) + deployedAt (32 bits)");
        console2.log("- srcWithdrawal doubles as timestamp tolerance");
        console2.log("- All 256 bits utilized, no room for additional data");
        console2.log("- Arithmetic is unchecked but safe (uint32 + uint32 < uint256)");
        console2.log("- Pack function simplifies factory implementation");
        console2.log("");
        console2.log("Verified Bit Layout:");
        console2.log("  Bits 0-31:    srcWithdrawal (tolerance)");
        console2.log("  Bits 32-63:   srcPublicWithdrawal");
        console2.log("  Bits 64-95:   srcCancellation");
        console2.log("  Bits 96-127:  srcPublicCancellation");
        console2.log("  Bits 128-159: dstWithdrawal");
        console2.log("  Bits 160-191: dstPublicWithdrawal");
        console2.log("  Bits 192-223: dstCancellation");
        console2.log("  Bits 224-255: deployedAt");
    }
}