# Cross-Chain Atomic Swap Implementation Comparison

## Executive Summary

This document compares three implementations of cross-chain atomic swaps:
1. **1inch cross-chain-swap** - Production-ready implementation using CREATE2
2. **bmn-evm-contracts** - Simplified implementation using CREATE2 (Clones)
3. **bmn-evm-resolver** - TypeScript/Deno resolver with extensive documentation

## Key Architectural Differences

### 1. Address Generation Method

| Implementation | Method | Validation | Complexity |
|---------------|--------|------------|------------|
| **1inch** | CREATE2 | Simple address check | Low - Direct comparison |
| **bmn-evm-contracts** | CREATE2 (Clones) | Immutables hash validation | Medium - Hash comparison |
| **bmn-evm-resolver** | Attempts to match factory | Complex reconstruction | High - Multiple failure points |

### 2. Immutables Handling

#### 1inch Approach
```solidity
// Emits complete immutables during creation
emit SrcEscrowCreated(immutables, immutablesComplement);

// Simple validation in Escrow.sol
if (Create2.computeAddress(immutablesHash, PROXY_BYTECODE_HASH, FACTORY) != address(this)) {
    revert InvalidImmutables();
}
```

#### bmn-evm-contracts Approach
```solidity
// Simplified event emission
event SrcEscrowCreated(
    address indexed escrow,
    bytes32 indexed orderHash,
    address indexed maker,
    address taker,
    uint256 amount
);

// Uses Clones library for deployment
escrow = ESCROW_SRC_IMPLEMENTATION.cloneDeterministic(salt);
```

#### bmn-evm-resolver Issues
- Attempts to reconstruct immutables off-chain
- Cannot match factory's internal computation
- Order hash mismatch prevents validation
- Missing exact block.timestamp from creation

### 3. Event Architecture

| Implementation | Event Data | Purpose | Issue Resolution |
|---------------|------------|---------|------------------|
| **1inch** | Full immutables struct | Complete data for withdrawal | Events are source of truth |
| **bmn-evm-contracts** | Partial data (address, hash, amounts) | Basic tracking | Missing data for reconstruction |
| **bmn-evm-resolver** | Parses partial events | Attempts reconstruction | Cannot match on-chain computation |

### 4. Contract Inheritance Structure

#### 1inch
```
BaseEscrow → Escrow → EscrowSrc/EscrowDst
BaseEscrowFactory → EscrowFactory
```

#### bmn-evm-contracts
```
BaseEscrow → Escrow → EscrowSrc/EscrowDst
SimplifiedEscrowFactory (standalone)
```

### 5. Security Features

| Feature | 1inch | bmn-evm-contracts | bmn-evm-resolver |
|---------|-------|-------------------|------------------|
| Resolver Whitelist | ✅ Via Settlement | ✅ Mapping-based | ✅ Checks whitelist |
| Maker Whitelist | ✅ In extraData | ✅ Optional flag | N/A |
| Emergency Pause | ❌ | ✅ | N/A |
| Access Token | ✅ | ✅ | N/A |
| Merkle Validation | ✅ MerkleStorageInvalidator | ❌ | ❌ |

### 6. PostInteraction Handling

#### 1inch
- Complex extraData parsing
- Fee calculations integrated
- Supports custom post-interactions
- Merkle tree support for partial fills

#### bmn-evm-contracts
- Simplified postInteraction
- Direct token transfer from taker
- No fee handling in base implementation
- Single fill only

### 7. Critical Issue: Source Withdrawal

The bmn-evm-resolver identifies a critical blocker:

**Problem**: Source withdrawals fail with `InvalidImmutables()` error

**Root Cause**:
1. Factory computes immutables using:
   - Exact block.timestamp during fill
   - Internal order hash computation
   - Transaction context unavailable off-chain

2. Resolver cannot reconstruct:
   - Order hash differs from protocol's computation
   - Timelock packing requires exact timestamp
   - Factory has hidden logic not in ABI

**1inch Solution**:
- Emits complete immutables in `SrcEscrowCreated` event
- Never attempts reconstruction
- Uses emitted data directly for withdrawal

## Implementation Maturity Comparison

| Aspect | 1inch | bmn-evm-contracts | bmn-evm-resolver |
|--------|-------|-------------------|------------------|
| Production Ready | ✅ | ⚠️ (needs events) | ❌ (blocked) |
| Gas Optimization | ✅ High (1M runs) | ✅ High (1M runs) | N/A |
| Test Coverage | ✅ Comprehensive | ⚠️ Basic | ✅ Extensive |
| Documentation | ✅ Complete | ✅ Good | ✅ Excellent |
| Multi-chain Support | ✅ 14+ chains | ⚠️ Base/Optimism | ⚠️ Test only |

## Key Technical Decisions

### 1. CREATE2 vs CREATE3
- **1inch & bmn**: Use CREATE2 for simpler validation
- **Initial bmn**: Attempted CREATE3, added complexity

### 2. Event Emission Strategy
- **1inch**: Emit everything needed upfront
- **bmn**: Minimal events causing reconstruction issues

### 3. Validation Approach
- **1inch**: Simple address comparison
- **bmn**: Complex immutables validation

### 4. Factory Architecture
- **1inch**: Inherited from Settlement/FeeTaker
- **bmn**: Simplified standalone factory

## Recommendations for bmn-evm-contracts

### Immediate Fixes (Required)
1. **Add comprehensive event emission**:
```solidity
event SrcEscrowCreated(
    address indexed escrow,
    IBaseEscrow.Immutables immutables,
    DstImmutablesComplement complement
);
```

2. **Store immutables during creation**:
```solidity
mapping(bytes32 => IBaseEscrow.Immutables) public escrowImmutables;
```

### Medium-term Improvements
1. Switch to 1inch's validation pattern
2. Add Merkle support for partial fills
3. Implement fee calculation logic
4. Add transaction tracing tools

### Long-term Enhancements
1. Multi-chain deployment scripts
2. Comprehensive test suite
3. Security audit
4. Monitoring infrastructure

## Critical Path to Production

1. **Fix Events** (1-2 days)
   - Modify factory to emit full immutables
   - Update resolver to parse complete events

2. **Test End-to-End** (2-3 days)
   - Verify source withdrawals work
   - Test cancellation flows
   - Validate timelock windows

3. **Security Review** (1 week)
   - Audit immutables computation
   - Review validation logic
   - Test edge cases

4. **Deploy to Testnet** (3-5 days)
   - Deploy on Sepolia/Goerli
   - Run integration tests
   - Monitor for issues

## Conclusion

The bmn implementation has a solid foundation but lacks the critical event emission that makes 1inch's solution work. The architecture is sound, but the attempt to reconstruct immutables off-chain is fundamentally flawed. 

**Key Takeaway**: Emit complete data at creation time, store it, and use it unchanged for withdrawal. This is the proven pattern that works in production.

## Status Summary

- **1inch**: ✅ Production-ready, battle-tested
- **bmn-contracts**: ⚠️ 70% complete, needs event fixes
- **bmn-resolver**: ❌ Blocked by immutables validation

The path forward is clear: adopt 1inch's event emission pattern to unblock source withdrawals and achieve full functionality.