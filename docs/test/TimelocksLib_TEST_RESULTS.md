# TimelocksLib Test Results and Findings

## Test Coverage Summary
- **100% Line Coverage** (8/8 lines)
- **100% Statement Coverage** (10/10 statements)  
- **100% Function Coverage** (3/3 functions)
- **All 14 tests passing**

## Bit Layout Documentation

Based on comprehensive testing, the actual bit layout of TimelocksLib is:

| Bits | Field | Description |
|------|-------|-------------|
| 0-31 | SrcWithdrawal | Stage 0 - Source chain withdrawal offset (uint32) |
| 32-63 | SrcPublicWithdrawal | Stage 1 - Source chain public withdrawal offset (uint32) |
| 64-95 | SrcCancellation | Stage 2 - Source chain cancellation offset (uint32) |
| 96-127 | SrcPublicCancellation | Stage 3 - Source chain public cancellation offset (uint32) |
| 128-159 | DstWithdrawal | Stage 4 - Destination chain withdrawal offset (uint32) |
| 160-191 | DstPublicWithdrawal | Stage 5 - Destination chain public withdrawal offset (uint32) |
| 192-223 | DstCancellation | Stage 6 - Destination chain cancellation offset (uint32) |
| 224-255 | DeployedAt | Deployment timestamp (uint32) |

## Key Findings

### 1. No Factory Address Packing Support
**Finding**: The documentation suggestion about factory address packing in high bits is incorrect.
- All 256 bits are fully utilized for timelocks and timestamp
- No room available for factory address storage
- If factory address packing is needed, the bit layout would require redesign

### 2. Timestamp Calculation Method
- The `get()` function returns: `deployedAt + offset`
- All offsets are relative to deployment time
- Results are absolute timestamps (seconds since Unix epoch)

### 3. Overflow Protection
- Library uses `unchecked` arithmetic for gas optimization
- This is safe because: `uint32 + uint32` always fits in `uint256`
- Maximum timestamp supported until year 2106 (uint32 limit)
- Maximum offset: ~136 years from deployment (uint32 seconds)

### 4. Stage Ordering
The library supports 7 distinct stages mapped to bit positions:
```solidity
enum Stage {
    SrcWithdrawal,        // 0 -> bits 0-31
    SrcPublicWithdrawal,  // 1 -> bits 32-63
    SrcCancellation,      // 2 -> bits 64-95
    SrcPublicCancellation,// 3 -> bits 96-127
    DstWithdrawal,        // 4 -> bits 128-159
    DstPublicWithdrawal,  // 5 -> bits 160-191
    DstCancellation       // 6 -> bits 192-223
}
```

### 5. Function Behaviors

#### `setDeployedAt(timelocks, value)`
- Modifies only bits 224-255
- Preserves all timelock offsets (bits 0-223)
- Overwrites any existing deployment timestamp

#### `get(timelocks, stage)`
- Extracts 32-bit offset at position: `stage * 32`
- Adds offset to deployment timestamp
- Returns absolute timestamp

#### `rescueStart(timelocks, rescueDelay)`
- Returns: `deployedAt + rescueDelay`
- Used for rescue period calculation
- Simple addition with unchecked arithmetic

## Test Cases Implemented

1. **testPackUnpack**: Verified roundtrip data preservation
2. **testSetDeployedAt**: Confirmed timestamp setting in bits 224-255
3. **testSrcWithdrawalStart**: Validated source withdrawal calculations
4. **testSrcPublicWithdrawalStart**: Tested public withdrawal window
5. **testSrcCancellationStart**: Verified cancellation timing
6. **testSrcPublicCancellationStart**: Tested public cancellation
7. **testDstWithdrawalStart**: Validated destination withdrawal
8. **testDstCancellationStart**: Tested destination cancellation
9. **testBoundaryConditions**: Confirmed handling of 0 and MAX values
10. **testOverflowProtection**: Verified no overflow with max values
11. **testFactoryAddressPacking**: Documented lack of factory address support
12. **testRescueStart**: Validated rescue delay calculations
13. **testFuzzPackUnpack**: Fuzz tested with 256 random input combinations
14. **testDocumentBitLayout**: Self-documenting test for bit layout

## Recommendations

1. **Documentation Update**: The documentation should be updated to remove any references to factory address packing capability
2. **Year 2106 Consideration**: Consider migration strategy before uint32 timestamp limit (year 2106)
3. **Gas Optimization**: The unchecked arithmetic is appropriate and safe given the uint32 bounds

## Test Execution

Run tests with:
```bash
forge test --match-contract TimelocksLibTest -vvv
```

Check coverage with:
```bash
forge coverage --match-path test/TimelocksLib.t.sol --ir-minimum
```