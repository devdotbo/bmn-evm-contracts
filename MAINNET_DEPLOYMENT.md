# Mainnet Deployment Documentation

## Overview

This document provides comprehensive documentation for the Bridge Me Not (BMN) cross-chain atomic swap protocol deployment on Base and Etherlink mainnets.

## Network Configuration

### Base Mainnet
- **Chain ID**: 8453
- **RPC URL**: Configure in .env as CHAIN_A_RPC_URL
- **Explorer**: https://basescan.org
- **Verification**: Etherscan API

### Etherlink Mainnet
- **Chain ID**: 42793
- **RPC URL**: Configure in .env as CHAIN_B_RPC_URL (use Ankr RPC)
- **Explorer**: https://explorer.etherlink.com/
- **Verification**: Blockscout API

## Deployed Contracts

All contracts use CREATE2 for deterministic addresses across chains:

### Base Mainnet Deployment
```json
{
  "chainId": 8453,
  "contracts": {
    "factory": "0x36753c48a93f05244abaE9b789F4C144D78ff769",
    "limitOrderProtocol": "0xF5e82Fbe75530ee7cA95e0eDA234f3e4e30e716D",
    "tokenA": "0x2561485d7EA230Dc8318352E6aA06ee4EF4D5593",
    "tokenB": "0x9900D2f569F413DaBE121C4bB2758be46ad537eC",
    "accessToken": "0x401b4544a51d798aEdfF01095D81c5C0B8B0603c",
    "feeToken": "0xb04979fa49c7514C765CbA2931fDC64a1a3703c1"
  },
  "accounts": {
    "deployer": "0x5f29827e25dc174a6A51C99e6811Bbd7581285b0",
    "alice": "0x240E2588e35FB9D3D60B283B45108a49972FFFd8",
    "bob": "0xfdF1dDeB176BEA06c7430166e67E615bC312b7B5"
  }
}
```

### Etherlink Mainnet Deployment
```json
{
  "chainId": 42793,
  "contracts": {
    "factory": "0x36753c48a93f05244abaE9b789F4C144D78ff769",
    "limitOrderProtocol": "0xF5e82Fbe75530ee7cA95e0eDA234f3e4e30e716D",
    "tokenA": "0x2561485d7EA230Dc8318352E6aA06ee4EF4D5593",
    "tokenB": "0x9900D2f569F413DaBE121C4bB2758be46ad537eC",
    "accessToken": "0x401b4544a51d798aEdfF01095D81c5C0B8B0603c",
    "feeToken": "0xb04979fa49c7514C765CbA2931fDC64a1a3703c1"
  },
  "accounts": {
    "deployer": "0x5f29827e25dc174a6A51C99e6811Bbd7581285b0",
    "alice": "0x240E2588e35FB9D3D60B283B45108a49972FFFd8",
    "bob": "0xfdF1dDeB176BEA06c7430166e67E615bC312b7B5"
  }
}
```

## Key Updates for Mainnet

### 1. Unified Deployment Architecture
- Created `UnifiedDeploy.s.sol` that handles both testnet and mainnet deployments
- Single script with network parameter instead of separate scripts per network
- Automatic chain ID detection and configuration

### 2. Blockscout Integration for Etherlink
- Etherlink mainnet uses Blockscout instead of Etherscan
- Updated deployment scripts to use `--verifier blockscout` for Etherlink
- Correct verifier URL: https://explorer.etherlink.com/api/

### 3. Deployment Scripts

#### deploy-unified.sh
- Unified deployment script for all networks
- Usage: `./scripts/deploy-unified.sh <network>`
- Networks: `base`, `base-sepolia`, `etherlink`, `etherlink-testnet`
- Automatically configures verification based on network

#### test-cross-chain-swap.sh
- Unified test script for cross-chain swaps
- Usage: `./scripts/test-cross-chain-swap.sh <network> [action]`
- Networks: `local`, `testnet`, `mainnet`
- Actions: `create-order`, `create-src-escrow`, `create-dst-escrow`, `withdraw-dst`, `withdraw-src`, `full`

### 4. Token Distribution
Initial token balances after deployment:
- **Alice** (User):
  - 1000 TKA on Base Mainnet
  - 100 TKB on Etherlink Mainnet
- **Bob** (Resolver):
  - 500 TKA on Base Mainnet
  - 1000 TKB on Etherlink Mainnet

