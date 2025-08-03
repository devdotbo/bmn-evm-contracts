# Resolver Agent Guide

Quick reference for BMN cross-chain atomic swap resolvers.

## Deployments

### Production
- **CrossChainEscrowFactory**: `0xc72ed1E8a0649e51Cd046a0FfccC8f8c0bf385Fa`
- **BMN Token**: `0x8287CD2aC7E227D9D927F998EB600a0683a832A1` (18 decimals)
- **Limitation**: Requires 1inch integration (see [CROSSCHAIN-FACTORY-USAGE.md](./CROSSCHAIN-FACTORY-USAGE.md))

### Testing
- **Script**: `./scripts/run-mainnet-test.sh [deploy|swap|check]`
- **Contracts**: See [LiveTestMainnet.s.sol](../script/LiveTestMainnet.s.sol)

## Quick Start

```bash
# Setup (.env required - see CLAUDE.md)
source .env

# Run test
./scripts/run-mainnet-test.sh deploy  # Deploy TestEscrowFactory
./scripts/run-mainnet-test.sh swap    # Execute swap
./scripts/run-mainnet-test.sh check   # Verify balances
```

## Swap Flow

1. **Create**: Alice creates order with hashlock
2. **Lock Source**: Alice locks BMN on Base
3. **Lock Destination**: Bob locks BMN on Etherlink
4. **Withdraw Destination**: Alice withdraws (reveals secret)
5. **Withdraw Source**: Bob withdraws using secret

## Timelocks

See [MAINNET-ATOMIC-SWAP-READY.md](./MAINNET-ATOMIC-SWAP-READY.md#timelock-configuration) for detailed windows.

## Integration

For TypeScript resolver (`../bmn-evm-resolver`):
```bash
forge build
cp out/{TestEscrowFactory,EscrowSrc,EscrowDst}.sol/*.json ../bmn-evm-resolver/abis/
```

## Debugging

```bash
# Check escrow state
cast call <escrow> "secretRevealed()(bool)" --rpc-url $BASE_RPC_URL

# Detailed output
ACTION=withdraw-dst forge script script/LiveTestMainnet.s.sol --rpc-url $ETHERLINK_RPC_URL -vvvv
```

## References

- [CLAUDE.md](../CLAUDE.md) - Project setup and commands
- [CROSSCHAIN-FACTORY-USAGE.md](./CROSSCHAIN-FACTORY-USAGE.md) - Factory details
- [MAINNET-ATOMIC-SWAP-READY.md](./MAINNET-ATOMIC-SWAP-READY.md) - Full protocol documentation