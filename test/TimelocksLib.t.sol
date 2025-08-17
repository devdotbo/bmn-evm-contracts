// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Test.sol";
import { Timelocks, TimelocksLib } from "../contracts/libraries/TimelocksLib.sol";

/**
 * @title TimelocksLibTest
 * @notice Comprehensive test suite for TimelocksLib covering all functionality
 * @dev Tests bit packing, unpacking, and timestamp calculations
 */
contract TimelocksLibTest is Test {
    using TimelocksLib for Timelocks;
    
    // Test constants
    uint32 constant DEPLOY_TIME = 1_700_000_000; // Example timestamp
    uint32 constant SRC_WITHDRAWAL_OFFSET = 3600; // 1 hour
    uint32 constant SRC_PUBLIC_WITHDRAWAL_OFFSET = 7200; // 2 hours
    uint32 constant SRC_CANCELLATION_OFFSET = 10800; // 3 hours
    uint32 constant SRC_PUBLIC_CANCELLATION_OFFSET = 14400; // 4 hours
    uint32 constant DST_WITHDRAWAL_OFFSET = 1800; // 30 minutes
    uint32 constant DST_PUBLIC_WITHDRAWAL_OFFSET = 5400; // 1.5 hours
    uint32 constant DST_CANCELLATION_OFFSET = 9000; // 2.5 hours
    
    // Maximum values for boundary testing
    uint32 constant MAX_UINT32 = type(uint32).max;
    uint256 constant MAX_UINT256 = type(uint256).max;
    
    /**
     * @notice Test 1: Pack and unpack roundtrip preserves data
     * @dev Verifies that packing timelocks and then unpacking them yields the original values
     */
    function testPackUnpack() public {
        // Pack timelocks manually using bit shifts
        uint256 packed = 0;
        packed |= uint256(SRC_WITHDRAWAL_OFFSET); // bits 0-31
        packed |= uint256(SRC_PUBLIC_WITHDRAWAL_OFFSET) << 32; // bits 32-63
        packed |= uint256(SRC_CANCELLATION_OFFSET) << 64; // bits 64-95
        packed |= uint256(SRC_PUBLIC_CANCELLATION_OFFSET) << 96; // bits 96-127
        packed |= uint256(DST_WITHDRAWAL_OFFSET) << 128; // bits 128-159
        packed |= uint256(DST_PUBLIC_WITHDRAWAL_OFFSET) << 160; // bits 160-191
        packed |= uint256(DST_CANCELLATION_OFFSET) << 192; // bits 192-223
        packed |= uint256(DEPLOY_TIME) << 224; // bits 224-255
        
        Timelocks timelocks = Timelocks.wrap(packed);
        
        // Verify each stage unpacks correctly
        assertEq(
            timelocks.get(TimelocksLib.Stage.SrcWithdrawal),
            DEPLOY_TIME + SRC_WITHDRAWAL_OFFSET,
            "SrcWithdrawal should unpack correctly"
        );
        assertEq(
            timelocks.get(TimelocksLib.Stage.SrcPublicWithdrawal),
            DEPLOY_TIME + SRC_PUBLIC_WITHDRAWAL_OFFSET,
            "SrcPublicWithdrawal should unpack correctly"
        );
        assertEq(
            timelocks.get(TimelocksLib.Stage.SrcCancellation),
            DEPLOY_TIME + SRC_CANCELLATION_OFFSET,
            "SrcCancellation should unpack correctly"
        );
        assertEq(
            timelocks.get(TimelocksLib.Stage.SrcPublicCancellation),
            DEPLOY_TIME + SRC_PUBLIC_CANCELLATION_OFFSET,
            "SrcPublicCancellation should unpack correctly"
        );
        assertEq(
            timelocks.get(TimelocksLib.Stage.DstWithdrawal),
            DEPLOY_TIME + DST_WITHDRAWAL_OFFSET,
            "DstWithdrawal should unpack correctly"
        );
        assertEq(
            timelocks.get(TimelocksLib.Stage.DstPublicWithdrawal),
            DEPLOY_TIME + DST_PUBLIC_WITHDRAWAL_OFFSET,
            "DstPublicWithdrawal should unpack correctly"
        );
        assertEq(
            timelocks.get(TimelocksLib.Stage.DstCancellation),
            DEPLOY_TIME + DST_CANCELLATION_OFFSET,
            "DstCancellation should unpack correctly"
        );
        
        // Verify raw packed value is preserved
        assertEq(Timelocks.unwrap(timelocks), packed, "Packed value should be preserved");
    }
    
    /**
     * @notice Test 2: setDeployedAt sets timestamp correctly
     * @dev Verifies the deployment timestamp is set properly in bits 224-255
     */
    function testSetDeployedAt() public {
        // Start with empty timelocks
        Timelocks timelocks = Timelocks.wrap(0);
        
        // Set deployment timestamp
        timelocks = timelocks.setDeployedAt(DEPLOY_TIME);
        
        // Extract deployment timestamp (bits 224-255)
        uint256 extractedTime = Timelocks.unwrap(timelocks) >> 224;
        assertEq(extractedTime, DEPLOY_TIME, "Deployment timestamp should be set correctly");
        
        // Verify other bits remain zero
        uint256 lowerBits = Timelocks.unwrap(timelocks) & ((1 << 224) - 1);
        assertEq(lowerBits, 0, "Lower bits should remain zero");
        
        // Test overwriting with new timestamp
        uint32 newTime = DEPLOY_TIME + 1000;
        timelocks = timelocks.setDeployedAt(newTime);
        extractedTime = Timelocks.unwrap(timelocks) >> 224;
        assertEq(extractedTime, newTime, "New deployment timestamp should overwrite old one");
    }
    
    /**
     * @notice Test 3: srcWithdrawalStart calculation is correct
     * @dev Verifies the source withdrawal start time calculation
     */
    function testSrcWithdrawalStart() public {
        uint256 packed = 0;
        packed |= uint256(SRC_WITHDRAWAL_OFFSET); // bits 0-31
        packed |= uint256(DEPLOY_TIME) << 224; // bits 224-255
        
        Timelocks timelocks = Timelocks.wrap(packed);
        
        uint256 expectedStart = DEPLOY_TIME + SRC_WITHDRAWAL_OFFSET;
        uint256 actualStart = timelocks.get(TimelocksLib.Stage.SrcWithdrawal);
        
        assertEq(actualStart, expectedStart, "SrcWithdrawal start should be deployedAt + offset");
        
        // Test with zero offset
        packed = uint256(DEPLOY_TIME) << 224;
        timelocks = Timelocks.wrap(packed);
        actualStart = timelocks.get(TimelocksLib.Stage.SrcWithdrawal);
        assertEq(actualStart, DEPLOY_TIME, "SrcWithdrawal with zero offset should equal deployedAt");
    }
    
    /**
     * @notice Test 4: srcPublicWithdrawalStart public window timing
     * @dev Verifies the source public withdrawal window calculation
     */
    function testSrcPublicWithdrawalStart() public {
        uint256 packed = 0;
        packed |= uint256(SRC_PUBLIC_WITHDRAWAL_OFFSET) << 32; // bits 32-63
        packed |= uint256(DEPLOY_TIME) << 224; // bits 224-255
        
        Timelocks timelocks = Timelocks.wrap(packed);
        
        uint256 expectedStart = DEPLOY_TIME + SRC_PUBLIC_WITHDRAWAL_OFFSET;
        uint256 actualStart = timelocks.get(TimelocksLib.Stage.SrcPublicWithdrawal);
        
        assertEq(actualStart, expectedStart, "SrcPublicWithdrawal start should be deployedAt + offset");
        
        // Test that public withdrawal comes after private withdrawal
        packed |= uint256(SRC_WITHDRAWAL_OFFSET); // Add src withdrawal offset
        timelocks = Timelocks.wrap(packed);
        
        uint256 privateStart = timelocks.get(TimelocksLib.Stage.SrcWithdrawal);
        uint256 publicStart = timelocks.get(TimelocksLib.Stage.SrcPublicWithdrawal);
        
        assertGe(publicStart, privateStart, "Public withdrawal should not start before private withdrawal");
    }
    
    /**
     * @notice Test 5: srcCancellationStart cancel timing
     * @dev Verifies the source cancellation start time calculation
     */
    function testSrcCancellationStart() public {
        uint256 packed = 0;
        packed |= uint256(SRC_CANCELLATION_OFFSET) << 64; // bits 64-95
        packed |= uint256(DEPLOY_TIME) << 224; // bits 224-255
        
        Timelocks timelocks = Timelocks.wrap(packed);
        
        uint256 expectedStart = DEPLOY_TIME + SRC_CANCELLATION_OFFSET;
        uint256 actualStart = timelocks.get(TimelocksLib.Stage.SrcCancellation);
        
        assertEq(actualStart, expectedStart, "SrcCancellation start should be deployedAt + offset");
        
        // Test typical ordering: cancellation after withdrawal periods
        packed = 0;
        packed |= uint256(SRC_WITHDRAWAL_OFFSET); // 1 hour
        packed |= uint256(SRC_PUBLIC_WITHDRAWAL_OFFSET) << 32; // 2 hours
        packed |= uint256(SRC_CANCELLATION_OFFSET) << 64; // 3 hours
        packed |= uint256(DEPLOY_TIME) << 224;
        
        timelocks = Timelocks.wrap(packed);
        
        uint256 withdrawalStart = timelocks.get(TimelocksLib.Stage.SrcWithdrawal);
        uint256 publicWithdrawalStart = timelocks.get(TimelocksLib.Stage.SrcPublicWithdrawal);
        uint256 cancellationStart = timelocks.get(TimelocksLib.Stage.SrcCancellation);
        
        assertGe(cancellationStart, publicWithdrawalStart, "Cancellation should typically start after public withdrawal");
        assertGe(publicWithdrawalStart, withdrawalStart, "Public withdrawal should start after private withdrawal");
    }
    
    /**
     * @notice Test 6: srcPublicCancellationStart public cancel timing
     * @dev Verifies the source public cancellation window calculation
     */
    function testSrcPublicCancellationStart() public {
        uint256 packed = 0;
        packed |= uint256(SRC_PUBLIC_CANCELLATION_OFFSET) << 96; // bits 96-127
        packed |= uint256(DEPLOY_TIME) << 224; // bits 224-255
        
        Timelocks timelocks = Timelocks.wrap(packed);
        
        uint256 expectedStart = DEPLOY_TIME + SRC_PUBLIC_CANCELLATION_OFFSET;
        uint256 actualStart = timelocks.get(TimelocksLib.Stage.SrcPublicCancellation);
        
        assertEq(actualStart, expectedStart, "SrcPublicCancellation start should be deployedAt + offset");
        
        // Test that public cancellation comes after private cancellation
        packed |= uint256(SRC_CANCELLATION_OFFSET) << 64; // Add src cancellation offset
        timelocks = Timelocks.wrap(packed);
        
        uint256 privateStart = timelocks.get(TimelocksLib.Stage.SrcCancellation);
        uint256 publicStart = timelocks.get(TimelocksLib.Stage.SrcPublicCancellation);
        
        assertGe(publicStart, privateStart, "Public cancellation should not start before private cancellation");
    }
    
    /**
     * @notice Test 7: dstWithdrawalStart destination window
     * @dev Verifies the destination withdrawal start time calculation
     */
    function testDstWithdrawalStart() public {
        uint256 packed = 0;
        packed |= uint256(DST_WITHDRAWAL_OFFSET) << 128; // bits 128-159
        packed |= uint256(DEPLOY_TIME) << 224; // bits 224-255
        
        Timelocks timelocks = Timelocks.wrap(packed);
        
        uint256 expectedStart = DEPLOY_TIME + DST_WITHDRAWAL_OFFSET;
        uint256 actualStart = timelocks.get(TimelocksLib.Stage.DstWithdrawal);
        
        assertEq(actualStart, expectedStart, "DstWithdrawal start should be deployedAt + offset");
        
        // Test with zero offset
        packed = uint256(DEPLOY_TIME) << 224;
        timelocks = Timelocks.wrap(packed);
        actualStart = timelocks.get(TimelocksLib.Stage.DstWithdrawal);
        assertEq(actualStart, DEPLOY_TIME, "DstWithdrawal with zero offset should equal deployedAt");
    }
    
    /**
     * @notice Test 8: dstCancellationStart destination cancel timing
     * @dev Verifies the destination cancellation start time calculation
     */
    function testDstCancellationStart() public {
        uint256 packed = 0;
        packed |= uint256(DST_CANCELLATION_OFFSET) << 192; // bits 192-223
        packed |= uint256(DEPLOY_TIME) << 224; // bits 224-255
        
        Timelocks timelocks = Timelocks.wrap(packed);
        
        uint256 expectedStart = DEPLOY_TIME + DST_CANCELLATION_OFFSET;
        uint256 actualStart = timelocks.get(TimelocksLib.Stage.DstCancellation);
        
        assertEq(actualStart, expectedStart, "DstCancellation start should be deployedAt + offset");
        
        // Test typical ordering for destination chain
        packed = 0;
        packed |= uint256(DST_WITHDRAWAL_OFFSET) << 128; // 30 minutes
        packed |= uint256(DST_PUBLIC_WITHDRAWAL_OFFSET) << 160; // 1.5 hours
        packed |= uint256(DST_CANCELLATION_OFFSET) << 192; // 2.5 hours
        packed |= uint256(DEPLOY_TIME) << 224;
        
        timelocks = Timelocks.wrap(packed);
        
        uint256 withdrawalStart = timelocks.get(TimelocksLib.Stage.DstWithdrawal);
        uint256 publicWithdrawalStart = timelocks.get(TimelocksLib.Stage.DstPublicWithdrawal);
        uint256 cancellationStart = timelocks.get(TimelocksLib.Stage.DstCancellation);
        
        assertGe(cancellationStart, publicWithdrawalStart, "Dst cancellation should typically start after public withdrawal");
        assertGe(publicWithdrawalStart, withdrawalStart, "Dst public withdrawal should start after private withdrawal");
    }
    
    /**
     * @notice Test 9: Boundary conditions with zero and max values
     * @dev Tests edge cases with minimum and maximum possible values
     */
    function testBoundaryConditions() public {
        // Test all zeros
        Timelocks zeroTimelocks = Timelocks.wrap(0);
        assertEq(zeroTimelocks.get(TimelocksLib.Stage.SrcWithdrawal), 0, "Zero timelocks should return 0");
        assertEq(zeroTimelocks.get(TimelocksLib.Stage.DstCancellation), 0, "Zero timelocks should return 0");
        
        // Test maximum uint32 values for offsets
        uint256 packed = 0;
        packed |= uint256(MAX_UINT32); // Max src withdrawal offset
        packed |= uint256(MAX_UINT32) << 32; // Max src public withdrawal offset
        packed |= uint256(MAX_UINT32) << 64; // Max src cancellation offset
        packed |= uint256(MAX_UINT32) << 96; // Max src public cancellation offset
        packed |= uint256(MAX_UINT32) << 128; // Max dst withdrawal offset
        packed |= uint256(MAX_UINT32) << 160; // Max dst public withdrawal offset
        packed |= uint256(MAX_UINT32) << 192; // Max dst cancellation offset
        packed |= uint256(MAX_UINT32) << 224; // Max deployed at timestamp
        
        Timelocks maxTimelocks = Timelocks.wrap(packed);
        
        // All should return max_uint32 + max_uint32 (within uint256 range)
        uint256 expected = uint256(MAX_UINT32) + uint256(MAX_UINT32);
        assertEq(maxTimelocks.get(TimelocksLib.Stage.SrcWithdrawal), expected, "Max values should add correctly");
        assertEq(maxTimelocks.get(TimelocksLib.Stage.DstCancellation), expected, "Max values should add correctly");
        
        // Test mixed boundary values
        packed = 0;
        packed |= uint256(0); // Zero src withdrawal
        packed |= uint256(MAX_UINT32) << 32; // Max src public withdrawal
        packed |= uint256(1) << 64; // Min non-zero src cancellation
        packed |= uint256(MAX_UINT32 - 1) << 96; // Almost max src public cancellation
        packed |= uint256(DEPLOY_TIME) << 224;
        
        Timelocks mixedTimelocks = Timelocks.wrap(packed);
        
        assertEq(mixedTimelocks.get(TimelocksLib.Stage.SrcWithdrawal), DEPLOY_TIME, "Zero offset should equal deployedAt");
        assertEq(mixedTimelocks.get(TimelocksLib.Stage.SrcPublicWithdrawal), uint256(DEPLOY_TIME) + MAX_UINT32, "Max offset should add correctly");
        assertEq(mixedTimelocks.get(TimelocksLib.Stage.SrcCancellation), DEPLOY_TIME + 1, "Min offset should add correctly");
        assertEq(mixedTimelocks.get(TimelocksLib.Stage.SrcPublicCancellation), uint256(DEPLOY_TIME) + MAX_UINT32 - 1, "Almost max offset should add correctly");
    }
    
    /**
     * @notice Test 10: Overflow protection ensures no overflows occur
     * @dev Tests that the library handles potential overflow scenarios correctly
     */
    function testOverflowProtection() public {
        // The library uses uint32 for offsets, which prevents overflow
        // When added to deployedAt (also uint32), the result fits in uint256
        
        // Test near-max timestamp with max offset
        uint256 packed = 0;
        packed |= uint256(MAX_UINT32); // Max offset
        packed |= uint256(MAX_UINT32) << 224; // Max deployed at
        
        Timelocks timelocks = Timelocks.wrap(packed);
        
        // This should not overflow because uint32 + uint32 < uint256
        uint256 result = timelocks.get(TimelocksLib.Stage.SrcWithdrawal);
        uint256 expected = uint256(MAX_UINT32) + uint256(MAX_UINT32);
        
        assertEq(result, expected, "Should handle max values without overflow");
        assertLt(result, type(uint64).max, "Result should fit in uint64");
        
        // Test that bit masking prevents overflow between fields
        packed = MAX_UINT256; // All bits set to 1
        timelocks = Timelocks.wrap(packed);
        
        // Each field should be properly masked to uint32
        result = timelocks.get(TimelocksLib.Stage.SrcWithdrawal);
        expected = uint256(MAX_UINT32) + uint256(MAX_UINT32); // deployedAt + offset, both masked to uint32
        assertEq(result, expected, "Bit masking should prevent field overflow");
        
        // Verify the library uses unchecked arithmetic (gas optimization)
        // This is safe because uint32 + uint32 cannot overflow uint256
        // The library code shows: unchecked { return (data >> _DEPLOYED_AT_OFFSET) + uint32(data >> bitShift); }
    }
    
    /**
     * @notice Test 11: Factory address packing in high bits
     * @dev Tests if factory address can be packed in unused high bits (if supported)
     * Note: Current implementation uses bits 224-255 for timestamp, bits 0-223 for offsets
     * Factory address packing would require different bit layout
     */
    function testFactoryAddressPacking() public {
        // Current TimelocksLib implementation analysis:
        // - Bits 0-31: Stage 0 (SrcWithdrawal)
        // - Bits 32-63: Stage 1 (SrcPublicWithdrawal)
        // - Bits 64-95: Stage 2 (SrcCancellation)
        // - Bits 96-127: Stage 3 (SrcPublicCancellation)
        // - Bits 128-159: Stage 4 (DstWithdrawal)
        // - Bits 160-191: Stage 5 (DstPublicWithdrawal)
        // - Bits 192-223: Stage 6 (DstCancellation)
        // - Bits 224-255: DeployedAt timestamp
        
        // The library does NOT currently support factory address packing
        // All 256 bits are used for timelocks and timestamp
        
        // Test that high bits are used for timestamp, not address
        uint256 packed = 0;
        uint32 testTimestamp = 0x12345678;
        packed |= uint256(testTimestamp) << 224;
        
        Timelocks timelocks = Timelocks.wrap(packed);
        
        // Verify timestamp is in bits 224-255
        uint256 extractedTimestamp = Timelocks.unwrap(timelocks) >> 224;
        assertEq(extractedTimestamp, testTimestamp, "Bits 224-255 store timestamp, not factory address");
        
        // Test setDeployedAt overwrites high bits
        timelocks = Timelocks.wrap(MAX_UINT256); // All bits set
        timelocks = timelocks.setDeployedAt(testTimestamp);
        
        extractedTimestamp = Timelocks.unwrap(timelocks) >> 224;
        assertEq(extractedTimestamp, testTimestamp, "setDeployedAt overwrites bits 224-255");
        
        // Document finding: Factory address packing is NOT supported in current implementation
        // All 256 bits are allocated: 7 stages (32 bits each) + deployedAt (32 bits)
        // If factory address packing is needed, the bit layout would need redesign
        
        emit log_string("FINDING: Factory address packing is NOT supported in current TimelocksLib");
        emit log_string("Bit layout: 7 stages (0-223) + deployedAt timestamp (224-255)");
    }
    
    /**
     * @notice Additional test: rescueStart function
     * @dev Tests the rescue delay calculation
     */
    function testRescueStart() public {
        uint256 packed = uint256(DEPLOY_TIME) << 224;
        Timelocks timelocks = Timelocks.wrap(packed);
        
        uint256 rescueDelay = 86400; // 1 day
        uint256 expectedRescueStart = DEPLOY_TIME + rescueDelay;
        uint256 actualRescueStart = timelocks.rescueStart(rescueDelay);
        
        assertEq(actualRescueStart, expectedRescueStart, "Rescue start should be deployedAt + rescueDelay");
        
        // Test with zero rescue delay
        actualRescueStart = timelocks.rescueStart(0);
        assertEq(actualRescueStart, DEPLOY_TIME, "Zero rescue delay should return deployedAt");
        
        // Test with max rescue delay
        actualRescueStart = timelocks.rescueStart(MAX_UINT32);
        expectedRescueStart = uint256(DEPLOY_TIME) + uint256(MAX_UINT32);
        assertEq(actualRescueStart, expectedRescueStart, "Max rescue delay should calculate correctly");
    }
    
    /**
     * @notice Fuzz test: Random values pack and unpack correctly
     * @dev Ensures the library works correctly with random inputs
     */
    function testFuzzPackUnpack(
        uint32 srcWithdrawal,
        uint32 srcPublicWithdrawal,
        uint32 srcCancellation,
        uint32 srcPublicCancellation,
        uint32 dstWithdrawal,
        uint32 dstPublicWithdrawal,
        uint32 dstCancellation,
        uint32 deployedAt
    ) public {
        // Pack all values
        uint256 packed = 0;
        packed |= uint256(srcWithdrawal);
        packed |= uint256(srcPublicWithdrawal) << 32;
        packed |= uint256(srcCancellation) << 64;
        packed |= uint256(srcPublicCancellation) << 96;
        packed |= uint256(dstWithdrawal) << 128;
        packed |= uint256(dstPublicWithdrawal) << 160;
        packed |= uint256(dstCancellation) << 192;
        packed |= uint256(deployedAt) << 224;
        
        Timelocks timelocks = Timelocks.wrap(packed);
        
        // Verify all values unpack correctly
        assertEq(
            timelocks.get(TimelocksLib.Stage.SrcWithdrawal),
            uint256(deployedAt) + uint256(srcWithdrawal),
            "Fuzz: SrcWithdrawal"
        );
        assertEq(
            timelocks.get(TimelocksLib.Stage.SrcPublicWithdrawal),
            uint256(deployedAt) + uint256(srcPublicWithdrawal),
            "Fuzz: SrcPublicWithdrawal"
        );
        assertEq(
            timelocks.get(TimelocksLib.Stage.SrcCancellation),
            uint256(deployedAt) + uint256(srcCancellation),
            "Fuzz: SrcCancellation"
        );
        assertEq(
            timelocks.get(TimelocksLib.Stage.SrcPublicCancellation),
            uint256(deployedAt) + uint256(srcPublicCancellation),
            "Fuzz: SrcPublicCancellation"
        );
        assertEq(
            timelocks.get(TimelocksLib.Stage.DstWithdrawal),
            uint256(deployedAt) + uint256(dstWithdrawal),
            "Fuzz: DstWithdrawal"
        );
        assertEq(
            timelocks.get(TimelocksLib.Stage.DstPublicWithdrawal),
            uint256(deployedAt) + uint256(dstPublicWithdrawal),
            "Fuzz: DstPublicWithdrawal"
        );
        assertEq(
            timelocks.get(TimelocksLib.Stage.DstCancellation),
            uint256(deployedAt) + uint256(dstCancellation),
            "Fuzz: DstCancellation"
        );
    }
    
    /**
     * @notice Documentation of bit layout findings
     * @dev This test documents the actual bit layout discovered through testing
     */
    function testDocumentBitLayout() public view {
        // Documented bit layout based on implementation analysis:
        console.log("=== TimelocksLib Bit Layout Documentation ===");
        console.log("Bits 0-31:     SrcWithdrawal offset (Stage 0)");
        console.log("Bits 32-63:    SrcPublicWithdrawal offset (Stage 1)");
        console.log("Bits 64-95:    SrcCancellation offset (Stage 2)");
        console.log("Bits 96-127:   SrcPublicCancellation offset (Stage 3)");
        console.log("Bits 128-159:  DstWithdrawal offset (Stage 4)");
        console.log("Bits 160-191:  DstPublicWithdrawal offset (Stage 5)");
        console.log("Bits 192-223:  DstCancellation offset (Stage 6)");
        console.log("Bits 224-255:  DeployedAt timestamp");
        console.log("");
        console.log("Key Findings:");
        console.log("1. All 256 bits are utilized - no room for factory address");
        console.log("2. Each stage offset is uint32 (max ~136 years from deploy)");
        console.log("3. DeployedAt is uint32 (valid until year 2106)");
        console.log("4. The get() function adds deployedAt + offset for absolute time");
        console.log("5. setDeployedAt() only modifies bits 224-255");
        console.log("6. rescueStart() adds rescueDelay to deployedAt");
        console.log("7. Library uses unchecked arithmetic (safe due to uint32 bounds)");
    }
}