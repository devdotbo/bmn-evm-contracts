# Resolver Fix Instructions

## Overview
The contract ABIs have been updated after fixing timelock packing issues. The resolver TypeScript code needs updates to match the new ABI signatures.

## ABI Changes
1. **Timelock Packing Fixed**: Contracts now properly pack timelock values into uint256
2. **createDstEscrow Signature Changed**: Now accepts 2 parameters instead of 3

## Required Code Changes

### 1. Fix createDstEscrow call in `src/resolver/executor.ts` (lines 139-143)

**Current (incorrect):**
```typescript
return await factory.write.createDstEscrow([
  order.immutables,
  dstImmutables,
  BigInt(this.srcChainId)
]);
```

**Fixed:**
```typescript
return await factory.write.createDstEscrow([
  dstImmutables,
  order.immutables.timelocks.srcCancellation  // Pass cancellation timestamp, not chainId
]);
```

### 2. Review computeEscrowDstAddress parameters
The computeEscrowDstAddress function may need parameter adjustments based on the new ABI.

### 3. Timelock Structure Compatibility

**Contract expects (packed uint256):**
- Bits 0-31: srcWithdrawal offset
- Bits 32-63: srcPublicWithdrawal offset  
- Bits 64-95: srcCancellation offset
- Bits 96-127: srcPublicCancellation offset
- Bits 128-159: dstWithdrawal offset
- Bits 160-191: dstPublicWithdrawal offset
- Bits 192-223: dstCancellation offset
- Bits 224-255: deployedAt timestamp

**TypeScript currently uses (unpacked):**
```typescript
interface Timelocks {
  srcWithdrawal: bigint;
  srcPublicWithdrawal: bigint;
  srcCancellation: bigint;
  srcPublicCancellation: bigint;
  dstWithdrawal: bigint;
  dstCancellation: bigint;
}
```

**Note:** Check if viem automatically handles the packing/unpacking based on the ABI. If not, you may need to add conversion functions.

## Contract Changes Summary
- Fixed bitwise operations in createTimelocks() with proper uint256 casting
- Timelocks now correctly store offset values instead of all zeros
- EscrowFactory.createDstEscrow now properly validates parameters

## Testing
After making these changes, run:
```bash
./scripts/test-flow.sh -y
```

This should resolve the "ABI encoding error when deploying destination escrow" issue.
