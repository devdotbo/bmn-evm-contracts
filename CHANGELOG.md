# Changelog

All notable changes to the BMN EVM Contracts will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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