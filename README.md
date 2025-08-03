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

## License

MIT