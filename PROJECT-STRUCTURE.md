# Project Structure - Bridge Me Not EVM Contracts

## Current Architecture

### Core Contracts
- `EscrowFactory.sol` - Main factory for creating escrows (has CREATE2 timestamp issue)
- `EscrowSrc.sol` - Source chain escrow for locking tokens
- `EscrowDst.sol` - Destination chain escrow
- `BaseEscrow.sol` - Shared escrow functionality
- `CrossChainResolverV2.sol` - 1inch-style resolver (still uses factory, so has same issue)

### Test Contracts
- `TestEscrowFactory.sol` - Factory with direct escrow creation for testing

### Key Scripts
- `DeployBMNProtocol.sol` - Deploy core protocol with CREATE2
- `DeployResolverMainnet.sol` - Deploy CrossChainResolverV2
- `CompleteResolverSwap.sol` - Complete cross-chain swaps
- `LocalDeploy.sol` - Local development deployment

### Current Deployments

#### Base Mainnet (8453)
- TestEscrowFactory: `0xBF293D1ad9C2C9a963f8527A221B5C4924C664D4`
- CrossChainResolverV2: `0xeaee1Fd7a1Fe2BC10f83391Df456Fe841602bc77`
- BMN Token: `0x8287CD2aC7E227D9D927F998EB600a0683a832A1`

#### Etherlink Mainnet (42793)
- TestEscrowFactory: `0x15Ce25FA34a29ce21Ae320BBF943DEf01cB9b384`
- CrossChainResolverV2: `0x3bCACdBEC5DdF9Ec29da0E04a7d846845396A354`
- BMN Token: `0x8287CD2aC7E227D9D927F998EB600a0683a832A1`

## Known Issues

1. **CREATE2 Address Prediction Fails**: Factory uses `block.timestamp` which differs from calculation time
2. **CrossChainResolverV2 Has Same Issue**: Still relies on factory's CREATE2 deployment
3. **Need Event-Driven Resolver**: Real solution requires TypeScript/Deno service monitoring events

## Next Steps

Move to `bmn-evm-resolver` project to implement proper event-driven resolver service.