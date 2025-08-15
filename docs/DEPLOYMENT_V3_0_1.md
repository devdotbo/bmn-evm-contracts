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

## Deployed Addresses

### Base (Chain ID: 8453)
- **SimplifiedEscrowFactory**: `0x4E03F2dA3433626c4ed65544b6A99a013f5768d2` ✅ Verified
- **EscrowSrc Implementation**: `0xA835C525d0BD76baFC56920230E13fD37015E7D2` ✅ Verified
- **EscrowDst Implementation**: `0xaAB8a9cd52f55c536b776172e2C2CfdB6444359e` ✅ Verified
- **Basescan**: https://basescan.org/address/0x4E03F2dA3433626c4ed65544b6A99a013f5768d2

### Optimism (Chain ID: 10)
- **SimplifiedEscrowFactory**: `0x0EB761170E01d403a84d6237b5A1776eE2091eA3` ✅ Verified
- **EscrowSrc Implementation**: `0x92BB1E1c068fF5d26fCf4031193618FEaCfcC593` ✅ Verified
- **EscrowDst Implementation**: `0xbFa072CCB0d0a6d31b00A70718b75C1CDA09De73` ✅ Verified
- **Optimistic Etherscan**: https://optimistic.etherscan.io/address/0x0EB761170E01d403a84d6237b5A1776eE2091eA3

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
// Base
const FACTORY_ADDRESS_BASE = "0x4E03F2dA3433626c4ed65544b6A99a013f5768d2";

// Optimism
const FACTORY_ADDRESS_OPTIMISM = "0x0EB761170E01d403a84d6237b5A1776eE2091eA3";
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

## Gas Costs
- **Deployment Gas (Base)**: ~3,907,217 gas
- **Deployment Cost (Base)**: ~0.000009 ETH
- **Deployment Gas (Optimism)**: ~3,907,201 gas
- **Deployment Cost (Optimism)**: ~0.00000009 ETH

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
- Base: `./deployments/v3_0_1_8453_1755299333.json`
- Optimism: `./deployments/v3_0_1_10_1755299417.json`
- Broadcast: `./broadcast/DeployV3_0_1.s.sol/`