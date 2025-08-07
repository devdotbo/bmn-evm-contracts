# Changelog

All notable changes to the BMN EVM Contracts will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed
- Critical: SimplifiedEscrowFactory missing IPostInteraction interface preventing atomic swap escrow creation
  - SimpleLimitOrderProtocol was unable to trigger escrow creation after order fills
  - Added comprehensive integration plan in POSTINTERACTION_INTEGRATION_PLAN.md
  - Solution requires implementing IPostInteraction interface in SimplifiedEscrowFactory

### Added
- POSTINTERACTION_INTEGRATION_PLAN.md - Comprehensive guide for fixing the integration issue
- Same-chain atomic swap testing strategy for faster iteration without cross-chain complexity
- Detailed implementation examples for postInteraction method

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