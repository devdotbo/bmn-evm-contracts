# Factory v2.1.0 Deployment Runbook

## Pre-Deployment Checklist

- [ ] Ensure .env file has DEPLOYER_PRIVATE_KEY set
- [ ] Verify deployer account has sufficient ETH/XTZ on all chains
- [ ] Confirm RPC URLs are working
- [ ] Run all tests locally
- [ ] Review security features in code
- [ ] Notify resolver operators of upcoming deployment

## Step 1: Final Code Verification

```bash
# Verify security features are present
grep -n "whitelistedResolvers\|emergencyPaused" contracts/CrossChainEscrowFactory.sol

# Run full test suite
source .env && forge test -vv

# Check compilation
forge build --sizes

# Verify version string
grep "VERSION.*=" contracts/CrossChainEscrowFactory.sol
# Should show: string public constant VERSION = "2.1.0-bmn-secure";
```

## Step 2: Deploy to Base Network

```bash
# Set environment for Base
export CHAIN_NAME="Base"
export RPC_URL=$BASE_RPC_URL

# Deploy factory v2
source .env && forge script script/DeployFactoryV2.s.sol \
  --rpc-url $BASE_RPC_URL \
  --broadcast \
  --verify \
  --etherscan-api-key $BASESCAN_API_KEY \
  -vvvv

# Save the deployed address
export BASE_FACTORY_V2=[DEPLOYED_ADDRESS]
echo "BASE_FACTORY_V2=$BASE_FACTORY_V2" >> deployments/base.env
```

## Step 3: Deploy to Etherlink Network

```bash
# Set environment for Etherlink
export CHAIN_NAME="Etherlink"
export RPC_URL=$ETHERLINK_RPC_URL

# Deploy factory v2
source .env && forge script script/DeployFactoryV2.s.sol \
  --rpc-url $ETHERLINK_RPC_URL \
  --broadcast \
  --legacy \
  -vvvv

# Save the deployed address
export ETHERLINK_FACTORY_V2=[DEPLOYED_ADDRESS]
echo "ETHERLINK_FACTORY_V2=$ETHERLINK_FACTORY_V2" >> deployments/etherlink.env
```

## Step 4: Deploy to Optimism Network

```bash
# Set environment for Optimism
export CHAIN_NAME="Optimism"
export RPC_URL=$OPTIMISM_RPC_URL

# Deploy factory v2
source .env && forge script script/DeployFactoryV2.s.sol \
  --rpc-url $OPTIMISM_RPC_URL \
  --broadcast \
  --verify \
  --etherscan-api-key $OPTIMISM_ETHERSCAN_API_KEY \
  -vvvv

# Save the deployed address
export OPTIMISM_FACTORY_V2=[DEPLOYED_ADDRESS]
echo "OPTIMISM_FACTORY_V2=$OPTIMISM_FACTORY_V2" >> deployments/optimism.env
```

## Step 5: Verify Deployments

### Base Verification
```bash
export FACTORY_V2_ADDRESS=$BASE_FACTORY_V2
source .env && forge script script/VerifyFactoryV2Security.s.sol \
  --rpc-url $BASE_RPC_URL \
  -vvv
```

### Etherlink Verification
```bash
export FACTORY_V2_ADDRESS=$ETHERLINK_FACTORY_V2
source .env && forge script script/VerifyFactoryV2Security.s.sol \
  --rpc-url $ETHERLINK_RPC_URL \
  -vvv
```

### Optimism Verification
```bash
export FACTORY_V2_ADDRESS=$OPTIMISM_FACTORY_V2
source .env && forge script script/VerifyFactoryV2Security.s.sol \
  --rpc-url $OPTIMISM_RPC_URL \
  -vvv
```

## Step 6: Whitelist Additional Resolvers

### Base
```bash
export FACTORY_V2_ADDRESS=$BASE_FACTORY_V2
export ACTION=add-resolver
export RESOLVER_ADDRESS=[RESOLVER_TO_ADD]

source .env && forge script script/ManageFactoryV2.s.sol \
  --rpc-url $BASE_RPC_URL \
  --broadcast \
  -vvv
```

### Etherlink
```bash
export FACTORY_V2_ADDRESS=$ETHERLINK_FACTORY_V2
export ACTION=add-resolver
export RESOLVER_ADDRESS=[RESOLVER_TO_ADD]

source .env && forge script script/ManageFactoryV2.s.sol \
  --rpc-url $ETHERLINK_RPC_URL \
  --broadcast \
  -vvv
```

### Optimism
```bash
export FACTORY_V2_ADDRESS=$OPTIMISM_FACTORY_V2
export ACTION=add-resolver
export RESOLVER_ADDRESS=[RESOLVER_TO_ADD]

source .env && forge script script/ManageFactoryV2.s.sol \
  --rpc-url $OPTIMISM_RPC_URL \
  --broadcast \
  -vvv
```

## Step 7: Test Emergency Functions

### Test Pause/Unpause (Base)
```bash
# Pause
export FACTORY_V2_ADDRESS=$BASE_FACTORY_V2
export ACTION=pause
source .env && forge script script/ManageFactoryV2.s.sol \
  --rpc-url $BASE_RPC_URL \
  --broadcast

# Verify paused
cast call $BASE_FACTORY_V2 "emergencyPaused()(bool)" --rpc-url $BASE_RPC_URL

# Unpause
export ACTION=unpause
source .env && forge script script/ManageFactoryV2.s.sol \
  --rpc-url $BASE_RPC_URL \
  --broadcast

# Verify unpaused
cast call $BASE_FACTORY_V2 "emergencyPaused()(bool)" --rpc-url $BASE_RPC_URL
```

