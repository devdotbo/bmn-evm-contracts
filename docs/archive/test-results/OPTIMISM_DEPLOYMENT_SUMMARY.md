# Optimism Deployment Summary

## Deployment Overview
Successfully deployed BMN Protocol contracts to Optimism mainnet (Chain ID: 10) using CREATE3 for cross-chain consistency.

## Contract Addresses

### Core Protocol Contracts
- **CREATE3 Factory**: `0x7B9e9BE124C5A0E239E04fDC93b66ead4e8C669d`
- **BMN Token**: `0x8287CD2aC7E227D9D927F998EB600a0683a832A1`
- **EscrowSrc Implementation**: `0x77CC1A51dC5855bcF0d9f1c1FceaeE7fb855a535`
- **EscrowDst Implementation**: `0x36938b7899A17362520AA741C0E0dA0c8EfE5e3b`
- **CrossChainEscrowFactory v1.0.0**: `0x75ee15F6BfDd06Aee499ed95e8D92a114659f4d1`
- **CrossChainEscrowFactory v1.1.0**: `0xB916C3edbFe574fFCBa688A6B92F72106479bD6c` (Enhanced with escrow address events)

### Resolver Infrastructure
- **Resolver Factory**: `0xe767202fD26104267CFD8bD8cfBd1A44450DC343`

## Key Accounts
- **Deployer**: `0x5f29827e25dc174a6A51C99e6811Bbd7581285b0`
- **Resolver (Bob)**: `0xfdF1dDeB176BEA06c7430166e67E615bC312b7B5`
- **Alice (End User)**: `0x240E2588e35FB9D3D60B283B45108a49972FFFd8`

## Cross-Chain Consistency
All contracts have been deployed using CREATE3, ensuring identical addresses across:
- Base Mainnet
- Optimism Mainnet
- Etherlink Mainnet (previous deployment)

## Next Steps
1. Update resolver configuration to include Optimism endpoints
2. Configure cross-chain routing between Base and Optimism
3. Test cross-chain swaps between Base and Optimism
4. Update documentation to reflect Optimism as a supported chain

## RPC Configuration
- **Optimism RPC**: `https://rpc.ankr.com/optimism/YOUR_API_KEY_HERE`
- **Optimism WS**: `wss://rpc.ankr.com/optimism/ws/YOUR_API_KEY_HERE`

## Deployment Transaction Logs
- Full deployment logs saved in: `broadcast/DeployWithCREATE3*.s.sol/10/run-latest.json`
- Deployment configuration files: `deployments/create3-*-10.env`