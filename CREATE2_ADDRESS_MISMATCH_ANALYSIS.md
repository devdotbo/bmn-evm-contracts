# CREATE2 Address Mismatch Analysis

## Executive Summary

A critical issue has been discovered in the Bridge-Me-Not protocol where the predicted destination escrow address (`addressOfEscrowDst`) does not match the actual deployed address. This mismatch prevents proper interaction with destination escrows unless workarounds are implemented.

**Status**: Workaround implemented in resolver, contract-side fix pending

## Problem Statement

When deploying a destination escrow:
- `addressOfEscrowDst` predicts: `0x714fb51648abd53ee62a98210f45468a576b02e4`
- Actual deployment address: `0xed5ac5f74545700da580ee1272e5665f3cab50a5`
- Tokens are correctly sent to the actual address, but the predicted address is empty

This causes failures when trying to interact with the escrow at the predicted address.

## Root Cause Analysis

### The Mismatch Origin

The issue stems from using two different methods for address calculation vs deployment:

1. **Address Prediction** (`BaseEscrowFactory.sol:159-161`):
```solidity
function addressOfEscrowDst(IBaseEscrow.Immutables calldata immutables) external view virtual returns (address) {
    return Create2.computeAddress(immutables.hash(), _PROXY_DST_BYTECODE_HASH);
}
```

2. **Actual Deployment** (`BaseEscrowFactory.sol:170-172`):
```solidity
function _deployEscrow(bytes32 salt, uint256 value, address implementation) internal virtual returns (address escrow) {
    escrow = implementation.cloneDeterministic(salt, value);
}
```

### Technical Deep Dive

#### ProxyHashLib Implementation
```solidity
// contracts/libraries/ProxyHashLib.sol
function computeProxyBytecodeHash(address implementation) internal pure returns (bytes32 bytecodeHash) {
    assembly ("memory-safe") {
        mstore(0x20, 0x5af43d82803e903d91602b57fd5bf3)
        mstore(0x11, implementation)
        mstore(0x00, or(shr(0x88, implementation), 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000))
        bytecodeHash := keccak256(0x09, 0x37)
    }
}
```

#### OpenZeppelin Clones Implementation
```solidity
// Clones.sol:114-128
function predictDeterministicAddress(
    address implementation,
    bytes32 salt,
    address deployer
) internal pure returns (address predicted) {
    assembly ("memory-safe") {
        let ptr := mload(0x40)
        mstore(add(ptr, 0x38), deployer)
        mstore(add(ptr, 0x24), 0x5af43d82803e903d91602b57fd5bf3ff)
        mstore(add(ptr, 0x14), implementation)
        mstore(ptr, 0x3d602d80600a3d3981f3363d3d373d3d3d363d73)
        mstore(add(ptr, 0x58), salt)
        mstore(add(ptr, 0x78), keccak256(add(ptr, 0x0c), 0x37))
        predicted := and(keccak256(add(ptr, 0x43), 0x55), 0xffffffffffffffffffffffffffffffffffffffff)
    }
}
```

The key difference is in how the bytecode hash is computed and used in the CREATE2 address calculation.

## Discovery Timeline

1. **Initial Symptom**: Step 5 of test-live-swap.sh failed with "Escrow contract not deployed"
2. **Investigation**: Found escrow had 0 code length at predicted address
3. **Discovery**: Tokens were sent to a different address (found in transaction logs)
4. **Root Cause**: Identified mismatch between `Create2.computeAddress` and `Clones.predictDeterministicAddress`

## Current Workaround Implementation

### Resolver Side (Already Implemented)

The resolver successfully works around this issue by:

1. **Event Parsing** (`executor.ts:170-195`):
```typescript
// Parse the actual deployed address from DstEscrowCreated event
let actualEscrowAddress: Address | null = null;

// Find the DstEscrowCreated event in the logs
for (const log of receipt.logs) {
    // DstEscrowCreated event signature
    const eventSignature = "0x0e534c62f0afd2fa0f0fa71198e8aa2d549f24daf2bb47de0d5486c7ce9288ca";
    
    if (log.topics[0] === eventSignature && log.data.length >= 66) {
        // Extract address from event data (first 32 bytes after removing 0x)
        actualEscrowAddress = ('0x' + log.data.slice(26, 66)) as Address;
        break;
    }
}
```

