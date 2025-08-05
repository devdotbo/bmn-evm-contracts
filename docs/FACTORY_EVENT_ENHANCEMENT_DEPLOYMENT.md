# Factory Event Enhancement Deployment Guide

## Overview

This document provides the step-by-step process for implementing and deploying the factory event enhancement to emit escrow addresses directly, bypassing Ponder's factory pattern limitations on Etherlink.

## Deployment Strategy

**Direct to Mainnet**: We deploy directly to production chains (Base and Etherlink) without testnet phase.

## Phase 1: Contract Implementation

### 1.1 Update Event Interfaces

**File**: `contracts/interfaces/IEscrowFactory.sol`

Update the event signatures to include escrow addresses:

```solidity
event SrcEscrowCreated(
    address indexed escrow,
    IBaseEscrow.Immutables srcImmutables, 
    DstImmutablesComplement dstImmutablesComplement
);

event DstEscrowCreated(
    address indexed escrow,
    bytes32 indexed hashlock,
    Address taker
);
```

### 1.2 Modify BaseEscrowFactory

**File**: `contracts/BaseEscrowFactory.sol`

Update the `_postInteraction` function to emit the escrow address:

```solidity
// Around line 114, modify the event emission
bytes32 salt = immutables.hashMem();
address escrow = _deployEscrow(salt, 0, ESCROW_SRC_IMPLEMENTATION);

// Emit event with escrow address
emit SrcEscrowCreated(escrow, immutables, immutablesComplement);
```

### 1.3 Update CrossChainEscrowFactory

Ensure the contract inherits the updated interface and uses the new event signatures.

### 1.4 Add Tests

Create comprehensive tests to verify:
- Event emission includes correct escrow address
- Address matches CREATE2 calculation
- Gas cost impact is within expected range

## Phase 2: Pre-Deployment Verification

### 2.1 Gas Analysis

Run gas profiling to confirm:
- Additional cost is ~2,100 gas
- Total transaction cost increase <1%

### 2.2 Event Signature Verification

Ensure event topics are correctly generated for indexing.

### 2.3 Integration Testing

Test with mock indexer to verify event parsing.

## Phase 3: Indexer Preparation

### 3.1 Create Dual-Mode Indexer

Implement indexer that handles both event formats:

```typescript
// Detect event format by argument count
if (event.args.length === 3 && isAddress(event.args[0])) {
    // New format with escrow address
    escrowAddress = event.args[0];
} else {
    // Legacy format - calculate CREATE2
    escrowAddress = calculateCreate2Address(event.args.srcImmutables);
}
```

### 3.2 Historical Data Handling

Maintain CREATE2 calculation logic for processing historical events.

### 3.3 Indexer Configuration

Update Ponder configuration to:
- Remove factory pattern usage
- Index events directly from CrossChainEscrowFactory
- Set appropriate block ranges for each chain

## Phase 4: Deployment Sequence

### 4.1 Contract Deployment Order

1. **Deploy to Base**:
   ```bash
   source .env && forge script script/DeployFactoryUpgrade.s.sol --rpc-url $BASE_RPC_URL --broadcast --verify
   ```

2. **Deploy to Etherlink**:
   ```bash
   source .env && forge script script/DeployFactoryUpgrade.s.sol --rpc-url $ETHERLINK_RPC_URL --broadcast
   ```

### 4.2 Verification Steps

After each deployment:
1. Verify contract on block explorer
2. Test event emission with a sample transaction
3. Confirm indexer receives and processes new events

### 4.3 Indexer Cutover

1. Deploy updated indexer with dual-mode support
2. Verify processing of new events
3. Monitor for any missed events during transition
4. Phase out factory pattern after confirmation

## Phase 5: Post-Deployment

### 5.1 Monitoring

- Track event emission patterns
- Monitor indexer performance improvements
- Verify Etherlink RPC load reduction

### 5.2 Documentation Updates

- Update integration documentation
- Provide migration guide for third-party indexers
- Update ABI files in resolver project

### 5.3 Cleanup (After 30 Days)

- Remove legacy CREATE2 calculation code
- Simplify indexer to only handle new format
- Archive old indexing logic

## Rollback Plan

If issues arise:
1. Indexer can immediately revert to factory pattern
2. New contracts still compatible with old indexing method
3. No user-facing impact during rollback

## Success Criteria

- [OK] Events emit escrow addresses correctly
- [OK] Indexer processes events without factory pattern
- [OK] Etherlink indexing works within configured block ranges
- [OK] Gas cost increase <1% of transaction total
- [OK] No disruption to existing protocol operations

## Timeline

- **Day 1**: Contract implementation and testing
- **Day 2**: Indexer preparation and testing
- **Day 3**: Base deployment
- **Day 4**: Etherlink deployment
- **Day 5-7**: Monitoring and verification
- **Day 30**: Legacy code cleanup