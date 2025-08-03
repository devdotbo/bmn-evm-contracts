# BMN Token Balance Issue

## Summary
We deployed a new BMN Access Token V2 with 18 decimals to replace the previous version that had 0 decimals. The transfer transactions are successful, but balance queries return 0.

## Current State

### Contract Details
- **BMN Token V2 Address**: `0xf410a63e825C162274c3295F13EcA1Dd1202b5cC` (same on both Base and Etherlink)
- **Decimals**: 18 (verified via `decimals()` call)
- **Deployed using**: CREATE2 with salt `keccak256("BMN_ACCESS_TOKEN_V2_18_DECIMALS")`

### Observed Behavior

1. **Successful Transfers**:
   - Transaction: `0xb6f805090680ed9fe90cc7e0c0e1d110c7c435f2d35266be0b36cabd153490c9`
   - Transfer event emitted correctly
   - From: `0x5f29827e25dc174a6a51c99e6811bbd7581285b0` (deployer)
   - To: `0x70997970c51812dc3a010c7d01b50e0d17dc79c8` (Alice)
   - Amount: 100 BMN (100e18 wei)

2. **Balance Checks**:
   - Deployer balance: 900 BMN (correctly decreased from 1000)
   - Alice balance: **0** (should be 100)
   - Bob balance: **0** (should be 100 after Etherlink transfer)

### Technical Details

**Transfer Event Log**:
```json
{
  "address": "0xf410a63e825C162274c3295F13EcA1Dd1202b5cC",
  "topics": [
    "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef",
    "0x0000000000000000000000005f29827e25dc174a6a51c99e6811bbd7581285b0",
    "0x00000000000000000000000070997970c51812dc3a010c7d01b50e0d17dc79c8"
  ],
  "data": "0x0000000000000000000000000000000000000000000000056bc75e2d63100000"
}
```

### Commands Used

```bash
# Check balance (returns 0)
cast call 0xf410a63e825C162274c3295F13EcA1Dd1202b5cC "balanceOf(address)(uint256)" 0x70997970C51812dc3A010C7d01b50e0d17dc79C8 --rpc-url https://lb.drpc.org/base/***REMOVED***

# Check deployer balance (returns 900e18)
cast call 0xf410a63e825C162274c3295F13EcA1Dd1202b5cC "balanceOf(address)(uint256)" 0x5f29827e25dc174a6a51c99e6811Bbd7581285b0 --rpc-url https://lb.drpc.org/base/***REMOVED***
```

### Previous Context
- Originally deployed BMN token had 0 decimals (at address `0x18ae5BB6E03Dc346eA9fd1afA78FEc314343857e`)
- Updated BMNAccessTokenV2.sol to return 18 decimals in the `decimals()` function
- Deployed new version with different salt to get new address

### Hypothesis
The issue might be:
1. RPC node caching/sync issues
2. Contract state inconsistency
3. Potential issue with the ERC20 implementation in BMNAccessTokenV2

### Next Steps to Try
1. Check the contract code on-chain to verify deployment
2. Try direct state slot reading
3. Check on block explorer (Basescan)
4. Test with different RPC endpoints
5. Verify the _balances mapping is being updated correctly

### Files to Review
- `/contracts/BMNAccessTokenV2.sol` - The token contract
- `/script/DeployBMNV2Mainnet.s.sol` - The deployment script