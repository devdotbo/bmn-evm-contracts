# 1inch Interface Compatibility Plan

## Goal
Make BMN contracts interface-compatible with 1inch cross-chain-swap contracts without adding complexity.

## Current Incompatibility
BMN's `IBaseEscrow.Immutables` struct is missing the `bytes parameters` field that 1inch uses for fee data.

## Simple Solution: Add Field, Keep Empty

### 1. Interface Changes Required

#### IBaseEscrow.sol
```solidity
struct Immutables {
    bytes32 orderHash;
    bytes32 hashlock;
    Address maker;
    Address taker;
    Address token;
    uint256 amount;
    uint256 safetyDeposit;
    Timelocks timelocks;
    bytes parameters;  // ADD THIS - For 1inch compatibility, always empty in BMN
}
```

#### IEscrowFactory.sol
```solidity
struct DstImmutablesComplement {
    Address maker;
    uint256 amount;
    Address token;
    uint256 safetyDeposit;
    uint256 chainId;
    bytes parameters;  // ADD THIS - For 1inch compatibility, always empty in BMN
}

// Update event to match 1inch format exactly
event SrcEscrowCreated(
    IBaseEscrow.Immutables srcImmutables,  // Remove indexed escrow address
    DstImmutablesComplement dstImmutablesComplement
);
```

### 2. Implementation Changes

#### SimplifiedEscrowFactory.sol
```solidity
// In _postInteraction (for source escrow):
IBaseEscrow.Immutables memory immutables = IBaseEscrow.Immutables({
    orderHash: orderHash,
    hashlock: hashlock,
    maker: order.maker,
    taker: Address.wrap(uint160(taker)),
    token: order.makerAsset,
    amount: makingAmount,
    safetyDeposit: extraDataArgs.deposits >> 128,
    timelocks: extraDataArgs.timelocks.setDeployedAt(block.timestamp),
    parameters: ""  // Always empty for BMN (no fees)
});

// For DstImmutablesComplement:
DstImmutablesComplement memory immutablesComplement = DstImmutablesComplement({
    maker: order.receiver.get() == address(0) ? order.maker : order.receiver,
    amount: takingAmount,
    token: extraDataArgs.dstToken,
    safetyDeposit: extraDataArgs.deposits & type(uint128).max,
    chainId: extraDataArgs.dstChainId,
    parameters: ""  // Always empty for BMN (no fees)
});
```

#### When creating destination escrow:
```solidity
// In createDstEscrow or resolver code:
IBaseEscrow.Immutables memory immutables = IBaseEscrow.Immutables({
    // ... other fields ...
    parameters: ""  // Always empty for BMN
});
```

### 3. What This Achieves

✅ **Full Interface Compatibility**
- Same struct layout as 1inch
- Same function signatures
- Same event structures
- Compatible ABI encoding

✅ **No Added Complexity**
- No fee logic implementation
- No parameter parsing
- Just pass empty bytes everywhere
- Ignore the field in escrow contracts

✅ **Future Extensibility**
- Can add fee support later if needed
- Parameters field ready for use
- No breaking changes required

### 4. Hash Computation Compatibility

The empty `parameters` field will be included in hash computation:
- Empty bytes `""` gets hashed to a specific value
- This ensures deterministic address generation
- Compatible with 1inch's hash computation

### 5. Testing Compatibility

After changes, you can verify compatibility:
1. Generate immutables with empty parameters
2. Compute hash using ImmutablesLib
3. Verify escrow addresses match expected values
4. Test with 1inch SDK (should recognize structs)

## Implementation Steps

1. **Update Interfaces** (5 minutes)
   - Add `bytes parameters` to both structs
   - Update event signatures

2. **Update Factory** (10 minutes)
   - Set `parameters: ""` in all immutable creations
   - Update event emissions

3. **Update Tests** (15 minutes)
   - Add empty parameters to test immutables
   - Verify hash computation still works

4. **Update Resolver** (10 minutes)
   - Add empty parameters field to TypeScript types
   - Pass empty string/bytes in all calls

## Benefits

- ✅ **Immediate 1inch compatibility**
- ✅ **No complex fee logic needed**
- ✅ **Can leverage 1inch tools/SDKs**
- ✅ **Minimal code changes**
- ✅ **No gas overhead** (empty bytes is cheap)
- ✅ **Future-proof** (can add fees later)

## Risks

- ⚠️ **Breaking change** - Requires redeployment
- ⚠️ **Different escrow addresses** - Hash will change
- ⚠️ **Must update all tooling** - Resolver, tests, scripts

## Decision Point

**Should we proceed?**

If YES:
1. Add parameters field to interfaces
2. Update factory to set empty parameters
3. Redeploy contracts
4. Update resolver/tooling

If NO:
- Accept incompatibility with 1inch
- Maintain BMN as separate ecosystem
- Build BMN-specific tooling

## Summary

Adding the `bytes parameters` field with empty values everywhere is the simplest path to 1inch compatibility. It requires minimal changes, adds no complexity, and makes BMN contracts fully interface-compatible with 1inch's ecosystem while maintaining our simplified approach.