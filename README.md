# Bridge-Me-Not

Cross-chain atomic swap protocol using hash timelock contracts (HTLC).

## Important Note

**TypeScript Resolver Required**: This repository contains the smart contracts (on-chain infrastructure) for the BMN protocol. To execute actual atomic swaps, you MUST use the TypeScript resolver implementation located at `../bmn-evm-resolver`. The contracts alone cannot perform cross-chain coordination - they provide the escrow and locking mechanisms that the resolver orchestrates.

## Architecture Overview

The BMN protocol consists of three essential components:
1. **Smart Contracts** (this repository): Provide on-chain escrow, timelocks, and atomic swap infrastructure
2. **1inch Integration** (v2.2.0): IPostInteraction interface for atomic escrow creation with SimpleLimitOrderProtocol
3. **TypeScript Resolver** (`../bmn-evm-resolver`): Monitors chains, coordinates swaps, reveals secrets

Without the TypeScript resolver, the contracts can only create escrows on individual chains. The resolver is what enables true cross-chain atomic swaps by:
- Monitoring order creation events via 1inch SimpleLimitOrderProtocol
- Triggering postInteraction callbacks for atomic escrow creation
- Deploying corresponding escrows on destination chains
- Managing secret revelation timing
- Ensuring atomicity across chains

## Setup

```bash
forge install
forge build
```

## Local Development

```bash
# Start test chains
./scripts/multi-chain-setup.sh

# Deploy contracts
forge script script/LocalDeploy.s.sol --rpc-url http://localhost:8545 --broadcast

# Run resolver
node scripts/resolver.js
```

## Testing

```bash
forge test
```

## Latest Features (v2.3.0)

### EIP-712 Resolver-Signed Actions
- Escrow contracts add `publicWithdrawSigned` and `publicCancelSigned` guarded by resolver EIP-712 signatures.
- Solady-style EIP-712 helper provides domain (name: "BMN-Escrow", version: "2.3").
- Backward compatible: token-gated public functions remain.

### Deployment (v2.3.0)
- Unified mainnet deploy script: `script/DeployV2_3_Mainnet.s.sol`
- CREATE3 deterministic address across Base and Optimism:
  - Factory v2.3: `0xdebE6F4bC7BaAD2266603Ba7AfEB3BB6dDA9FE0A`
  - Verified on Basescan and Optimistic Etherscan
  
To deploy:
```bash
forge script script/DeployV2_3_Mainnet.s.sol --rpc-url $BASE_RPC_URL --broadcast --verify --slow
forge script script/DeployV2_3_Mainnet.s.sol --rpc-url $OPTIMISM_RPC_URL --broadcast --verify --slow
```

## Security Features (v2.1.0)

The factory deployment includes critical security enhancements:

- **Resolver Whitelist**: Only approved addresses can create destination escrows
- **Emergency Pause**: Protocol can be immediately halted if issues are detected
- **Enhanced Access Control**: Improved owner-only functions for protocol management

## Documentation

### Essential Guides

- **[Current Project State](docs/CURRENT_STATE.md)** - Complete status and roadmap
- **[PostInteraction Implementation](docs/POSTINTERACTION_IMPLEMENTATION.md)** - v2.2.0 1inch integration details
- **[Testing Guide](TESTING.md)** - Comprehensive testing documentation
- **[Deployment Runbook](DEPLOYMENT_RUNBOOK.md)** - Step-by-step deployment procedures
- **[Resolver Migration Guide](RESOLVER_MIGRATION_GUIDE.md)** - Migration from v1.1.0 to v2.1.0

### Technical Documentation

- **[Deployment History](docs/DEPLOYMENT_HISTORY.md)** - Comprehensive record of all deployments
- **[CREATE3 Deployment](docs/CREATE3-DEPLOYMENT-SUMMARY.md)** - CREATE3 factory usage details
- **[Factory Enhancement](docs/FACTORY_EVENT_ENHANCEMENT.md)** - Technical improvements
- **[Resolver Update Guide](docs/RESOLVER_UPDATE_GUIDE.md)** - Resolver infrastructure updates
- **[Completed Plans](docs/completed/)** - Archive of implemented features

### Current Deployment (v2.3.0)

**Deployed**: August 12, 2025  
**Status**: ACTIVE on Base and Optimism

| Contract | Address | Networks |
|----------|---------|----------|
| CREATE3 Factory | `0x7B9e9BE124C5A0E239E04fDC93b66ead4e8C669d` | All |
| **SimplifiedEscrowFactory v2.3.0** | `0xdebE6F4bC7BaAD2266603Ba7AfEB3BB6dDA9FE0A` | Base, Optimism |
| BMN Token | `0x8287CD2aC7E227D9D927F998EB600a0683a832A1` | All |
| EscrowSrc | `0x77CC1A51dC5855bcF0d9f1c1FceaeE7fb855a535` | All |
| EscrowDst | `0x36938b7899A17362520AA741C0E0dA0c8EfE5e3b` | All |
| Resolver Factory | `0xe767202fD26104267CFD8bD8cfBd1A44450DC343` | All |

### Previous Deployment (v2.1.0)

**Deployed**: August 6, 2025  
**Status**: DEPRECATED

| Contract | Address | Networks |
|----------|---------|----------|
| CrossChainEscrowFactory v2.1.0 | `0xBc9A20A9FCb7571B2593e85D2533E10e3e9dC61A` | Base, Optimism |

⚠️ **Previous v1.1.0 and v2.1.0 factories are DEPRECATED** - All resolvers should migrate to v2.2.0

See [Current Deployment Status](deployments/current/MAINNET-STATUS.md) for live status.

## License

MIT