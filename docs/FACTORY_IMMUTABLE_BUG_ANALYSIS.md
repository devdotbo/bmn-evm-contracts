# FACTORY Immutable Bug Analysis and Solution

## Executive Summary

The v3.0.1 deployment (and v3.0.0, v2.2.0, v2.1.0) contains a critical bug where the `FACTORY` immutable in escrow implementations incorrectly captures the CREATE3 factory address instead of the actual SimplifiedEscrowFactory address. This causes all escrow operations to fail with `InvalidImmutables()` error. The v2.3.0 deployment solved this elegantly by having the factory deploy its own implementations.

## The Bug

### Root Cause

In `BaseEscrow.sol:33`:
```solidity
address public immutable FACTORY = msg.sender;
```

When implementations are deployed via CREATE3:
- `msg.sender` during deployment = CREATE3 Factory (`0x7B9e9BE124C5A0E239E04fDC93b66ead4e8C669d`)
- `FACTORY` immutable gets permanently set to CREATE3 factory address
- But proxy clones are deployed by SimplifiedEscrowFactory (`0xF99e2f0772f9c381aD91f5037BF7FF7dE8a68DDc`)

### Why Validation Fails

The validation in `Escrow.sol`:
```solidity
function _validateImmutables(Immutables calldata immutables) internal view virtual override {
    bytes32 salt = immutables.hash();
    if (Create2.computeAddress(salt, PROXY_BYTECODE_HASH, FACTORY) != address(this)) {
        revert InvalidImmutables();
    }
}
```

- Computes expected address using `FACTORY` (CREATE3 factory)
- Actual proxy deployed by SimplifiedEscrowFactory
- Computed address ≠ Actual address
- **Result: InvalidImmutables() error on every operation**

## Version History

### v2.1.0 & v2.2.0 - HAD THE BUG
- Implementations deployed via CREATE3
- Factory deployed via CREATE3
- `FACTORY = msg.sender` captured CREATE3 factory address
- **Status: BROKEN**

### v2.3.0 - FIXED THE BUG
- Factory deploys its own implementations in constructor
- `FACTORY = msg.sender` correctly captures factory address
- **Status: WORKING**

### v3.0.0 & v3.0.1 - REINTRODUCED THE BUG
- Went back to CREATE3 for implementations
- `FACTORY = msg.sender` again captures CREATE3 factory
- **Status: BROKEN**

## The v2.3 Solution

### Implementation

```solidity
// SimplifiedEscrowFactoryV2_3.sol
contract SimplifiedEscrowFactoryV2_3 is SimplifiedEscrowFactory {
    constructor(IERC20 accessToken, address _owner, uint32 rescueDelay)
        SimplifiedEscrowFactory(
            address(new EscrowSrc(rescueDelay, accessToken)),  // Factory deploys this
            address(new EscrowDst(rescueDelay, accessToken)),  // Factory deploys this
            _owner
        )
    {}
}
```

### Deployment Flow

```
Step 1: Deploy Factory via CREATE3
═══════════════════════════════════

   Deployer (0x5f29...)
        │
        │ calls deploy(salt, bytecode)
        ↓
   CREATE3 Factory (0x7B9e9...)
        │
        │ deploys via CREATE3
        ↓
   SimplifiedEscrowFactoryV2_3 (0xdebE6F...)
        │
        │ in constructor, deploys with 'new'
        ├──→ new EscrowSrc(...) ──→ EscrowSrc Implementation
        │                             └─→ FACTORY = msg.sender = 0xdebE6F... ✅
        │
        └──→ new EscrowDst(...) ──→ EscrowDst Implementation
                                      └─→ FACTORY = msg.sender = 0xdebE6F... ✅

Result:
• Factory at same address on all chains (via CREATE3)
• Implementations at DIFFERENT addresses per chain
• FACTORY immutable correctly points to factory
```

### Runtime Validation

```
Step 2: Escrow Creation & Validation
═════════════════════════════════════

   User calls createSrcEscrow()
        ↓
   SimplifiedEscrowFactoryV2_3 (0xdebE6F...)
        │
        │ cloneDeterministic(salt)
        ↓
   Escrow Proxy (0xABCD...)
        │
        │ withdraw() validates:
        ↓
   Compute: Create2.computeAddress(
       salt,
       PROXY_BYTECODE_HASH,
       FACTORY  // 0xdebE6F... ✅ (correct factory!)
   ) = 0xABCD...
        │
        ↓
   Check: computed == address(this)
        │
        ↓
   VALIDATION PASSES! ✅
```

### Why It Works

**Key Insight**: The factory that deploys the implementations (`msg.sender`) is the same factory that deploys the proxy clones.

| Aspect | v3.0.1 (Broken) | v2.3 (Working) |
|--------|----------------|----------------|
| Implementation Deployer | CREATE3 Factory | SimplifiedEscrowFactory |
| FACTORY Immutable Value | 0x7B9e9... (CREATE3) | 0xdebE6F... (Factory) |
| Proxy Clone Deployer | SimplifiedEscrowFactory | SimplifiedEscrowFactory |
| Validation Expects From | CREATE3 Factory | SimplifiedEscrowFactory |
| Actual Proxy From | SimplifiedEscrowFactory | SimplifiedEscrowFactory |
| **Result** | **Mismatch - FAILS** | **Match - WORKS** |

## Alternative Solutions Considered

### 1. Pass Factory as Constructor Parameter
- **Pros**: Keep CREATE3 for everything
- **Cons**: Changes interface, circular dependency

### 2. Skip Validation
- **Pros**: Simple fix
- **Cons**: Loses security validation

### 3. Override Validation Logic
- **Pros**: No interface changes
- **Cons**: Hacky, requires hardcoded addresses

### 4. Use Factory Registry
- **Pros**: Flexible
- **Cons**: Complex, extra gas costs

## Trade-offs of v2.3 Approach

### Pros
- ✅ Factory at same address across all chains (CREATE3)
- ✅ FACTORY immutable is correct
- ✅ Validation works without modifications
- ✅ Clean, self-contained solution
- ✅ No hacky workarounds

### Cons
- ❌ Implementation addresses differ per chain
- ❌ Slightly higher deployment gas (3 contracts in one transaction)
- ❌ Can't reuse existing implementations

## Recommendation

**Use the v2.3 approach** for any new deployment:

1. Create a factory contract that deploys its own implementations in the constructor
2. Use CREATE3 only for the factory itself (maintains cross-chain consistency)
3. Accept that implementation addresses will differ per chain (acceptable trade-off)

This ensures the FACTORY immutable correctly captures the factory address, making validation work without any modifications or workarounds.

## Critical Lesson

When using immutables that capture `msg.sender` in a proxy pattern:
- **Consider who deploys the implementation** - this becomes the immutable value
- **Ensure consistency** between who the immutable points to and who actually deploys proxies
- **Test the full flow** including validation before mainnet deployment

The v2.3 solution elegantly solves this by ensuring the factory deploys both implementations and proxies, maintaining consistency throughout the system.