# BMN Protocol Deployments

## Current Deployments

### v3.0.0 (ACTIVE - Production)

**Status**: ✅ FULLY DEPLOYED AND VERIFIED
**Date**: 2025-08-15
**Networks**: Base (8453), Optimism (10)
**Deployment Method**: CREATE3 for deterministic cross-chain addresses

#### Key Features & Changes
- **TIMESTAMP_TOLERANCE**: Reduced from 300 to 60 seconds for faster cross-chain operations
- **Whitelist Bypass**: Default enabled (`whitelistBypassed = true`) for permissionless access
- **Minimal Timelocks**: 
  - `srcWithdrawal`: Can now be 0 (immediate withdrawal supported)
  - `srcPublicWithdrawal`: Reduced to 10 minutes
  - Other timelocks proportionally reduced for better UX
- **Gas Optimizations**: Via-IR enabled with 1M optimizer runs

#### Deployed Contract Addresses (Same on Both Chains)

| Contract | Address | Base Verification | Optimism Verification |
|----------|---------|-------------------|----------------------|
| **SimplifiedEscrowFactory** | `0xa820F5dB10AE506D22c7654036a4B74F861367dB` | [✅ Verified](https://basescan.org/address/0xa820f5db10ae506d22c7654036a4b74f861367db) | [✅ Verified](https://optimistic.etherscan.io/address/0xa820f5db10ae506d22c7654036a4b74f861367db) |
| **EscrowSrc Implementation** | `0xaf7D19bfAC3479627196Cc9C9aDF0FB67A4441AE` | [✅ Verified](https://basescan.org/address/0xaf7d19bfac3479627196cc9c9adf0fb67a4441ae) | [✅ Verified](https://optimistic.etherscan.io/address/0xaf7d19bfac3479627196cc9c9adf0fb67a4441ae) |
| **EscrowDst Implementation** | `0x334787690D3112a4eCB10ACAa1013c12A3893E74` | [✅ Verified](https://basescan.org/address/0x334787690d3112a4ecb10acaa1013c12a3893e74) | [✅ Verified](https://optimistic.etherscan.io/address/0x334787690d3112a4ecb10acaa1013c12a3893e74) |
| **BMN Token** | `0x8287CD2aC7E227D9D927F998EB600a0683a832A1` | [View](https://basescan.org/address/0x8287CD2aC7E227D9D927F998EB600a0683a832A1) | [View](https://optimistic.etherscan.io/address/0x8287CD2aC7E227D9D927F998EB600a0683a832A1) |

#### Technical Details
- **CREATE3 Factory**: `0x7B9e9BE124C5A0E239E04fDC93b66ead4e8C669d` (shared across chains)
- **Factory Owner**: `0x5f29827e25dc174a6A51C99e6811Bbd7581285b0`
- **Constructor Arguments**:
  - Rescue Delay: 604800 seconds (7 days)
  - Access Token: BMN Token address
- **Compiler**: Solidity 0.8.23 with Cancun EVM target

---

## Infrastructure Overview

### Current Deployment Architecture

```
Production Environment (v3.0.0)
├── Base Network (Chain ID: 8453)
│   ├── SimplifiedEscrowFactory (0xa820...)
│   ├── EscrowSrc Implementation (0xaf7D...)
│   └── EscrowDst Implementation (0x3347...)
│
└── Optimism Network (Chain ID: 10)
    ├── SimplifiedEscrowFactory (0xa820...)
    ├── EscrowSrc Implementation (0xaf7D...)
    └── EscrowDst Implementation (0x3347...)
```

### Configuration Management

#### Environment Variables
```bash
# Network RPC URLs (use placeholders)
BASE_RPC_URL=https://rpc.provider.com/base/YOUR_API_KEY_HERE
OPTIMISM_RPC_URL=https://rpc.provider.com/optimism/YOUR_API_KEY_HERE

# Deployment Configuration
DEPLOYER_PRIVATE_KEY=YOUR_PRIVATE_KEY_HERE
ETHERSCAN_API_KEY=YOUR_ETHERSCAN_API_KEY_HERE
OPTIMISM_ETHERSCAN_API_KEY=YOUR_OPTIMISM_ETHERSCAN_API_KEY_HERE
```

---

## Deployment Procedures

### Standard Deployment Process

#### 1. Pre-Deployment Checklist
- [ ] Review all contract changes
- [ ] Run full test suite: `forge test -vvv`
- [ ] Check contract sizes: `forge build --sizes`
- [ ] Verify environment variables are set
- [ ] Confirm CREATE3 factory is deployed on target chains
- [ ] Document expected gas costs

#### 2. Deployment Commands

```bash
# Deploy to Base
source .env && forge script script/DeployMainnet.s.sol \
    --rpc-url $BASE_RPC_URL \
    --broadcast \
    --verify \
    --etherscan-api-key $ETHERSCAN_API_KEY \
    -vvvv

# Deploy to Optimism
source .env && forge script script/DeployMainnet.s.sol \
    --rpc-url $OPTIMISM_RPC_URL \
    --broadcast \
    --verify \
    --etherscan-api-key $OPTIMISM_ETHERSCAN_API_KEY \
    -vvvv
```

#### 3. Verification Commands

```bash
# Verify SimplifiedEscrowFactory on Base
forge verify-contract \
    --chain-id 8453 \
    --num-of-optimizations 1000000 \
    --watch \
    --compiler-version v0.8.23+commit.f704f362 \
    --constructor-args $(cast abi-encode "constructor(address,address,address,address)" \
        "0xaf7D19bfAC3479627196Cc9C9aDF0FB67A4441AE" \
        "0x334787690D3112a4eCB10ACAa1013c12A3893E74" \
        "0x5f29827e25dc174a6A51C99e6811Bbd7581285b0" \
        "0x0000000000000000000000000000000000000000") \
    0xa820F5dB10AE506D22c7654036a4B74F861367dB \
    src/SimplifiedEscrowFactory.sol:SimplifiedEscrowFactory \
    --etherscan-api-key $ETHERSCAN_API_KEY

# Verify Implementation Contracts
forge verify-contract \
    --chain-id 8453 \
    --num-of-optimizations 1000000 \
    --watch \
    --compiler-version v0.8.23+commit.f704f362 \
    --constructor-args $(cast abi-encode "constructor(uint256,address)" 604800 "0x8287CD2aC7E227D9D927F998EB600a0683a832A1") \
    0xaf7D19bfAC3479627196Cc9C9aDF0FB67A4441AE \
    src/EscrowSrc.sol:EscrowSrc \
    --etherscan-api-key $ETHERSCAN_API_KEY
```

#### 4. Post-Deployment Verification
- [ ] Verify all contracts on block explorers
- [ ] Test factory deployment of escrows
- [ ] Verify resolver can interact with contracts
- [ ] Check event emissions
- [ ] Update monitoring dashboards
- [ ] Update deployment.md

---

## Rollback Procedures

### Emergency Rollback Process

1. **Pause Current Factory** (if emergency pause is enabled)
   ```bash
   cast send $FACTORY_ADDRESS "pause()" --private-key $OWNER_KEY
   ```

2. **Deploy Previous Version**
   - Use previous deployment scripts with verified code
   - Ensure same CREATE3 salt for address consistency

3. **Migrate State** (if necessary)
   - Export whitelisted resolvers
   - Transfer ownership
   - Update resolver configurations

4. **Verification Steps**
   - Confirm all escrows can complete or cancel
   - Verify resolver functionality
   - Check monitoring alerts

---

## Monitoring & Alerts

### Key Metrics to Monitor
- Factory deployment events
- Escrow creation rate
- Secret reveal success rate
- Cancellation rate
- Gas usage patterns
- Cross-chain timing accuracy

### Alert Thresholds
- Failed escrow deployments > 5 in 1 hour
- Cancellation rate > 30% in 24 hours
- Gas price spike > 200% baseline
- Timestamp tolerance violations

### Monitoring Tools
- Block explorer event logs
- Custom indexer for escrow tracking
- Gas price oracles
- Chain health monitoring

---

## Security Considerations

### Production Security Checklist
- [ ] Whitelist bypass should be disabled for production (`setWhitelistBypassed(false)`)
- [ ] Appropriate timelocks based on chain finality
- [ ] Multi-sig for factory ownership
- [ ] Resolver key management with hardware wallets
- [ ] Regular security audits
- [ ] Incident response plan documented

### Access Control
- **Factory Owner**: Controls whitelist, pause, and configuration
- **Resolvers**: Whitelisted addresses that can create destination escrows
- **Users**: Can create source escrows through limit orders

---

## Deprecated Deployments

### v2.3.0 (DEPRECATED - January 8, 2025)

| Contract | Base Address | Optimism Address | Status |
|----------|--------------|------------------|--------|
| SimplifiedEscrowFactory | `0xdebE6F4bC7BaAD2266603Ba7AfEB3BB6dDA9FE0A` | Same | ✅ Verified |
| EscrowSrc Implementation | `0x80C3D0e98C62930dD3f6ab855b34d085Ca9aDf59` | Same | ✅ Verified |
| EscrowDst Implementation | `0x32e98F40D1D4643b251D8Ee99fd95918A3A8b306` | Same | ✅ Verified |

**Features**: EIP-712 signatures, PostInteraction integration, Resolver whitelist, Emergency pause

### v2.2.0 (DEPRECATED - January 7, 2025)
- SimplifiedEscrowFactory: `0xB436dBBee1615dd80ff036Af81D8478c1FF1Eb68`
- Features: Initial PostInteraction integration with 1inch

### v2.1.0 (DEPRECATED - August 6, 2024)
- CrossChainEscrowFactory: `0xBc9A20A9FCb7571B2593e85D2533E10e3e9dC61A`
- Features: Resolver whitelist, Emergency pause mechanism

### v1.1.0 (DEPRECATED - July 15, 2024)
- Base/Etherlink: `0x2B2d52Cf0080a01f457A4f64F41cbca500f787b1`
- Optimism: `0xB916C3edbFe574fFCBa688A6B92F72106479bD6c`
- Features: Enhanced events with escrow addresses

### v1.0.0 (DEPRECATED - July 1, 2024)
- CrossChainEscrowFactory: `0x75ee15F6BfDd06Aee499ed95e8D92a114659f4d1`
- Features: Initial HTLC implementation

---

## Deployment History

| Version | Date | Networks | Status | Key Changes |
|---------|------|----------|--------|-------------|
| **v3.0.0** | 2025-08-15 | Base, Optimism | **✅ ACTIVE** | Reduced timing (60s tolerance), whitelist bypass default, immediate withdrawals |
| v2.3.0 | 2025-01-08 | Base, Optimism | Deprecated | EIP-712 signatures, PostInteraction complete |
| v2.2.0 | 2025-01-07 | Base, Optimism | Deprecated | PostInteraction integration |
| v2.1.0 | 2024-08-06 | Base, Optimism | Deprecated | Resolver whitelist, emergency pause |
| v1.1.0 | 2024-07-15 | Base, Etherlink, Optimism | Deprecated | Enhanced events |
| v1.0.0 | 2024-07-01 | Base, Etherlink | Deprecated | Initial deployment |

---

## Best Practices & Lessons Learned

### Deployment Best Practices

1. **CREATE3 Deployment Strategy**
   - Always use deterministic deployment for cross-chain consistency
   - Verify CREATE3 factory exists on all target chains before deployment
   - Use consistent salt values across chains

2. **Verification Process**
   - Use Foundry's built-in verification during deployment (`--verify` flag)
   - For manual verification, use Etherscan v2 API
   - Keep constructor arguments encoded and documented
   - Verify immediately after deployment while transaction data is fresh

3. **Gas Optimization**
   - Enable Via-IR for better optimization
   - Use 1M optimizer runs for frequently called functions
   - Monitor deployment gas costs: ~3-4M gas per factory deployment

4. **Security Practices**
   - Never expose private keys or API keys in documentation
   - Use hardware wallets or secure key management for production deployments
   - Implement time delays between deployment and configuration changes
   - Always verify contract code matches expected bytecode

### Common Issues & Solutions

| Issue | Solution |
|-------|----------|
| Verification fails with "Similar match found" | Use `--force` flag or verify via UI with exact constructor args |
| CREATE3 address mismatch | Ensure same salt and deployer address across chains |
| High gas costs on deployment | Split deployment into multiple transactions if needed |
| Etherscan rate limiting | Use delays between verification attempts |

### Migration Checklist

When deploying new versions:
- [ ] Export current whitelist state
- [ ] Document all active escrows
- [ ] Prepare rollback script
- [ ] Test on testnets first
- [ ] Coordinate with resolver operators
- [ ] Update monitoring systems
- [ ] Prepare user communication
- [ ] Set appropriate grace period

---

## Technical References

### Contract Verification Commands

```bash
# Generic verification template
forge verify-contract \
    --chain-id <CHAIN_ID> \
    --num-of-optimizations 1000000 \
    --watch \
    --compiler-version v0.8.23+commit.f704f362 \
    --constructor-args <ENCODED_ARGS> \
    <CONTRACT_ADDRESS> \
    <CONTRACT_PATH>:<CONTRACT_NAME> \
    --etherscan-api-key <API_KEY>

# Encoding constructor arguments
cast abi-encode "constructor(address,address,address,address)" \
    <srcImpl> <dstImpl> <owner> <resolver>
```

### Useful Cast Commands

```bash
# Check factory owner
cast call <FACTORY_ADDRESS> "owner()(address)"

# Check whitelist bypass status
cast call <FACTORY_ADDRESS> "whitelistBypassed()(bool)"

# Check if resolver is whitelisted
cast call <FACTORY_ADDRESS> "resolverWhitelist(address)(bool)" <RESOLVER_ADDRESS>

# Get implementation addresses
cast call <FACTORY_ADDRESS> "srcImplementation()(address)"
cast call <FACTORY_ADDRESS> "dstImplementation()(address)"
```

---

## Contact & Support

- **Technical Issues**: Create GitHub issue in bmn-evm-contracts repository
- **Security Concerns**: Contact security team immediately
- **Resolver Support**: Coordinate through official resolver channels
- **Factory Owner**: Multi-sig at `0x5f29827e25dc174a6A51C99e6811Bbd7581285b0`

---

## Appendix: Environment File Templates

### Production Environment (.env.production)
```bash
# NEVER COMMIT THIS FILE
BASE_RPC_URL=https://mainnet.base.org
OPTIMISM_RPC_URL=https://mainnet.optimism.io
DEPLOYER_PRIVATE_KEY=YOUR_PRIVATE_KEY_HERE
ETHERSCAN_API_KEY=YOUR_ETHERSCAN_API_KEY_HERE
OPTIMISM_ETHERSCAN_API_KEY=YOUR_OPTIMISM_ETHERSCAN_API_KEY_HERE
```

### Testing Environment (.env.test)
```bash
# Safe for testing only
BASE_RPC_URL=http://localhost:8545
OPTIMISM_RPC_URL=http://localhost:8546
DEPLOYER_PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
ETHERSCAN_API_KEY=test
```

---

*Last Updated: August 15, 2025 - v3.0.0 Full Deployment & Verification*