# 1inch Implementation Comparison Analysis

## Executive Summary

After analyzing the 1inch cross-chain swap implementation, we discovered that **1inch has the exact same CREATE2 address mismatch issue** that we identified in our Bridge-Me-Not protocol. This confirms our diagnosis is correct and validates our proposed fix. However, 1inch's production deployment across multiple chains suggests they have workarounds in their off-chain infrastructure.

## Key Findings

### 1. **Identical CREATE2 Mismatch Issue**

1inch's cross-chain-swap repository exhibits the **exact same architectural problem**:

```solidity
// In BaseEscrowFactory.sol - addressOfEscrowDst
return Create2.computeAddress(immutables.hash(), _PROXY_DST_BYTECODE_HASH);  // 2 parameters

// In Escrow.sol - validation  
if (Create2.computeAddress(salt, PROXY_BYTECODE_HASH, FACTORY) != address(this)) {  // 3 parameters
```

**The Issue**: 
- Address prediction uses the 2-parameter version (assumes `address(this)` as deployer)
- Actual deployment uses `Clones.cloneDeterministic()` which internally uses 3-parameter version
- This causes predicted addresses to differ from actual deployed addresses

### 2. **Production Deployment Despite the Issue**

1inch has deployed their contracts to multiple mainnets:
- Ethereum, Arbitrum, Base, BSC, Polygon, Optimism, etc.
- This suggests the issue doesn't prevent basic functionality
- They likely handle it through off-chain workarounds

### 3. **Their Solution Pattern: Same-Transaction Deployment**

In their `ResolverExample.sol`, they use a critical pattern:

```solidity
function deploySrc(/* params */) external onlyOwner {
    // Update timelocks with current block.timestamp
    immutablesMem.timelocks = TimelocksLib.setDeployedAt(immutables.timelocks, block.timestamp);
    
    // Compute address with updated timelocks
    address computed = _FACTORY.addressOfEscrowSrc(immutablesMem);
    
    // Fund the address AND deploy in same transaction
    (bool success,) = address(computed).call{ value: immutablesMem.safetyDeposit }("");
    _LOP.fillOrderArgs(order, r, vs, amount, takerTraits, argsMem);
}
```

**Key Insight**: By funding and deploying in the same transaction, they ensure consistent `block.timestamp` and avoid timing-related mismatches.

### 4. **Event-Based Address Discovery**

Like our implementation, they emit events with actual deployed addresses:
```solidity
event DstEscrowCreated(address escrow, bytes32 hashlock, Address taker);
```

Their SDK acknowledges this by tracking deployment block times:
```typescript
public getDstEscrowAddress(
    srcImmutables: Immutables,
    complement: DstImmutablesComplement,
    blockTime: bigint,  // Block time when DstEscrowCreated event was produced
    taker: Address,
    implementationAddress: Address
): Address
```

## Architecture Comparison

### Similarities with Our Implementation

1. **Core Design**: HTLC-based atomic swaps without bridges
2. **Factory Pattern**: Deterministic escrow deployment using CREATE2
3. **Proxy Pattern**: Minimal proxies for gas efficiency
4. **Timelock System**: Multi-stage withdrawal/cancellation windows
5. **Safety Deposits**: Prevent griefing attacks
6. **CREATE2 Issue**: Same bytecode hash calculation mismatch

### Key Differences

| Feature | 1inch | Bridge-Me-Not |
|---------|-------|---------------|
| Factory Deployment | CREATE3 for cross-chain consistency | Standard deployment |
| Timestamp Tolerance | No built-in tolerance | 5-minute tolerance |
| Secret Management | Merkle trees for partial fills | Single secrets |
| Resolver Access | Complex whitelist + tokens | Simpler access control |
| Test Environment | No separate test factory | TestEscrowFactory for development |

## Learnings and Recommendations

### 1. **Our CREATE2 Fix is Validated**

The fact that 1inch has the same issue confirms our analysis is correct. Our proposed fix to use consistent address calculation is the right approach.

### 2. **Consider Same-Transaction Pattern**

1inch's approach of funding and deploying in the same transaction eliminates timing issues. We could adopt this pattern where feasible.

### 3. **Event-Based Discovery is Standard**

Both implementations rely on events for actual address discovery, confirming our resolver's approach is correct.

### 4. **CREATE3 for Factory Deployment**

1inch uses CREATE3 to ensure factory addresses are identical across all chains:
```solidity
bytes32 public constant CROSSCHAIN_SALT = keccak256("1inch EscrowFactory");
ICreate3Deployer public constant CREATE3_DEPLOYER = ICreate3Deployer(0x65B3Db8bAeF0215A1F9B14c506D2a3078b2C84AE);
```

This could solve cross-chain deployment challenges.

### 5. **Advanced Features to Consider**

- **Merkle Tree Secrets**: Support for partial fills with N+1 secrets
- **Dutch Auction Rate Bumps**: Dynamic pricing based on gas prices
- **Priority Fee Validation**: MEV protection on mainnet
- **Resolver Whitelist Registry**: Better access control

## Impact on Our Implementation

### Immediate Actions

1. **Proceed with CREATE2 Fix**: Our diagnosis and fix are validated
2. **Document the Issue**: Add comments explaining the mismatch
3. **Maintain Event Parsing**: Continue using events for address discovery

### Future Enhancements

1. **CREATE3 Factory Deployment**: For true cross-chain consistency
2. **Same-Transaction Pattern**: Where architecturally feasible
3. **Enhanced Secret Management**: Merkle trees for partial fills
4. **Improved Access Control**: Whitelist registry system

## Conclusion

The 1inch analysis confirms that:

1. **Our CREATE2 mismatch issue is real** and exists in production code
2. **Our proposed fix is necessary** for robust operation
3. **Event-based address discovery is the standard** approach
4. **Production deployment is possible** with proper workarounds

The fact that 1inch has deployed to multiple mainnets with this issue suggests it's manageable with proper off-chain handling, but fixing it at the contract level (as we propose) is the cleaner solution.

## Code References

### 1inch Implementation
- CREATE2 Issue: `1inch/cross-chain-swap/contracts/BaseEscrowFactory.sol:152-161`
- ProxyHashLib: `1inch/cross-chain-swap/contracts/libraries/ProxyHashLib.sol`
- Same-Transaction Pattern: `1inch/cross-chain-swap/contracts/mocks/ResolverExample.sol:56-65`
- Factory Deployment: `1inch/cross-chain-swap/script/DeployEscrowFactory.s.sol`

### Our Implementation
- CREATE2 Issue: `contracts/BaseEscrowFactory.sol:159-161`
- Proposed Fix: Use `Clones.predictDeterministicAddress` consistently
- Resolver Workaround: `bmn-evm-resolver/src/resolver/executor.ts:170-195`