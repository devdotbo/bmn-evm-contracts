// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { Test } from "forge-std/Test.sol";
import { Timelocks, TimelocksLib } from "../contracts/libraries/TimelocksLib.sol";

contract TimelocksLibPackTest is Test {
    using TimelocksLib for Timelocks;

    function testPackFunction() public pure {
        // Create a struct with test values
        TimelocksLib.TimelocksStruct memory timelocksStruct = TimelocksLib.TimelocksStruct({
            srcWithdrawal: 100,
            srcPublicWithdrawal: 200,
            srcCancellation: 300,
            srcPublicCancellation: 400,
            dstWithdrawal: 500,
            dstPublicWithdrawal: 600,
            dstCancellation: 700
        });

        // Pack the struct
        Timelocks packed = TimelocksLib.pack(timelocksStruct);
        
        // Add deployment timestamp
        uint256 deployedAt = 1234567890;
        packed = packed.setDeployedAt(deployedAt);

        // Verify each value was packed correctly
        assertEq(packed.get(TimelocksLib.Stage.SrcWithdrawal), deployedAt + 100, "SrcWithdrawal incorrect");
        assertEq(packed.get(TimelocksLib.Stage.SrcPublicWithdrawal), deployedAt + 200, "SrcPublicWithdrawal incorrect");
        assertEq(packed.get(TimelocksLib.Stage.SrcCancellation), deployedAt + 300, "SrcCancellation incorrect");
        assertEq(packed.get(TimelocksLib.Stage.SrcPublicCancellation), deployedAt + 400, "SrcPublicCancellation incorrect");
        assertEq(packed.get(TimelocksLib.Stage.DstWithdrawal), deployedAt + 500, "DstWithdrawal incorrect");
        assertEq(packed.get(TimelocksLib.Stage.DstPublicWithdrawal), deployedAt + 600, "DstPublicWithdrawal incorrect");
        assertEq(packed.get(TimelocksLib.Stage.DstCancellation), deployedAt + 700, "DstCancellation incorrect");
    }

    function testPackWithZeroValues() public pure {
        // Test with all zero values
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
        uint256 deployedAt = 1700000000; // Use a fixed timestamp for testing
        packed = packed.setDeployedAt(deployedAt);

        // All values should be equal to deployedAt (since offsets are 0)
        assertEq(packed.get(TimelocksLib.Stage.SrcWithdrawal), deployedAt);
        assertEq(packed.get(TimelocksLib.Stage.SrcPublicWithdrawal), deployedAt);
        assertEq(packed.get(TimelocksLib.Stage.SrcCancellation), deployedAt);
        assertEq(packed.get(TimelocksLib.Stage.SrcPublicCancellation), deployedAt);
        assertEq(packed.get(TimelocksLib.Stage.DstWithdrawal), deployedAt);
        assertEq(packed.get(TimelocksLib.Stage.DstPublicWithdrawal), deployedAt);
        assertEq(packed.get(TimelocksLib.Stage.DstCancellation), deployedAt);
    }

    function testPackWithMaxValues() public pure {
        // Test with maximum uint32 values
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
        uint256 deployedAt = 0; // Use 0 to test max values clearly
        packed = packed.setDeployedAt(deployedAt);

        // All values should be equal to maxValue
        assertEq(packed.get(TimelocksLib.Stage.SrcWithdrawal), uint256(maxValue));
        assertEq(packed.get(TimelocksLib.Stage.SrcPublicWithdrawal), uint256(maxValue));
        assertEq(packed.get(TimelocksLib.Stage.SrcCancellation), uint256(maxValue));
        assertEq(packed.get(TimelocksLib.Stage.SrcPublicCancellation), uint256(maxValue));
        assertEq(packed.get(TimelocksLib.Stage.DstWithdrawal), uint256(maxValue));
        assertEq(packed.get(TimelocksLib.Stage.DstPublicWithdrawal), uint256(maxValue));
        assertEq(packed.get(TimelocksLib.Stage.DstCancellation), uint256(maxValue));
    }

    function testPackPreservesIndividualValues() public pure {
        // Test that packing different values doesn't interfere with each other
        TimelocksLib.TimelocksStruct memory timelocksStruct = TimelocksLib.TimelocksStruct({
            srcWithdrawal: 1,
            srcPublicWithdrawal: 2,
            srcCancellation: 3,
            srcPublicCancellation: 4,
            dstWithdrawal: 5,
            dstPublicWithdrawal: 6,
            dstCancellation: 7
        });

        Timelocks packed = TimelocksLib.pack(timelocksStruct);
        
        // Check raw packed value to ensure correct bit positions
        uint256 rawValue = Timelocks.unwrap(packed);
        
        // Extract and verify each field from the raw value
        assertEq(uint32(rawValue), 1, "Bits 0-31 should be 1");
        assertEq(uint32(rawValue >> 32), 2, "Bits 32-63 should be 2");
        assertEq(uint32(rawValue >> 64), 3, "Bits 64-95 should be 3");
        assertEq(uint32(rawValue >> 96), 4, "Bits 96-127 should be 4");
        assertEq(uint32(rawValue >> 128), 5, "Bits 128-159 should be 5");
        assertEq(uint32(rawValue >> 160), 6, "Bits 160-191 should be 6");
        assertEq(uint32(rawValue >> 192), 7, "Bits 192-223 should be 7");
        assertEq(uint32(rawValue >> 224), 0, "Bits 224-255 should be 0 (deployedAt not set)");
    }
}