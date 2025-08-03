# Mainnet Deployment Guide

## Overview
This guide outlines the complete process for deploying the CREATE2-fixed EscrowFactory contracts to Base and Etherlink mainnets.

## Pre-Deployment Checklist

### 1. Code Verification ✅
- [x] CREATE2 fix implemented in BaseEscrowFactory
- [x] Using Clones.predictDeterministicAddress instead of Create2.computeAddress
- [x] Local tests pass (`quick-create2-test.sh`)
- [ ] Fork tests pass on mainnet data
- [ ] All unit tests pass (`forge test`)

### 2. Security Review
- [ ] No hardcoded private keys or secrets
- [ ] All sensitive data in `.env` file
- [ ] Code reviewed by team
- [ ] No TODO or FIXME comments in production code

### 3. Infrastructure Requirements
- [ ] Sufficient ETH on Base mainnet (min 0.01 ETH)
- [ ] Sufficient ETH on Etherlink mainnet (min 0.1 ETH)
- [ ] Reliable RPC endpoints configured
- [ ] Etherscan API keys ready

### 4. Testing Progression
- [x] Local Anvil test ✅
- [ ] Mainnet fork test
- [ ] Testnet deployment
- [ ] Testnet end-to-end test (24-48 hours)
- [ ] Mainnet deployment

## Deployment Steps

### Step 1: Pre-Deployment Verification
```bash
./scripts/verify-before-mainnet.sh
```
This script checks:
- Local CREATE2 fix works
- Contracts compile
- Tests pass
- Git status is clean
- Environment variables are set
- BaseEscrowFactory has the fix

### Step 2: Fork Testing (RECOMMENDED)
```bash
./scripts/test-fork-simple.sh
```
Tests the deployment on forked mainnet data without spending real ETH.

### Step 3: Testnet Deployment (CRITICAL)
```bash
./scripts/deploy-fixed-testnets.sh
```
Deploy to:
- Base Sepolia
- Etherlink Testnet

Wait 24-48 hours and run multiple test swaps.

### Step 4: Mainnet Deployment
```bash
./scripts/deploy-mainnet-with-checks.sh
```
This script:
1. Confirms you want to deploy to mainnet (multiple times)
2. Checks ETH balances on both chains
3. Verifies RPC connectivity
4. Deploys factories with CREATE2 fix
5. Saves deployment addresses
6. Attempts to verify on Etherscan

## Post-Deployment Steps

### 1. Verification
- [ ] Contracts verified on Base explorer
- [ ] Contracts verified on Etherlink explorer (if available)
- [ ] Factory addresses saved in `deployments/mainnet-latest.json`

### 2. Resolver Update
Update the resolver with new factory addresses:
```json
{
  "base_mainnet_factory": "0x...",
  "etherlink_mainnet_factory": "0x..."
}
```

### 3. End-to-End Test
Run a small test swap (e.g., $10 worth) to verify:
- Address prediction works correctly
- Escrows deploy to expected addresses
- Cross-chain atomic swap completes successfully

### 4. Monitoring
- Monitor for 24 hours before public announcement
- Check for any failed transactions
- Verify gas costs are reasonable

## Rollback Plan
If issues are discovered post-deployment:
1. Stop resolver from processing new orders
2. Allow existing swaps to complete/cancel
3. Deploy updated factories with new addresses
4. Update resolver to use new factories

## Important Addresses

### Tokens (Mainnet)
- Base TKA: `0x...` (update with actual)
- Etherlink TKB: `0x...` (update with actual)

### Access Token
- Mainnet: Set in `MAINNET_ACCESS_TOKEN` env var

### Configuration
- Rescue Delay: 86400 seconds (1 day)
- Deployed At Offset: 300 seconds (5 minutes)

## Emergency Contacts
- Technical Lead: @username
- Security Team: security@1inch.io
- On-call Engineer: @oncall

## Deployment Log Template
```
Date: YYYY-MM-DD HH:MM UTC
Deployer: 0x...
Base Mainnet Factory: 0x...
Etherlink Mainnet Factory: 0x...
Gas Used (Base): X ETH
Gas Used (Etherlink): X ETH
Issues Encountered: None / Description
Status: Success / Failed
```

## Checklist Summary
- [ ] Run pre-deployment verification
- [ ] Test on forks
- [ ] Deploy to testnets
- [ ] Test on testnets (24-48h)
- [ ] Get team approval
- [ ] Deploy to mainnet
- [ ] Verify contracts
- [ ] Update resolver
- [ ] Run test swap
- [ ] Monitor for 24h
- [ ] Public announcement