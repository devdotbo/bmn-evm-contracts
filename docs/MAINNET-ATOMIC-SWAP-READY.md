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
- **BMN Token**: `0x8287CD2aC7E227D9D927F998EB600a0683a832A1` (6 decimals)

All contracts are verified on both [Basescan](https://basescan.org/address/0xc72ed1E8a0649e51Cd046a0FfccC8f8c0bf385Fa#code) and [Etherlink Explorer](https://explorer.etherlink.com/address/0xc72ed1E8a0649e51Cd046a0FfccC8f8c0bf385Fa/contracts#address-tabs).

## Running the Mainnet Atomic Swap Test

### Prerequisites
1. Ensure Alice and Bob have BMN tokens on their respective chains:
   - Alice needs at least 11 BMN on Base (10 for swap + 1 safety deposit)
   - Bob needs at least 11 BMN on Etherlink

### Quick Test
Run the automated test script:
```bash
./scripts/test-crosschain-swap.sh
```

This script will:
1. Create source escrow on Base (Alice locks 10 BMN)
2. Create destination escrow on Etherlink (Bob locks 10 BMN)
3. Alice withdraws from destination (reveals secret)
4. Bob withdraws from source (using revealed secret)
5. Show final balances

### Manual Step-by-Step Test
For more control, use the Forge script directly:

```bash
# Step 1: Create source escrow on Base
source .env && ACTION=create-src forge script script/TestCrossChainSwap.s.sol \
    --rpc-url $BASE_RPC_URL \
    --broadcast \
    --private-key $ALICE_PRIVATE_KEY

# Step 2: Create destination escrow on Etherlink  
source .env && ACTION=create-dst forge script script/TestCrossChainSwap.s.sol \
    --rpc-url $ETHERLINK_RPC_URL \
    --broadcast \
    --private-key $RESOLVER_PRIVATE_KEY

# Step 3: Alice withdraws from destination (reveals secret)
source .env && ACTION=withdraw-dst forge script script/TestCrossChainSwap.s.sol \
    --rpc-url $ETHERLINK_RPC_URL \
    --broadcast \
    --private-key $ALICE_PRIVATE_KEY

# Step 4: Bob withdraws from source
source .env && ACTION=withdraw-src forge script script/TestCrossChainSwap.s.sol \
    --rpc-url $BASE_RPC_URL \
    --broadcast \
    --private-key $RESOLVER_PRIVATE_KEY

# Check balances at any time
source .env && ACTION=check-balances forge script script/TestCrossChainSwap.s.sol \
    --rpc-url $BASE_RPC_URL
```

### Expected Results
After a successful swap:
- Alice: -10 BMN on Base, +10 BMN on Etherlink
- Bob: +10 BMN on Base, -10 BMN on Etherlink

## Technical Details

### How CREATE2 Solved the Problem
1inch uses CREATE3 for cross-chain consistency, but Etherlink doesn't support CREATE3. We solved this by:
1. Using the standard CREATE2 factory at `0x4e59b44847b379578588920cA78FbF26c0B4956C`
2. Deploying implementations with deterministic salts
3. Creating `CrossChainEscrowFactory` that accepts pre-deployed implementation addresses
4. Result: Identical addresses on both chains without CREATE3

### Key Innovation
The `CrossChainEscrowFactory` constructor accepts implementation addresses as parameters, allowing us to use the same factory bytecode with pre-deployed implementations. This ensures the factory itself has the same address on all chains.

## Next Steps
1. Run the test to verify the atomic swap works
2. Consider integrating with 1inch Limit Order Protocol for production
3. Deploy resolver infrastructure for automated swap execution