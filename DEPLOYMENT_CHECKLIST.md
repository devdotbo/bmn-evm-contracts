# Factory Event Enhancement - Deployment Checklist

## Pre-Deployment
- [ ] Ensure `.env` file has `DEPLOYER_PRIVATE_KEY`
- [ ] Verify deployer has sufficient ETH on Base (~0.01 ETH)
- [ ] Verify deployer has sufficient ETH on Etherlink (~0.1 ETH)
- [ ] Confirm CREATE3 factory exists at `0x7B9e9BE124C5A0E239E04fDC93b66ead4e8C669d` on both chains
- [ ] Verify existing implementations are deployed and have code

## Base Deployment
- [ ] Run: `source .env && forge script script/DeployFactoryUpgrade.s.sol --rpc-url $BASE_RPC_URL --broadcast --verify`
- [ ] Note deployed factory address: `0x___________________________`
- [ ] Note deployment block number: `_______________`
- [ ] Verify on Basescan
- [ ] Save deployment info from `deployments/factory-upgrade-base-latest.env`

## Etherlink Deployment  
- [ ] Run: `source .env && forge script script/DeployFactoryUpgrade.s.sol --rpc-url $ETHERLINK_RPC_URL --broadcast --slow`
- [ ] Note deployed factory address: `0x___________________________`
- [ ] Note deployment block number: `_______________`
- [ ] Check deployment with: `cast code <factory_address> --rpc-url $ETHERLINK_RPC_URL`
- [ ] Save deployment info from `deployments/factory-upgrade-etherlink-latest.env`

## Post-Deployment Verification
- [ ] Run verification script on Base: `UPGRADED_FACTORY=0x... forge script script/VerifyFactoryUpgrade.s.sol --rpc-url $BASE_RPC_URL`
- [ ] Run verification script on Etherlink: `UPGRADED_FACTORY=0x... forge script script/VerifyFactoryUpgrade.s.sol --rpc-url $ETHERLINK_RPC_URL`
- [ ] Create test order and verify event includes escrow address
- [ ] Check gas usage is within expected range (<1% increase)

## Indexer Update
- [ ] Update Ponder config with new factory addresses
- [ ] Set correct start blocks for each chain
- [ ] Deploy indexer with dual-mode event support
- [ ] Verify indexer processes new events correctly
- [ ] Monitor for any missed events

## Documentation Updates
- [ ] Update main README with new factory addresses
- [ ] Update resolver documentation
- [ ] Create migration guide for third-party integrations
- [ ] Update deployment addresses in this checklist

## Monitoring (First 7 Days)
- [ ] Daily check: Event emission working correctly
- [ ] Daily check: Indexer processing without errors
- [ ] Daily check: No increase in failed transactions
- [ ] Weekly review: Gas costs remain stable
- [ ] Weekly review: Etherlink RPC load reduced

## Final Cleanup (After 30 Days)
- [ ] Remove legacy CREATE2 calculation from indexer
- [ ] Archive old factory deployment files
- [ ] Update all references to use new factory only