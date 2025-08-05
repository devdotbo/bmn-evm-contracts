# Factory Event Enhancement: Emitting Escrow Addresses

## Executive Summary

The current implementation of the Bridge Me Not (BMN) protocol's factory events does not emit the deployed escrow contract addresses, causing significant issues with the Ponder indexer on Etherlink due to block range limitations. This document proposes enhancing the factory events to include escrow addresses directly, eliminating the need for complex CREATE2 calculations and factory pattern usage in the indexer.

## Current Problem

### 1. Missing Escrow Addresses in Events

The current events emitted by the CrossChainEscrowFactory do not include the actual deployed escrow addresses:

```solidity
// Current SrcEscrowCreated event - missing escrow address
event SrcEscrowCreated(IBaseEscrow.Immutables srcImmutables, DstImmutablesComplement dstImmutablesComplement);

// Only DstEscrowCreated includes the address
event DstEscrowCreated(address escrow, bytes32 hashlock, Address taker);
```

### 2. Ponder Indexer Limitations

The Ponder v0.12 indexer faces critical issues:

- **Factory Pattern Block Range Bug**: When using the factory pattern to track dynamically created contracts, Ponder does not respect the configured block range limits
- **Etherlink Failure**: On Etherlink (chain 42793), this causes the indexer to attempt processing from block 0 instead of the configured start block, leading to RPC failures
- **Complex CREATE2 Calculations**: The indexer must recreate the CREATE2 address derivation logic, increasing complexity and potential for errors

### 3. Impact on Cross-Chain Operations

- **Delayed Event Processing**: Cannot efficiently track escrow creation events
- **Increased RPC Load**: Excessive calls due to factory pattern scanning
- **Maintenance Burden**: Complex address calculation logic must be maintained in multiple places

## Proposed Solution

### Enhanced Event Signatures

#### Before (Current Implementation)

```solidity
event SrcEscrowCreated(
    IBaseEscrow.Immutables srcImmutables, 
    DstImmutablesComplement dstImmutablesComplement
);

event DstEscrowCreated(
    address escrow, 
    bytes32 hashlock, 
    Address taker
);
```

#### After (Proposed Implementation)

```solidity
event SrcEscrowCreated(
    address indexed escrow,  // NEW: Add escrow address
    IBaseEscrow.Immutables srcImmutables, 
    DstImmutablesComplement dstImmutablesComplement
);

event DstEscrowCreated(
    address indexed escrow,  // Already present, make indexed
    bytes32 indexed hashlock,  // Make indexed for better querying
    Address taker
);
```

### Benefits of This Approach

1. **Simplified Indexing**: Direct address emission eliminates CREATE2 calculations
2. **Better Performance**: Indexed fields enable efficient event filtering
3. **Ponder Compatibility**: No factory pattern needed, respecting block ranges
4. **Reduced Complexity**: Simpler indexer implementation and maintenance
5. **Gas Efficiency**: Minimal gas cost increase (already computing the address)

## Implementation Details

### 1. BaseEscrowFactory.sol Modifications

```solidity
// In _postInteraction function (around line 114)
// Current implementation:
emit SrcEscrowCreated(immutables, immutablesComplement);

bytes32 salt = immutables.hashMem();
address escrow = _deployEscrow(salt, 0, ESCROW_SRC_IMPLEMENTATION);

// Proposed implementation:
bytes32 salt = immutables.hashMem();
address escrow = _deployEscrow(salt, 0, ESCROW_SRC_IMPLEMENTATION);

// Emit event AFTER deployment with escrow address
emit SrcEscrowCreated(escrow, immutables, immutablesComplement);
```

### 2. IEscrowFactory.sol Interface Update

```solidity
interface IEscrowFactory {
    // Updated event signatures
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
    
    // ... rest of interface remains unchanged
}
```

### 3. Example Complete Implementation