## Step 8: Update Documentation

```bash
# Update CLAUDE.md with new addresses
cat << EOF >> CLAUDE.md

### Production Deployments (v2.1.0 - CURRENT)

**Deployment Date**: January 6, 2025
**Security Features**: Resolver whitelist, Emergency pause

- Base Factory: $BASE_FACTORY_V2
- Etherlink Factory: $ETHERLINK_FACTORY_V2  
- Optimism Factory: $OPTIMISM_FACTORY_V2
EOF

# Update resolver migration guide
sed -i "s/\[TO BE DEPLOYED\]/$BASE_FACTORY_V2/g" RESOLVER_MIGRATION_GUIDE.md
sed -i "s/\[TO BE DEPLOYED\]/$ETHERLINK_FACTORY_V2/g" RESOLVER_MIGRATION_GUIDE.md
sed -i "s/\[TO BE DEPLOYED\]/$OPTIMISM_FACTORY_V2/g" RESOLVER_MIGRATION_GUIDE.md

# Commit documentation updates
git add -A
git commit -m "Deploy factory v2.1.0 with security features to all chains"
```

## Step 9: Notify Stakeholders

### Create deployment summary
```bash
cat << EOF > deployments/v2.1.0-summary.md
# Factory v2.1.0 Deployment Summary

## Deployment Completed: $(date)

### Deployed Addresses
- Base: $BASE_FACTORY_V2
- Etherlink: $ETHERLINK_FACTORY_V2
- Optimism: $OPTIMISM_FACTORY_V2

### Security Features
- [OK] Resolver whitelist system active
- [OK] Emergency pause mechanism ready
- [OK] Initial resolver whitelisted

### Next Steps
1. Resolver operators to migrate within 24-48 hours
2. Monitor initial operations closely
3. Old factory deprecation in 30 days

### Verification Links
- Base: https://basescan.org/address/$BASE_FACTORY_V2
- Optimism: https://optimistic.etherscan.io/address/$OPTIMISM_FACTORY_V2
EOF

# Send to team
echo "Deployment complete. Summary saved to deployments/v2.1.0-summary.md"
```

## Step 10: Post-Deployment Monitoring

### Monitor factory events (first 24 hours)
```bash
# Base
cast logs --address $BASE_FACTORY_V2 --from-block latest --rpc-url $BASE_RPC_URL

# Etherlink  
cast logs --address $ETHERLINK_FACTORY_V2 --from-block latest --rpc-url $ETHERLINK_RPC_URL

# Optimism
cast logs --address $OPTIMISM_FACTORY_V2 --from-block latest --rpc-url $OPTIMISM_RPC_URL
```

### Check resolver activity
```bash
# Get factory status on all chains
for CHAIN in BASE ETHERLINK OPTIMISM; do
  echo "=== $CHAIN ==="
  FACTORY_VAR="${CHAIN}_FACTORY_V2"
  RPC_VAR="${CHAIN}_RPC_URL"
  
  export FACTORY_V2_ADDRESS=${!FACTORY_VAR}
  export ACTION=status
  
  source .env && forge script script/ManageFactoryV2.s.sol \
    --rpc-url ${!RPC_VAR} \
    -vvv
done
```

## Emergency Procedures

### If Critical Issue Found

1. **Pause all factories immediately**:
```bash
# Pause Base
export FACTORY_V2_ADDRESS=$BASE_FACTORY_V2
export ACTION=pause
source .env && forge script script/ManageFactoryV2.s.sol --rpc-url $BASE_RPC_URL --broadcast

# Pause Etherlink
export FACTORY_V2_ADDRESS=$ETHERLINK_FACTORY_V2
source .env && forge script script/ManageFactoryV2.s.sol --rpc-url $ETHERLINK_RPC_URL --broadcast

# Pause Optimism
export FACTORY_V2_ADDRESS=$OPTIMISM_FACTORY_V2
source .env && forge script script/ManageFactoryV2.s.sol --rpc-url $OPTIMISM_RPC_URL --broadcast
```

2. **Notify all resolver operators**
3. **Investigate and fix issue**
4. **Deploy fix if needed**
5. **Unpause when safe**

### Rollback Plan

If v2.1.0 has critical issues that can't be fixed:

1. Pause v2.1.0 factories
2. Direct resolvers back to v1.1.0 (if still safe)
3. Deploy v2.2.0 with fixes
4. Migrate to v2.2.0

## Success Criteria

- [ ] All three chains deployed successfully
- [ ] Security features verified on all chains
- [ ] At least one resolver whitelisted per chain
- [ ] Pause/unpause tested successfully
- [ ] Documentation updated
- [ ] Resolver operators notified
- [ ] First successful swap completed

## Deployment Log

| Time | Action | Status | Notes |
|------|--------|--------|-------|
| | Pre-deployment checks | | |
| | Base deployment | | |
| | Etherlink deployment | | |
| | Optimism deployment | | |
| | Verification scripts | | |
| | Documentation update | | |
| | Stakeholder notification | | |

---

**Runbook Version**: 1.0
**Created**: January 6, 2025
**Estimated Duration**: 2-3 hours
**Required Access**: Deployer private key, RPC endpoints, Etherscan API keys