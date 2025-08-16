# V3.0.3 Resolver Compatibility Fix Plan

## Problem Summary

The v3.0.2 factory (and v2.3) use `block.timestamp` at deployment time when building timelocks, making it impossible for resolvers to predict the exact immutables stored in escrows. This causes `InvalidImmutables` errors when attempting withdrawals.

## Root Cause

In `SimplifiedEscrowFactory.postInteraction()` line 247:
```solidity
uint256 packedTimelocks = uint256(uint32(block.timestamp)) << 224; // deployedAt
```

The factory modifies the provided timelocks by:
1. Using actual `block.timestamp` as deployedAt (unpredictable)
2. Calculating offsets from this timestamp
3. Storing these modified values in the escrow immutables

When resolvers try to withdraw, they must provide the exact immutables, but they can't know what `block.timestamp` was at deployment time.

## Impact

- **v3.0.2**: Withdrawals fail with InvalidImmutables
- **v2.3**: Same issue exists but may have been worked around differently
- **All versions**: Resolvers cannot deterministically calculate stored immutables

## Solution Design

### Option 1: Event-Based Solution (Quick Fix)
Add comprehensive events that emit the exact immutables stored:

```solidity
event SrcEscrowCreatedWithImmutables(
    address indexed escrow,
    bytes32 indexed hashlock,
    bytes32 indexed orderHash,
    uint256[8] immutables  // Exact values for reconstruction
);
```

**Pros:**
- Minimal contract changes
- Backward compatible
- Quick to implement

**Cons:**
- Resolvers must read events to get immutables
- Not ideal for decentralized operation

### Option 2: Storage-Based Solution (Better)
Add getter functions to escrows that return stored immutables:

```solidity
// In BaseEscrow
mapping(address => Immutables) public escrowImmutables;

function getImmutables() external view returns (Immutables memory) {
    return escrowImmutables[address(this)];
}
```

**Pros:**
- Resolvers can read immutables directly from chain
- More reliable than events

**Cons:**
- Increases gas costs
- Requires escrow contract changes

### Option 3: Predictable Timelocks (Best)
Make timelocks predictable by using provided timestamps instead of block.timestamp:

```solidity
// Use provided timestamp from extraData instead of block.timestamp
uint256 deployedAt = (timelocks >> 192) & type(uint32).max; // Extract from packed data
uint256 packedTimelocks = uint256(uint32(deployedAt)) << 224;
```

**Pros:**
- Resolvers can calculate immutables off-chain
- No need for events or storage
- True decentralized operation

**Cons:**
- Requires careful timestamp validation
- May need tolerance for block timestamp variations

## Recommended Implementation: Hybrid Approach

Implement both Option 1 (events) and Option 3 (predictable timelocks) for v3.0.3:

1. **Make timelocks predictable**:
   - Use a provided deployedAt timestamp from order data
   - Validate it's within acceptable range of block.timestamp
   - This allows deterministic calculation

2. **Add comprehensive events**:
   - Emit exact immutables for debugging
   - Provide fallback for edge cases
   - Help with migration from v3.0.2

3. **Add helper view function**:
   - Factory provides `computeImmutables()` helper
   - Takes order data and returns what would be stored
   - Useful for testing and verification

## Implementation Steps

1. Create `SimplifiedEscrowFactoryV3_0_3.sol`
2. Modify timelock packing to use predictable values
3. Add comprehensive events with immutables
4. Add view helper for computing immutables
5. Update tests to verify resolver can calculate immutables
6. Deploy and verify on testnet first
7. Coordinate with resolver team for testing
8. Deploy to mainnet after verification

## Migration Path

For existing v3.0.2 escrows:
1. Resolvers must read events or use custom recovery logic
2. Factory owner could deploy helper contract to read immutables
3. Consider emergency migration function if needed

For new escrows (v3.0.3):
1. Resolvers can calculate immutables deterministically
2. Events provide verification and debugging
3. Full compatibility with existing infrastructure

## Testing Requirements

1. **Unit Tests**:
   - Verify predictable immutables calculation
   - Test withdrawal with calculated immutables
   - Ensure events emit correct data

2. **Integration Tests**:
   - Full cross-chain swap flow
   - Resolver calculates immutables off-chain
   - Successful withdrawal without reading events

3. **Edge Cases**:
   - Timestamp tolerance boundaries
   - Network timestamp variations
   - Gas optimization verification

## Timeline

- Implementation: 2 hours
- Testing: 2 hours
- Testnet deployment: 1 hour
- Resolver coordination: 2-3 days
- Mainnet deployment: After testnet verification

## Risk Assessment

- **Low Risk**: Adding events (backward compatible)
- **Medium Risk**: Changing timelock calculation (needs careful testing)
- **Mitigation**: Deploy to testnet first, coordinate with resolver team

## Success Criteria

1. Resolvers can withdraw from v3.0.3 escrows without reading events
2. Gas costs remain reasonable (< 5% increase)
3. Full backward compatibility with existing tooling
4. No security vulnerabilities introduced