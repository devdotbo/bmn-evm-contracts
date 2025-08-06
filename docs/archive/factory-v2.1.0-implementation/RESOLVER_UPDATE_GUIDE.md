# Resolver Update Guide - Factory v1.1.0

## Overview

The CrossChainEscrowFactory has been upgraded to v1.1.0 with enhanced events that emit escrow addresses directly. This guide documents what the resolver needs to know about the changes.

## New Factory Deployment

**Upgraded Factory Address**: `0x2B2d52Cf0080a01f457A4f64F41cbca500f787b1` (same on Base and Etherlink)

### What Changed

1. **Event Enhancement**: Factory events now include escrow addresses as the first indexed parameter
2. **No More CREATE2 Calculations**: Escrow addresses are emitted directly in events
3. **Backward Compatible**: All contract interfaces remain the same

### Updated Event Signatures

```solidity
// Old events (v1.0.0)
event SrcEscrowCreated(
    IBaseEscrow.Immutables srcImmutables, 
    DstImmutablesComplement dstImmutablesComplement
);

// New events (v1.1.0) - NOW ACTIVE
event SrcEscrowCreated(
    address indexed escrow,  // NEW: Escrow address included
    IBaseEscrow.Immutables srcImmutables, 
    DstImmutablesComplement dstImmutablesComplement
);

event DstEscrowCreated(
    address indexed escrow,  // Already present, now indexed
    bytes32 indexed hashlock,  // Now indexed
    Address taker
);
```

## Integration Options

### Option 1: Direct Event Monitoring (Current Approach)

If continuing to monitor events directly:

1. **Update Factory Address**:
   ```typescript
   const FACTORY_ADDRESS = "0x2B2d52Cf0080a01f457A4f64F41cbca500f787b1";
   ```

2. **Simplify Event Handling**:
   ```typescript
   // Old: Calculate escrow address
   const escrowAddress = calculateCreate2Address(srcImmutables);
   
   // New: Get directly from event
   const escrowAddress = event.args.escrow;
   ```

3. **Remove CREATE2 Logic**: No longer needed for address derivation

### Option 2: Indexer Integration (Recommended Future Approach)

The indexer is being updated to handle the new factory events. Once ready:

1. **Query Indexer API** instead of monitoring events directly
2. **Benefits**:
   - No need to monitor blockchain events
   - Faster queries with indexed data
   - Historical data readily available
   - Reduced RPC load

## Immediate Actions Required

1. **Update Configuration**:
   - Change factory address to `0x2B2d52Cf0080a01f457A4f64F41cbca500f787b1`
   - Update ABI to include new event signatures

2. **Deployment Status**:
   - Base: Deployed at block 33806117
   - Etherlink: Deployed at block 22641583

3. **Testing**:
   - New escrows will emit enhanced events
   - Old escrows continue working normally

## Timeline

- [OK] Factory v1.1.0 deployed to mainnet
- [IN PROGRESS] Indexer being updated for new events
- [PENDING] Resolver to integrate with indexer API

## Technical Details

### ABI Changes

The factory ABI has been updated with new event signatures. Key changes:
- `SrcEscrowCreated` now has escrow address as first parameter
- Both events have indexed parameters for efficient filtering

### Gas Impact

- Minimal increase (<1% per transaction)
- No impact on resolver operations

## Questions?

For implementation questions, refer to:
- Factory deployment: `deployments/FACTORY_UPGRADE_DEPLOYMENT_SUMMARY.md`
- Event changes: `docs/FACTORY_EVENT_ENHANCEMENT.md`
- Contract code: `contracts/BaseEscrowFactory.sol`