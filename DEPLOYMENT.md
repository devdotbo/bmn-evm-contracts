# Bridge-Me-Not Deployment Guide

This guide explains how to deploy and manage the Bridge-Me-Not contracts for local development and testing.

## Prerequisites

- Foundry installed (`forge`, `cast`, `anvil`)
- Unix-like environment (Linux, macOS, WSL)
- Git and basic command line knowledge

## Quick Start

1. **Start chains and deploy contracts:**
   ```bash
   ./scripts/multi-chain-setup.sh
   ```

   This single command will:
   - Start two Anvil instances (Chain A on port 8545, Chain B on port 8546)
   - Deploy all contracts to both chains
   - Save deployment info to `deployments/` directory
   - Copy deployment files to resolver project (if exists)

2. **Check deployment status:**
   ```bash
   ./scripts/check-deployment.sh
   ```

3. **Start resolver (in separate project):**
   ```bash
   cd ../bmn-evm-resolver
   deno task resolver:start
   ```

## Deployment Details

### Contract Addresses

Deployment addresses are saved in JSON files:
- `deployments/chainA.json` - Chain A (1337) contracts
- `deployments/chainB.json` - Chain B (1338) contracts

Each file contains:
```json
{
  "chainId": 1337,
  "contracts": {
    "factory": "0x...",
    "limitOrderProtocol": "0x...",
    "tokenA": "0x...",
    "tokenB": "0x...",
    "accessToken": "0x...",
    "feeToken": "0x..."
  },
  "accounts": {
    "deployer": "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
    "alice": "0x70997970C51812dc3A010C7d01b50e0d17dc79C8",
    "bob": "0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC"
  }
}
```

### Test Accounts

All test accounts use Anvil's default private keys:

**Deployer (Account 0):**
- Address: `0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266`
- Private Key: See `.env` file (copy from `.env.example` for local development)

**Alice (Account 1):**
- Address: `0x70997970C51812dc3A010C7d01b50e0d17dc79C8`
- Private Key: `0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d`

**Bob/Resolver (Account 2):**
- Address: `0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC`
- Private Key: `0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a`

### Token Distribution

The deployment script distributes tokens for testing:

**Chain A (Source):**
- Alice: 1000 TKA (Token A) - for creating orders
- Bob: 500 TKA - for acting as taker
- Both: 1 Access Token

**Chain B (Destination):**
- Bob: 1000 TKB (Token B) - for liquidity
- Alice: 100 TKB - for testing withdrawals
- Both: 1 Access Token

## Helper Scripts

### Check Deployment Status
```bash
./scripts/check-deployment.sh
```
Shows:
- Chain status (running/stopped)
- Deployed contract addresses
- Account ETH and token balances
- Resolver project status

### Fund Accounts
```bash
# Fund both ETH and tokens with defaults
./scripts/fund-accounts.sh

# Fund only ETH (20 ETH each)
./scripts/fund-accounts.sh --eth 20

# Fund only tokens (500 tokens)
./scripts/fund-accounts.sh --tokens 500
```

### Clean Up
```bash
./scripts/cleanup.sh
```
This will:
- Stop both Anvil chains
- Remove log files
- Optionally remove deployment files
- Optionally clean forge cache

## Manual Deployment

If you need to deploy contracts manually:

```bash
# Start chains manually
anvil --port 8545 --chain-id 1337 &
anvil --port 8546 --chain-id 1338 &

# Load environment variables
source .env

# Deploy to Chain A
forge script script/LocalDeploy.s.sol --rpc-url http://localhost:8545 --broadcast --private-key $DEPLOYER_PRIVATE_KEY

# Deploy to Chain B
forge script script/LocalDeploy.s.sol --rpc-url http://localhost:8546 --broadcast --private-key $DEPLOYER_PRIVATE_KEY
```

## Troubleshooting

### Ports Already in Use
If you see "Port 8545/8546 is already in use":
1. Run `./scripts/cleanup.sh` to stop existing chains
2. Or manually: `lsof -ti :8545 | xargs kill -9`

### Deployment Fails
If deployment fails:
1. Check chain logs: `tail -f chain-a.log` or `tail -f chain-b.log`
2. Ensure you have enough gas (Anvil provides 10000 ETH by default)
3. Try running with `--slow` flag for deployment

### Missing Dependencies
If you get import errors:
1. Run `forge install` to install dependencies
2. Check that all git submodules are initialized

## Integration with Resolver

The deployment automatically copies deployment files to the resolver project if it exists at `../bmn-evm-resolver`. The resolver can then read these files to get contract addresses.

To manually copy deployment files:
```bash
cp -r deployments ../bmn-evm-resolver/
```

## Production Considerations

This deployment is for development only. For production:
- Use proper private key management
- Deploy with a hardware wallet or secure key management system
- Verify contracts on block explorers
- Use appropriate gas settings
- Set proper timelocks and safety deposits
- Audit all contracts before mainnet deployment