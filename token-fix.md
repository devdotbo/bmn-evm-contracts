# Token Funding Issue for Bridge-Me-Not Demo

## Issue Description

The resolver (Bob) is unable to execute orders because of insufficient token balance. The current test flow has a token distribution issue.

## Current Situation

1. **Alice's Order**: 
   - Offering: 100 TKA on Chain A
   - Requesting: 100 TKB on Chain A
   - Order created successfully with EIP-712 signature

2. **Bob's Balance Issue**:
   - Bob has 0 TKB on Chain A
   - The funding script (`fund-accounts.sh`) only mints TKB to Bob on Chain B
   - Bob needs TKB on Chain A to fulfill Alice's order

## Root Cause

The funding script has asymmetric token distribution:
- Chain A: Mints TKA to both Alice and Bob
- Chain B: Mints TKB only to Bob

But for the cross-chain swap demo to work:
- Alice needs TKA on Chain A (✓ she has it)
- Bob needs TKB on Chain A (✗ he doesn't have it)

## Required Fix

Please update the `fund-accounts.sh` script in the `bmn-evm-contracts` repository to:

1. Mint TKB to Bob on Chain A (not just Chain B)
2. Optionally, mint some TKA to Alice on Chain B for symmetry

## Suggested Change

In `fund-accounts.sh`, add:
```bash
# Chain A: Also mint TKB to Bob
cast send $TOKEN_B_CHAIN_A "mint(address,uint256)" $BOB "100000000000000000000" \
  --rpc-url http://localhost:8545 \
  --private-key $DEPLOYER_KEY
```

This will allow Bob to fulfill orders where Alice wants to swap TKA for TKB on the same chain.

## Current Console Output

The resolver is running correctly but cannot execute orders:
```
🔍 Checking for new orders...
Found 1 pending orders
Bob's TKB balance: 0
⚠️ Order 0xe78737ab... not profitable or insufficient balance
```

Once Bob has TKB on Chain A, the order execution should proceed successfully.