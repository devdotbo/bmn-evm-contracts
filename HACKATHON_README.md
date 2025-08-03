# BMN CrossChain Resolver - Hackathon Deployment

## Quick Deploy (< 5 minutes)

### Prerequisites
- `.env` file with `DEPLOYER_PRIVATE_KEY`
- ETH on Base and Etherlink for gas
- BMN tokens: `0x9C32618CeeC96b9DC0b7c0976c4b4cf2Ee452988`

### Deploy Both Chains
```bash
./scripts/deploy-resolver-hackathon.sh
```

### Manual Deploy (if script fails)
```bash
# Base Mainnet
forge script script/DeployResolverMainnet.s.sol --rpc-url https://mainnet.base.org --broadcast

# Etherlink Mainnet  
forge script script/DeployResolverMainnet.s.sol --rpc-url https://node.mainnet.etherlink.com --broadcast
```

## Architecture

```
CrossChainResolverV2
├── Uses TestEscrowFactory (allows direct escrow creation)
├── initiateSwap() - Creates source escrow
├── createDestinationEscrow() - Creates dest escrow (resolver only)
└── withdraw() - Claims tokens with secret
```

## Key Differences from Production
- **TestEscrowFactory**: Bypasses limit order protocol for demo
- **Simplified Access**: Basic owner pattern instead of complex ACL
- **Mock Tokens**: Fee/access tokens are mocks

## Demo Flow

1. **Alice on Base**: Calls `initiateSwap()` with 100 BMN
2. **Resolver on Etherlink**: Calls `createDestinationEscrow()` 
3. **Bob on Etherlink**: Calls `withdraw()` with secret
4. **Alice on Base**: Uses revealed secret to `withdraw()`

## Deployed Contracts
After deployment, check:
- `deployments/mainnet-Base-resolver.env`
- `deployments/mainnet-Etherlink-resolver.env`

## Test Deployment
```bash
RESOLVER_ADDRESS=<your-resolver> forge script script/TestCrossChainResolver.s.sol --rpc-url <rpc> --broadcast
```