# CREATE3 Deployment Summary

## Deployment Configuration
- **CREATE3 Factory**: `0x7B9e9BE124C5A0E239E04fDC93b66ead4e8C669d` (shared across chains)
- **EVM Version**: `cancun` (required for CREATE3 compatibility)
- **Chains**: Base (8453) and Etherlink (42793)

## Deployed Contracts

### Main Protocol (Deployer: 0x5f29827e25dc174a6A51C99e6811Bbd7581285b0)
- **EscrowSrc**: `0x77CC1A51dC5855bcF0d9f1c1FceaeE7fb855a535`
- **EscrowDst**: `0x36938b7899A17362520AA741C0E0dA0c8EfE5e3b`
- **CrossChainEscrowFactory**: `0x75ee15F6BfDd06Aee499ed95e8D92a114659f4d1`

### Resolver Infrastructure (Bob: 0xfdF1dDeB176BEA06c7430166e67E615bC312b7B5)
- **Resolver Factory**: `0xe767202fD26104267CFD8bD8cfBd1A44450DC343`

## Key Changes Made
1. Updated foundry.toml to use `evm_version = 'cancun'`
2. Fixed EscrowDst constructor to include accessToken parameter
3. Implemented CREATE3 deployment scripts for cross-chain consistency
4. Achieved deterministic addresses across Base and Etherlink

## Deployment Scripts
- `script/DeployWithCREATE3.s.sol` - Main protocol deployment
- `script/DeployResolverCREATE3.s.sol` - Resolver infrastructure

## Deployment Commands
```bash
# Deploy main contracts
source .env && forge script script/DeployWithCREATE3.s.sol --rpc-url $BASE_RPC_URL --broadcast
source .env && forge script script/DeployWithCREATE3.s.sol --rpc-url $ETHERLINK_RPC_URL --broadcast

# Deploy resolver contracts  
source .env && forge script script/DeployResolverCREATE3.s.sol --rpc-url $BASE_RPC_URL --broadcast
source .env && forge script script/DeployResolverCREATE3.s.sol --rpc-url $ETHERLINK_RPC_URL --broadcast
```