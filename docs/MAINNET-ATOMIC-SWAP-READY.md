# Mainnet Atomic Swap Test - Ready to Run

## Summary

Yes, we can now run mainnet atomic swaps! The cross-chain factory consistency issue has been resolved:

### What We Fixed
1. **Original Issue**: Different factory implementation addresses between Base and Etherlink caused `InvalidImmutables` errors
2. **Solution**: Deployed `CrossChainEscrowFactory` using CREATE2 with identical addresses on both chains
3. **Result**: All contracts now have matching addresses across chains

### Deployed Contracts (Same on Base & Etherlink)
- **CrossChainEscrowFactory**: `0xc72ed1E8a0649e51Cd046a0FfccC8f8c0bf385Fa`
- **EscrowSrc Implementation**: `0xcCF2DEd118EC06185DC99E1a42a078754ae9c84c`
- **EscrowDst Implementation**: `0xb5A9FBEB81830006A9C03aBB33d02574346C5A9a`
- **BMN Token**: `0x8287CD2aC7E227D9D927F998EB600a0683a832A1` (18 decimals)

All contracts are verified on both [Basescan](https://basescan.org/address/0xc72ed1E8a0649e51Cd046a0FfccC8f8c0bf385Fa#code) and [Etherlink Explorer](https://explorer.etherlink.com/address/0xc72ed1E8a0649e51Cd046a0FfccC8f8c0bf385Fa/contracts#address-tabs).

## Running the Mainnet Atomic Swap Test

### Prerequisites
1. Ensure Alice and Bob have BMN tokens on their respective chains:
   - Alice needs at least 11 BMN on Base (10 for swap + 1 safety deposit)
   - Bob needs at least 11 BMN on Etherlink

### Testing Options

For testing, use the scripts documented in [RESOLVER-AGENT-GUIDE.md](./RESOLVER-AGENT-GUIDE.md):

```bash
# Deploy test infrastructure
./scripts/run-mainnet-test.sh deploy

# Execute atomic swap
./scripts/run-mainnet-test.sh swap

# Check balances
./scripts/run-mainnet-test.sh check
```

### Expected Results
After a successful swap:
- Alice: -10 BMN on Base, +10 BMN on Etherlink
- Bob: +10 BMN on Base, -10 BMN on Etherlink

## Technical Details

### CREATE2 Implementation
See [CREATE3_DEPLOYMENT_STRATEGY.md](./CREATE3_DEPLOYMENT_STRATEGY.md) for how we achieved cross-chain address consistency without CREATE3.

### Timelock Configuration
- **Source Withdrawal**: 0-300s (5 min) - Taker only  
- **Source Public**: 300-600s (5-10 min) - Anyone
- **Source Cancel**: 600-900s (10-15 min) - Maker only
- **Source Public Cancel**: 900s+ (15 min+) - Anyone

### Integration
For production integration with 1inch Limit Order Protocol, see [CROSSCHAIN-FACTORY-USAGE.md](./CROSSCHAIN-FACTORY-USAGE.md).