2. **State Management**:
- Stores both `dstEscrowAddress` (predicted) and `actualDstEscrowAddress` (from event)
- Uses `actualDstEscrowAddress` for all interactions

### Test Scripts Workaround

The test scripts also implement parsing:
```bash
# scripts/parse-dst-escrow.sh
DST_ESCROW=$(cat "$BROADCAST_FILE" | jq -r '.receipts[1].logs[1].data' | cut -c 27-66 | sed 's/^/0x/')
```

## Proposed Contract Fix

### Short-term Fix
Update `addressOfEscrowDst` to use OpenZeppelin's method:

```solidity
function addressOfEscrowDst(IBaseEscrow.Immutables calldata immutables) external view virtual returns (address) {
    // OLD: return Create2.computeAddress(immutables.hash(), _PROXY_DST_BYTECODE_HASH);
    return Clones.predictDeterministicAddress(ESCROW_DST_IMPLEMENTATION, immutables.hash());
}
```

### Long-term Considerations
1. Add comprehensive tests to ensure address prediction matches deployment
2. Consider standardizing on one CREATE2 calculation method throughout the codebase
3. Document the proxy deployment pattern clearly

## Impact Analysis

### Affected Components

1. **Contracts**:
   - `BaseEscrowFactory.addressOfEscrowDst` - returns incorrect address
   - `BaseEscrowFactory.addressOfEscrowSrc` - potentially affected (needs verification)

2. **Resolver**:
   - ✅ Already handles the mismatch via event parsing
   - No immediate changes needed

3. **Test Scripts**:
   - ✅ Workaround implemented in parse-dst-escrow.sh
   - Future scripts should use event parsing

4. **External Integrators**:
   - ⚠️ Will face issues if relying on `addressOfEscrowDst`
   - Must implement event-based address discovery

## Testing Evidence

### Live Test Results
```bash
Step 3: Creating destination escrow on Chain B
Factory claims to deploy to: 0x714fb51648abd53ee62a98210f45468a576b02e4
Tokens actually sent to:      0xed5ac5f74545700da580ee1272e5665f3cab50a5
Code exists at:              0xed5ac5f74545700da580ee1272e5665f3cab50a5
```

### Resolver Handling
```json
{
  "dstEscrowAddress": "0xb0293D235ab252e67bf19e7f36799344Df6459Ee",
  "actualDstEscrowAddress": "0xb0293D235ab252e67bf19e7f36799344Df6459Ee"
}
```

## Recommendations

### For Contract Team
1. **Immediate**: Document the issue in contract comments
2. **Short-term**: Implement the proposed fix using `Clones.predictDeterministicAddress`
3. **Medium-term**: Add tests to verify address calculation matches deployment
4. **Long-term**: Review all CREATE2 usage for consistency

### For Resolver Team
1. **Continue** using event-based address discovery (current implementation is correct)
2. **Monitor** for contract updates that might fix the underlying issue
3. **Test** thoroughly when contracts are updated to ensure compatibility

### For Integration Partners
1. **Never** rely on `addressOfEscrowDst` for destination escrow addresses
2. **Always** parse the `DstEscrowCreated` event to get the actual address
3. **Store** both predicted and actual addresses for debugging

## Code References

- Contract issue: `contracts/BaseEscrowFactory.sol:159-161`
- Proxy hash calculation: `contracts/libraries/ProxyHashLib.sol:15-26`
- OpenZeppelin Clones: `lib/openzeppelin-contracts/contracts/proxy/Clones.sol:114-128`
- Resolver workaround: `bmn-evm-resolver/src/resolver/executor.ts:170-195`
- Test script workaround: `scripts/parse-dst-escrow.sh`

## Next Steps

1. **Contract Team**: Review and implement the proposed fix
2. **Testing**: Create comprehensive tests for CREATE2 address calculation
3. **Documentation**: Update integration guides with event parsing requirement
4. **Monitoring**: Track if any other contracts are affected by similar issues

## Conclusion

While the CREATE2 address mismatch is a critical issue, the implemented workarounds ensure the protocol remains functional. The resolver's event-based approach is robust and should continue to work even after the contract fix is deployed. However, fixing the root cause will improve developer experience and prevent future integration issues.