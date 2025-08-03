# Contract Verification Guide

This document provides instructions for verifying Bridge-Me-Not smart contracts on Base and Etherlink chains.

## Deployed Contracts

### Base & Etherlink (Same addresses on both chains)

| Contract | Address | Constructor Args |
|----------|---------|------------------|
| BMNAccessTokenV2 | `0x18ae5BB6E03Dc346eA9fd1afA78FEc314343857e` | owner: `0x5f29827e25dc174a6A51C99e6811Bbd7581285b0` |
| EscrowFactory | `0x068aABdFa6B8c442CD32945A9A147B45ad7146d2` | See detailed args below |
| EscrowSrc (Implementation) | `0x8f92DA1E1b537003569b7293B8063E6e79f27FC6` | rescueDelay: `86400`, accessToken: `0x18ae5BB6E03Dc346eA9fd1afA78FEc314343857e` |
| EscrowDst (Implementation) | `0xFd3114ef8B537003569b7293B8063E6e79f27FC6` | rescueDelay: `86400`, accessToken: `0x18ae5BB6E03Dc346eA9fd1afA78FEc314343857e` |

### EscrowFactory Constructor Arguments
- limitOrderProtocol: `0x0000000000000000000000000000000000000000`
- feeToken: `0x0000000000000000000000000000000000000000`
- accessToken: `0x18ae5BB6E03Dc346eA9fd1afA78FEc314343857e`
- owner: `0x5f29827e25dc174a6A51C99e6811Bbd7581285b0`
- rescueDelaySrc: `86400` (1 day)
- rescueDelayDst: `86400` (1 day)

## Verification Status

| Contract | Base | Etherlink |
|----------|------|-----------|
| BMNAccessTokenV2 | ❌ Not verified | ❌ Not verified |
| EscrowFactory | ❌ Not verified | ❌ Not verified |
| EscrowSrc | ❌ Not verified | ❌ Not verified |
| EscrowDst | ❌ Not verified | ❌ Not verified |

## Verification Instructions

### Prerequisites

1. **API Keys**: Add the following to your `.env` file:
   ```
   BASESCAN_API_KEY=YOUR_BASESCAN_API_KEY
   ```
   Get your API key from: https://basescan.org/myapikey

2. **Build contracts**: Ensure contracts are compiled:
   ```bash
   forge build
   ```

### Base Chain Verification

Base supports automated verification via Basescan API.

```bash
# Run the automated verification script
./scripts/verify-base.sh
```

The script will:
1. Check for BASESCAN_API_KEY in .env
2. Verify each contract using forge verify-contract
3. Display verification URLs for checking status

### Etherlink Chain Verification

Etherlink requires manual verification through their explorer interface.

```bash
# Generate verification files
./scripts/verify-etherlink.sh
```

The script will:
1. Generate flattened source files in `verification/etherlink/`
2. Create constructor argument files
3. Display manual verification instructions

#### Manual Steps for Etherlink:

1. Navigate to the contract on [Etherlink Explorer](https://explorer.etherlink.com/)
2. Click "Contract" tab → "Verify and Publish"
3. Use these settings:
   - **Compiler Type**: Solidity (Single file)
   - **Compiler Version**: v0.8.23+commit.f704f362
   - **License**: MIT
   - **Optimization**: Enabled
   - **Runs**: 1000000
   - **Via-IR**: Yes

4. Copy source code from `verification/etherlink/<Contract>_flattened.sol`
5. Copy constructor args from `verification/etherlink/<Contract>_constructor_args.txt`
6. Complete verification

## Compiler Settings

All contracts use:
- Solidity: 0.8.23
- Optimizer: Enabled
- Runs: 1,000,000
- Via-IR: Enabled

## Verification URLs

### Base
- BMNAccessTokenV2: https://basescan.org/address/0x18ae5BB6E03Dc346eA9fd1afA78FEc314343857e#code
- EscrowFactory: https://basescan.org/address/0x068aABdFa6B8c442CD32945A9A147B45ad7146d2#code
- EscrowSrc: https://basescan.org/address/0x8f92DA1E1b537003569b7293B8063E6e79f27FC6#code
- EscrowDst: https://basescan.org/address/0xFd3114ef8B537003569b7293B8063E6e79f27FC6#code

### Etherlink
- BMNAccessTokenV2: https://explorer.etherlink.com/address/0x18ae5BB6E03Dc346eA9fd1afA78FEc314343857e
- EscrowFactory: https://explorer.etherlink.com/address/0x068aABdFa6B8c442CD32945A9A147B45ad7146d2
- EscrowSrc: https://explorer.etherlink.com/address/0x8f92DA1E1b537003569b7293B8063E6e79f27FC6
- EscrowDst: https://explorer.etherlink.com/address/0xFd3114ef8B537003569b7293B8063E6e79f27FC6

## Troubleshooting

### Base Verification Issues

1. **API Key Error**: Ensure BASESCAN_API_KEY is set in .env
2. **Rate Limiting**: Wait a few seconds between verification attempts
3. **Already Verified**: Check if contract is already verified on explorer

### Etherlink Verification Issues

1. **Source Code Mismatch**: Ensure you're using the exact compiler settings
2. **Constructor Args**: Use the encoded hex values from the generated files
3. **License**: Must match the SPDX identifier in the source code (MIT)

## Helper Commands

```bash
# View encoded constructor arguments
forge script script/VerifyContracts.s.sol

# Generate flattened source for a specific contract
forge flatten contracts/BMNAccessTokenV2.sol

# Encode constructor arguments manually
cast abi-encode "constructor(address)" "0x5f29827e25dc174a6A51C99e6811Bbd7581285b0"
```