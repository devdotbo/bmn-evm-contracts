# Changelog

All notable changes to the BMN EVM Contracts will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [2.3.0] - 2025-08-12

### Added
- EIP-712 resolver-signed public actions in escrows
  - `publicWithdrawSigned` and `publicCancelSigned` in `EscrowSrc`/`EscrowDst`
  - Solady-style EIP-712 helper (`contracts/utils/SoladyEIP712.sol`)
  - Domain: name "BMN-Escrow", version "2.3"
- Factory compatibility view `isWhitelistedResolver(address)` in `SimplifiedEscrowFactory`
- Unified v2.3 deploy script: `script/DeployV2_3_Mainnet.s.sol`
- v2.3 factory that deploys its own escrows: `contracts/SimplifiedEscrowFactoryV2_3.sol`
- Unit test `test/EIP712Escrow.t.sol` for domain/digest and signature recovery

### Changed
- `BaseEscrow` now extends EIP-712 helper and exposes digest/recover for testing
- Kept token-gated methods for backward compatibility alongside signed variants

### Deployment
- Deployed and verified on Base (8453) and Optimism (10) at the same address via CREATE3:
  - Factory v2.3: `0xdebE6F4bC7BaAD2266603Ba7AfEB3BB6dDA9FE0A`
  - Deployment envs: `deployments/v2.3.0-mainnet-{8453,10}.env`

### Removed/Archived
- Consolidated deployment scripts; use only `DeployV2_3_Mainnet.s.sol` for mainnet.

## [2.2.0] - 2025-01-07

### Added
- **IPostInteraction Interface Implementation** in SimplifiedEscrowFactory
  - Enables atomic escrow creation through 1inch SimpleLimitOrderProtocol
  - postInteraction() method handles callbacks after order fills
  - Automatic token transfer from resolver to escrow
  - PostInteractionEscrowCreated event for tracking
- **BMNToken Contract** - Local implementation compatible with Solidity 0.8.23
- **MockLimitOrderProtocol** - Testing infrastructure for order fills
- **PostInteractionTest Suite** - Comprehensive testing of the integration
- **Documentation Updates**
  - docs/POSTINTERACTION_IMPLEMENTATION.md - Complete implementation details
  - docs/CURRENT_STATE.md - Current project status and roadmap
  - Archived completed plan to docs/completed/

### Fixed
- **Critical: Atomic Escrow Creation** - SimplifiedEscrowFactory now properly integrates with SimpleLimitOrderProtocol
  - Implemented IPostInteraction interface
  - Handles token flow: maker → taker → escrow
  - Validates resolver whitelisting
  - Prevents duplicate escrow creation

### Changed
- SimplifiedEscrowFactory now extends IPostInteraction
- Added internal _createSrcEscrowInternal() for code reuse
- Improved timelock packing for escrow creation

### Performance
- PostInteraction gas usage: ~105,535 gas per call
- Well within 250k gas target
- Efficient CREATE2 deployment pattern maintained

## [2.1.0] - 2025-01-06

### Added
- SimplifiedEscrowFactory for mainnet deployment
- Basic escrow creation functionality
- Resolver whitelisting

### Changed
- Simplified architecture for faster deployment
- Removed complex features for initial release

## [2.0.0] - 2025-01-05

### Added
- BaseEscrowFactory with full IPostInteraction support
- CrossChainEscrowFactory for multi-chain atomic swaps
- MerkleStorageInvalidator for proof validation
- Comprehensive test suite

### Changed
- Upgraded to Solidity 0.8.23
- Improved gas optimization
- Enhanced security measures

## [1.0.0] - 2025-01-01

### Added
- Initial escrow contracts
- Basic atomic swap functionality
- Factory pattern implementation