### 5. Timelock Configuration
Production timelock values (in seconds):
```solidity
SRC_WITHDRAWAL_START = 0;              // Immediate
SRC_PUBLIC_WITHDRAWAL_START = 300;     // 5 minutes
SRC_CANCELLATION_START = 900;          // 15 minutes
SRC_PUBLIC_CANCELLATION_START = 1200;  // 20 minutes
DST_WITHDRAWAL_START = 0;              // Immediate
DST_PUBLIC_WITHDRAWAL_START = 300;     // 5 minutes
DST_CANCELLATION_START = 900;          // 15 minutes
```

## Deployment Process

### 1. Environment Setup
Ensure `.env` file contains:
```bash
# Mnemonic for account derivation
MNEMONIC="your mnemonic here"

# Mainnet RPC URLs
CHAIN_A_RPC_URL=<YOUR_BASE_RPC_URL>
CHAIN_B_RPC_URL=<YOUR_ETHERLINK_RPC_URL>
```

### 2. Deploy to Base Mainnet
```bash
./scripts/deploy-unified.sh base
```

### 3. Deploy to Etherlink Mainnet
```bash
./scripts/deploy-unified.sh etherlink
```

### 4. Verify Deployment
Check deployment files:
```bash
cat deployments/baseMainnet.json
cat deployments/etherlinkMainnet.json
```

## Testing Cross-Chain Swaps

### Run Full Test
```bash
./scripts/test-cross-chain-swap.sh mainnet
```

### Run Individual Steps
```bash
# Create order
./scripts/test-cross-chain-swap.sh mainnet create-order

# Create source escrow
./scripts/test-cross-chain-swap.sh mainnet create-src-escrow

# Create destination escrow
./scripts/test-cross-chain-swap.sh mainnet create-dst-escrow

# Withdraw from destination (reveals secret)
./scripts/test-cross-chain-swap.sh mainnet withdraw-dst

# Withdraw from source (uses revealed secret)
./scripts/test-cross-chain-swap.sh mainnet withdraw-src
```

## Security Considerations

1. **Private Keys**: Never commit private keys. Always use environment variables
2. **Mnemonic**: Store securely, never share or commit
3. **Safety Deposits**: Small ETH deposits prevent griefing attacks
4. **Timelocks**: Production values balance security and user experience
5. **CREATE2**: Ensures matching addresses across chains for security

## Monitoring

### Transaction Monitoring
- Base Mainnet: https://basescan.org/address/[CONTRACT_ADDRESS]
- Etherlink Mainnet: https://explorer.etherlink.com/address/[CONTRACT_ADDRESS]

### Balance Checking
Use the provided script:
```bash
./scripts/test-cross-chain-swap.sh mainnet check-balances
```

## Troubleshooting

### Common Issues

1. **Verification Timeout on Etherlink**
   - Etherlink verification can be slow
   - Script will continue in background
   - Check explorer manually after a few minutes

2. **Gas Issues**
   - Ensure all accounts have sufficient ETH on both chains
   - Base mainnet gas is typically low
   - Etherlink may require higher gas prices

3. **RPC Connection Issues**
   - Ankr RPC for Etherlink may have rate limits
   - Consider using backup RPC endpoints if needed

## Next Steps

1. **Mainnet Testing**: Run cross-chain swap tests with small amounts
2. **Monitoring Setup**: Implement monitoring for escrow deployments
3. **Resolver Integration**: Connect bmn-evm-resolver to mainnet deployments
4. **User Interface**: Deploy frontend for mainnet interaction

## Contract Verification Status

- ✅ All Base Mainnet contracts verified on Basescan
- ✅ All Etherlink Mainnet contracts verified on Blockscout

## Important Notes

1. **TestEscrowFactory**: The current deployment uses TestEscrowFactory which allows direct escrow creation. For production, integrate with the full Limit Order Protocol flow.

2. **Access Control**: The resolver (Bob) needs appropriate access tokens to participate in swaps.

3. **Fee Structure**: Current deployment uses test fee structures. Production fees should be carefully calibrated.

## References

- [Blockscout Verification Guide](https://docs.blockscout.com/devs/verification/foundry-verification)
- [Base Documentation](https://docs.base.org/)
- [Etherlink Documentation](https://docs.etherlink.com/)