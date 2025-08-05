# Bridge-Me-Not

Cross-chain atomic swap protocol using hash timelock contracts (HTLC).

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

## Documentation

### Key Documents

- **[Deployment History](docs/DEPLOYMENT_HISTORY.md)** - Comprehensive record of all deployments across chains
- **[CREATE3 Deployment Summary](docs/CREATE3-DEPLOYMENT-SUMMARY.md)** - Details about CREATE3 factory usage and deployed addresses
- **[Factory Event Enhancement](docs/FACTORY_EVENT_ENHANCEMENT.md)** - Technical proposal for factory improvements
- **[Implementation Summary](docs/FACTORY_EVENT_ENHANCEMENT_IMPLEMENTATION.md)** - Implementation details for factory v1.1.0
- **[Resolver Update Guide](docs/RESOLVER_UPDATE_GUIDE.md)** - Guide for updating resolver infrastructure

### Deployment Addresses

All contracts are deployed using CREATE3 for deterministic addresses across chains:

- **CREATE3 Factory**: `0x7B9e9BE124C5A0E239E04fDC93b66ead4e8C669d` (Base, Etherlink & Optimism)
- **BMN Token**: `0x8287CD2aC7E227D9D927F998EB600a0683a832A1`
- **EscrowSrc**: `0x77CC1A51dC5855bcF0d9f1c1FceaeE7fb855a535`
- **EscrowDst**: `0x36938b7899A17362520AA741C0E0dA0c8EfE5e3b`
- **CrossChainEscrowFactory v1.1.0**: `0x2B2d52Cf0080a01f457A4f64F41cbca500f787b1` (Base & Etherlink)
- **CrossChainEscrowFactory v1.1.0**: `0xB916C3edbFe574fFCBa688A6B92F72106479bD6c` (Optimism)
- **Resolver Factory**: `0xe767202fD26104267CFD8bD8cfBd1A44450DC343`

See [Deployment History](docs/DEPLOYMENT_HISTORY.md) for full details.

## License

MIT