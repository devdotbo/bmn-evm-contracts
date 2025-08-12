# Bridge Me Not - Deployment History

## Overview

This document tracks all production deployments of the Bridge Me Not protocol across Base, Etherlink, and Optimism chains.

## Current Production Deployment (v2.3.0)

**Deployment Date**: August 12, 2025

### Core Protocol Contracts

| Contract | Address | Chains | Notes |
|----------|---------|--------|-------|
| BMN Token | `0x8287CD2aC7E227D9D927F998EB600a0683a832A1` | Base, Etherlink, Optimism | Fee and access token |
| EscrowSrc Impl | Deterministic via factory | Base, Optimism | Deployed by v2.3 factory constructor |
| EscrowDst Impl | Deterministic via factory | Base, Optimism | Deployed by v2.3 factory constructor |
| SimplifiedEscrowFactoryV2_3 | `0xdebE6F4bC7BaAD2266603Ba7AfEB3BB6dDA9FE0A` | Base, Optimism | **v2.3.0** - EIP-712 resolver-signed actions, CREATE3 |

### Resolver Infrastructure

| Contract | Address | Chains | Notes |
|----------|---------|--------|-------|
| Resolver Factory | `0xe767202fD26104267CFD8bD8cfBd1A44450DC343` | Base, Etherlink, Optimism | Factory for resolver contracts |

### Infrastructure

| Contract | Address | Chains | Notes |
|----------|---------|--------|-------|
| CREATE3 Factory | `0x7B9e9BE124C5A0E239E04fDC93b66ead4e8C669d` | Base, Etherlink, Optimism | Used for deterministic deployments |

## Previous Deployments

### v2.2.0 (January 7, 2025)
PostInteraction-enabled SimplifiedEscrowFactory deployed to Base and Optimism (see `deployments/v2.2.0-mainnet-*.env`).

### v1.1.0
Enhanced events for indexers; see historical entries below.

### v1.0.0
Initial deployment.

### Core Protocol Contracts

| Contract | Address | Chains | Notes |
|----------|---------|--------|-------|
| EscrowSrc | `0x77CC1A51dC5855bcF0d9f1c1FceaeE7fb855a535` | Base, Etherlink | Same as v1.1.0 |
| EscrowDst | `0x36938b7899A17362520AA741C0E0dA0c8EfE5e3b` | Base, Etherlink | Same as v1.1.0 |
| CrossChainEscrowFactory | `0x75ee15F6BfDd06Aee499ed95e8D92a114659f4d1` | Base, Etherlink | **v1.0.0** - Original factory |

## Version Changes

### v1.1.0 (August 5, 2025)

**Purpose**: Solve Ponder indexing issues on Etherlink

**Changes**:
- Factory events now emit escrow addresses as first indexed parameter
- `SrcEscrowCreated` event enhanced with escrow address
- `DstEscrowCreated` event parameters now indexed
- No changes to escrow implementations (reused v1.0.0)

**Benefits**:
- Eliminates need for CREATE2 address calculation in indexers
- Fixes Ponder factory pattern bug on Etherlink
- Simplifies resolver implementation
- Gas impact minimal (<1% increase)

**Deployment Details**:
- Base: Block 33806117, TX: `0x1bde783e6c3e4f8ecf24aa0736d1e093ae9f69e66961c0435b230b270de4a2d4`
- Etherlink: Block 22641583, TX: `0x418f22a01a7724a1edec9ca7e278b299a29c8c5375abba126b689cee04463772`
- Optimism: Factory v1.1.0 at `0xB916C3edbFe574fFCBa688A6B92F72106479bD6c` (Note: Different salt used)

### v1.0.0 (Initial)

**Purpose**: Initial protocol deployment

**Features**:
- Cross-chain atomic swaps without bridges
- Hash Timelock Contracts (HTLC) implementation
- Integration with 1inch Limit Order Protocol
- Deterministic escrow addresses via CREATE2

## Deployment Scripts

### Current Scripts
- `script/DeployFactoryUpgrade.s.sol` - Deploys v1.1.0 factory
- `script/VerifyFactoryUpgrade.s.sol` - Verifies v1.1.0 deployment

### Legacy Scripts
- `script/DeployWithCREATE3.s.sol` - Original deployment script
- `script/LocalDeploy.s.sol` - Local testing deployment

## Migration Notes

### From v1.0.0 to v1.1.0
- Existing escrows continue working normally
- Indexers need update to handle new event format
- Resolvers can optionally update to use emitted addresses
- No user action required

## Verification

All contracts are verified on:
- BaseScan: https://basescan.org/address/[CONTRACT_ADDRESS]
- Etherlink: Manual verification may be required

## Chain Information

### Base (Chain ID: 8453)
- RPC: Configured in `.env` as `BASE_RPC_URL`
- Explorer: https://basescan.org

### Etherlink (Chain ID: 42793)
- RPC: Configured in `.env` as `ETHERLINK_RPC_URL`
- Explorer: https://explorer.etherlink.com

### Optimism (Chain ID: 10)
- RPC: Configured in `.env` as `OPTIMISM_RPC_URL`
- Explorer: https://optimistic.etherscan.io

## Future Deployments

When deploying new versions:
1. Update version in deployment salt (e.g., "BMN-CrossChainEscrowFactory-v1.2.0")
2. Document changes in this file
3. Update CLAUDE.md with new addresses
4. Create migration guide if needed
5. Verify on all chains

## Contact

For deployment questions: Refer to deployment scripts and documentation in this repository.