# Factory Event Enhancement Deployment Task

## Objective
Deploy the upgraded CrossChainEscrowFactory with enhanced events to Base and Etherlink mainnet to solve Ponder indexing issues.

## Pre-Deployment Checklist

### 1. Environment Verification
- [ ] Verify `.env` file contains:
  - `DEPLOYER_PRIVATE_KEY` - Funded on both chains
  - `BASE_RPC_URL` - Base mainnet RPC endpoint
  - `ETHERLINK_RPC_URL` - Etherlink mainnet RPC endpoint
  - `BASESCAN_API_KEY` - For contract verification on Base

### 2. Account Preparation
- [ ] Check deployer address: `cast wallet address --private-key $DEPLOYER_PRIVATE_KEY`
- [ ] Verify ETH balance on Base: `cast balance <deployer> --rpc-url $BASE_RPC_URL`
- [ ] Verify XTZ balance on Etherlink: `cast balance <deployer> --rpc-url $ETHERLINK_RPC_URL`
- [ ] Ensure sufficient gas funds on both chains

### 3. Pre-Deployment Verification
- [ ] Run final build: `source .env && forge build`
- [ ] Run tests: `source .env && forge test --match-path test/FactoryEventEnhancement.t.sol -vvv`
- [ ] Verify CREATE3 factory exists at `0x7B9e9BE124C5A0E239E04fDC93b66ead4e8C669d` on both chains

## Deployment Steps

### Phase 1: Base Mainnet Deployment

```bash
# 1. Preview deployment (dry run)
source .env && forge script script/DeployFactoryUpgrade.s.sol --rpc-url $BASE_RPC_URL

# 2. Deploy with broadcast and verification
source .env && forge script script/DeployFactoryUpgrade.s.sol --rpc-url $BASE_RPC_URL --broadcast --verify

# 3. Save deployment output and transaction hash
# Expected new factory address: (will be deterministic via CREATE3)
```

### Phase 2: Verify Base Deployment

```bash
# 1. Check deployment succeeded
UPGRADED_FACTORY=<deployed_address> forge script script/VerifyFactoryUpgrade.s.sol --rpc-url $BASE_RPC_URL

# 2. Verify on BaseScan if not auto-verified
forge verify-contract <deployed_address> CrossChainEscrowFactory --chain-id 8453

# 3. Test with a sample transaction to verify events
# Create a test order and check event logs contain escrow address
```

### Phase 3: Etherlink Mainnet Deployment

```bash
# 1. Preview deployment (dry run)
source .env && forge script script/DeployFactoryUpgrade.s.sol --rpc-url $ETHERLINK_RPC_URL

# 2. Deploy with broadcast (use --slow for Etherlink)
source .env && forge script script/DeployFactoryUpgrade.s.sol --rpc-url $ETHERLINK_RPC_URL --broadcast --slow

# 3. Note: Etherlink may not support auto-verification
```

### Phase 4: Verify Etherlink Deployment

```bash
# 1. Check deployment succeeded
UPGRADED_FACTORY=<deployed_address> forge script script/VerifyFactoryUpgrade.s.sol --rpc-url $ETHERLINK_RPC_URL

# 2. Manually verify contract functionality
# Test event emission on Etherlink
```

## Post-Deployment Tasks

### 1. Update Documentation
- [ ] Record deployed addresses in deployment logs
- [ ] Update README with new factory addresses
- [ ] Document in deployment history

### 2. Indexer Migration
- [ ] Update Ponder configuration to use new factory address
- [ ] Remove factory pattern, use direct event indexing
- [ ] Test indexer catches new events correctly
- [ ] Monitor for successful Etherlink indexing

### 3. Verification Steps
- [ ] Create test order on Base, verify event includes escrow address
- [ ] Create test order on Etherlink, verify event includes escrow address
- [ ] Confirm Ponder successfully indexes without factory pattern
- [ ] Monitor gas costs match expectations

### 4. Communication
- [ ] Notify resolver operators of new factory address
- [ ] Update integration documentation
- [ ] Announce deployment completion

## Rollback Plan

If issues arise:
1. Indexers can continue using old factory (previous deployment still active)
2. Update indexer config to point back to old factory if needed
3. No on-chain rollback needed - old factory remains functional

## Expected Outcomes

- [OK] New factory deployed at same address on both chains
- [OK] Events now include escrow addresses as first indexed parameter
- [OK] Ponder can index Etherlink without factory pattern
- [OK] Gas costs increased by <1% per transaction
- [OK] Full backward compatibility maintained

## Important Notes

1. **CREATE3 Determinism**: The same factory address will be deployed on both chains
2. **No Downtime**: Old factory continues working during migration
3. **Event Format**: New events have escrow address as first parameter
4. **Existing Escrows**: Not affected - only new escrows use enhanced events

## Emergency Contacts

- Deploy any issues: Check deployment logs in `deployments/`
- Transaction failures: Verify gas prices and account balances
- Verification issues: Manual verification may be needed on Etherlink