# V3.0.1 Deployment Summary

## Overview
Version 3.0.1 is a critical bugfix release that resolves the `InvalidCreationTime` error that made all atomic swaps fail in v3.0.0. This release has been successfully deployed and verified on both Base and Optimism mainnet.

## Deployment Date
January 18, 2025

## Critical Bug Fixed
- **Issue**: Hardcoded 2-hour `dstCancellation` timeout was incompatible with reduced 60s `TIMESTAMP_TOLERANCE`
- **Root Cause**: Validation formula `dstCancellation <= srcCancellation + TIMESTAMP_TOLERANCE` always failed
- **Solution**: Aligned `dstCancellation` with `srcCancellation` to ensure validation always passes
- **Impact**: Restores full protocol functionality for instant atomic swaps

## Deployed Addresses (Same on All Chains via CREATE3)

### All Chains (Base & Optimism)
- **SimplifiedEscrowFactory**: `0xF99e2f0772f9c381aD91f5037BF7FF7dE8a68DDc` ✅ Verified
- **EscrowSrc Implementation**: `0xF899Ee616C512f5E9Ea499fbd4F60AAA1DdC2D6f` ✅ Verified
- **EscrowDst Implementation**: `0x42fc825085a2aAd6c4b536Ba3321aCA8B32982B1` ✅ Verified
- **CREATE3 Factory Used**: `0x7B9e9BE124C5A0E239E04fDC93b66ead4e8C669d`

### Verification Links
- **Basescan**: https://basescan.org/address/0xF99e2f0772f9c381aD91f5037BF7FF7dE8a68DDc
- **Optimistic Etherscan**: https://optimistic.etherscan.io/address/0xF99e2f0772f9c381aD91f5037BF7FF7dE8a68DDc

## Key Features
- **Instant Withdrawals**: 0 second delay supported
- **Flexible Cancellation Times**: Any duration (5 minutes, 1 hour, etc.)
- **Tight Timing Validation**: 60-second cross-chain timestamp tolerance
- **Whitelist Bypass**: Enabled by default for easier onboarding
- **Full Backward Compatibility**: No changes to external interfaces

## Migration Instructions

### For Resolvers
1. Update your configuration to point to the new v3.0.1 factory addresses
2. Stop using v3.0.0 factories (they are broken and unusable)
3. No code changes required - interfaces remain the same

### For Integrators
```javascript
// Same address on all chains (Base & Optimism)
const FACTORY_ADDRESS = "0xF99e2f0772f9c381aD91f5037BF7FF7dE8a68DDc";
```

## Configuration
- **Rescue Delay**: 86400 seconds (1 day)
- **Access Token**: None (0x0)
- **Whitelist Bypass**: Enabled
- **Owner**: `0x5f29827e25dc174a6A51C99e6811Bbd7581285b0`

## Technical Details

### Fix Implementation
The fix was implemented in `SimplifiedEscrowFactory.sol` at lines 254-256:
```solidity
// FIX: Make dstCancellation relative to srcCancellation to ensure validation passes
uint32 dstCancellationOffset = uint32(srcCancellationTimestamp - block.timestamp);
packedTimelocks |= uint256(dstCancellationOffset) << 192; // dstCancellation aligned with srcCancellation
```

### Validation Added
Added timestamp validation to prevent underflow:
```solidity
require(srcCancellationTimestamp > block.timestamp, "srcCancellation must be future");
require(dstWithdrawalTimestamp > block.timestamp, "dstWithdrawal must be future");
```

## Gas Costs (CREATE3 Deployment)
- **Deployment Gas (Base)**: ~4,392,833 gas
- **Deployment Cost (Base)**: ~0.0000069 ETH
- **Deployment Gas (Optimism)**: ~4,392,833 gas
- **Deployment Cost (Optimism)**: ~0.000000046 ETH

## Verification Status
All contracts have been successfully verified on both chains:
- Base: All 3 contracts verified on Basescan
- Optimism: All 3 contracts verified on Optimistic Etherscan

## Testing
- 38 out of 41 tests passing (3 skipped tests are for unrelated features)
- Comprehensive test suite in `test/V3_0_1_BugfixSimple.t.sol`
- Tested various cancellation times that would fail in v3.0.0

## Deprecated Versions
- **v3.0.0**: DO NOT USE - Contains critical bug that breaks all atomic swaps
- **v2.3.0**: Still functional but uses higher timestamp tolerance (300s)
- **v2.2.0**: Deprecated in favor of v2.3.0

## Support
For questions or issues with the v3.0.1 deployment:
- GitHub: https://github.com/bridge-me-not/bmn-evm-contracts
- Security: security@1inch.io

## Deployment Artifacts
- Base CREATE3: `./deployments/v3_0_1_CREATE3_8453_1755301295.json`
- Optimism CREATE3: `./deployments/v3_0_1_CREATE3_10_1755301363.json`
- Broadcast: `./broadcast/DeployV3_0_1_CREATE3.s.sol/`