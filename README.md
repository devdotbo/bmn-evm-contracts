# Bridge-Me-Not

Cross-chain atomic swap protocol using hash timelock contracts (HTLC).

## Important Note

**TypeScript Resolver Required**: This repository contains the smart contracts (on-chain infrastructure) for the BMN protocol. To execute actual atomic swaps, you MUST use the TypeScript resolver implementation located at `../bmn-evm-resolver`. The contracts alone cannot perform cross-chain coordination - they provide the escrow and locking mechanisms that the resolver orchestrates.

## Architecture Overview

The BMN protocol consists of three essential components:
1. **Smart Contracts** (this repository): Provide on-chain escrow, timelocks, and atomic swap infrastructure
2. **1inch Integration**: IPostInteraction interface for atomic escrow creation with SimpleLimitOrderProtocol
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

# Deploy contracts locally
source .env && forge script script/Deploy.s.sol --rpc-url http://localhost:8545 --broadcast

# Run resolver (see ../bmn-evm-resolver)
```

## Testing

```bash
forge test
```

## Key Features

### EIP-712 Resolver-Signed Actions
- Escrow contracts support `publicWithdrawSigned` and `publicCancelSigned` with EIP-712 signatures
- Backward compatible with token-gated public functions

### Security Features
- **Resolver Whitelist**: Only approved addresses can create destination escrows
- **Emergency Pause**: Protocol can be immediately halted if issues are detected
- **Enhanced Access Control**: Owner-only functions for protocol management
- **Whitelist Bypass**: Configurable for permissionless mode

## Deployment

For current deployment addresses and instructions, see [`deployments/deployment.md`](deployments/deployment.md).

### Deploy New Instance
```bash
# Deploy to mainnet with CREATE3
source .env && forge script script/Deploy.s.sol --rpc-url $BASE_RPC_URL --broadcast
source .env && forge script script/Deploy.s.sol --rpc-url $OPTIMISM_RPC_URL --broadcast

# Verify deployment
FACTORY_ADDRESS=0x... forge script script/Deploy.s.sol:Deploy --sig "verify()" --rpc-url $BASE_RPC_URL
```

## Documentation

### Core Documentation

- **[Deployment Information](deployments/deployment.md)** - Current deployment addresses and instructions
- **[Architecture Overview](docs/)** - Technical documentation and implementation details
- **[Testing Guide](TESTING.md)** - Comprehensive testing documentation
- **[Change Log](CHANGELOG.md)** - Version history and updates

### Additional Resources

- **[Archived Documentation](docs/archive/)** - Historical plans and implementations
- **[Completed Features](docs/completed/)** - Archive of implemented features

## License

MIT