```solidity
// BaseEscrowFactory.sol - Modified _postInteraction
function _postInteraction(
    IOrderMixin.Order calldata order,
    bytes calldata extension,
    bytes32 orderHash,
    address taker,
    uint256 makingAmount,
    uint256 takingAmount,
    uint256 remainingMakingAmount,
    bytes calldata extraData
) internal override(BaseExtension, ResolverValidationExtension) {
    // ... existing logic ...

    // Deploy escrow first
    bytes32 salt = immutables.hashMem();
    address escrow = _deployEscrow(salt, 0, ESCROW_SRC_IMPLEMENTATION);
    
    // Emit event with escrow address
    emit SrcEscrowCreated(escrow, immutables, immutablesComplement);
    
    // Continue with balance checks
    if (escrow.balance < immutables.safetyDeposit || 
        IERC20(order.makerAsset.get()).safeBalanceOf(escrow) < makingAmount) {
        revert InsufficientEscrowBalance();
    }
}

// createDstEscrow already emits the address correctly
function createDstEscrow(
    IBaseEscrow.Immutables calldata dstImmutables, 
    uint256 srcCancellationTimestamp
) external payable {
    // ... existing logic ...
    
    address escrow = _deployEscrow(salt, msg.value, ESCROW_DST_IMPLEMENTATION);
    
    // ... transfer logic ...
    
    // Current implementation already emits escrow address
    emit DstEscrowCreated(escrow, dstImmutables.hashlock, dstImmutables.taker);
}
```

## Migration Strategy

### 1. Deployment Timeline

1. **Phase 1**: Deploy updated contracts to testnet
2. **Phase 2**: Update indexer to handle both event formats
3. **Phase 3**: Deploy to mainnet with coordinated indexer update
4. **Phase 4**: Deprecate old event handling after migration period

### 2. Backward Compatibility

- New indexer can handle both old and new event formats
- Use event signature to determine format version
- Maintain CREATE2 calculation as fallback for historical data

### 3. Indexer Migration Code

```typescript
// Ponder indexer example
ponder.on("CrossChainEscrowFactory:SrcEscrowCreated", async ({ event, context }) => {
  let escrowAddress: string;
  
  // Check if new format (has escrow address as first parameter)
  if (event.args.length === 3 && isAddress(event.args[0])) {
    // New format: extract address directly
    escrowAddress = event.args[0];
  } else {
    // Old format: calculate CREATE2 address (fallback)
    escrowAddress = calculateCreate2Address(event.args.srcImmutables);
  }
  
  // Continue processing...
});
```

## Impact on Existing Systems

### 1. Minimal Breaking Changes

- Event signature change requires indexer updates
- No changes to contract functionality
- No impact on user interactions

### 2. Benefits for Integrations

- Simpler integration for third-party indexers
- Reduced infrastructure requirements
- Better real-time tracking capabilities

### 3. Gas Cost Analysis

- Additional gas cost: ~2,100 gas for emitting address
- Percentage increase: <1% of total transaction cost
- Benefit: Significant reduction in RPC calls and indexing complexity

## Security Considerations

1. **No Security Impact**: Emitting addresses doesn't expose new information
2. **Verification**: Addresses can be verified against CREATE2 calculations
3. **Immutability**: Event data cannot be modified after emission

## Conclusion

Enhancing factory events to emit escrow addresses directly is a simple yet effective solution that:

- Resolves critical Ponder indexer issues on Etherlink
- Simplifies the overall system architecture
- Reduces maintenance burden
- Improves real-time tracking capabilities
- Has minimal gas cost impact

This change represents a best practice for factory patterns in blockchain development and aligns with modern indexing requirements.

## Appendix: Technical References

- [Ponder v0.12 Documentation](https://ponder.sh/docs)
- [CREATE2 Opcode Specification](https://eips.ethereum.org/EIPS/eip-1014)
- [Solidity Events Best Practices](https://docs.soliditylang.org/en/latest/contracts.html#events)