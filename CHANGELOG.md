# Changelog

All notable changes to the BMN EVM Contracts will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [3.0.1] - 2025-01-18

### Fixed
- **CRITICAL**: Fixed `InvalidCreationTime` error that made all atomic swaps fail in v3.0.0
  - Root cause: Hardcoded 2-hour `dstCancellation` timeout incompatible with reduced 60s `TIMESTAMP_TOLERANCE`
  - Solution: Aligned `dstCancellation` with `srcCancellation` to ensure validation always passes
  - Added timestamp validation to prevent underflow when timestamps are in the past

### Changed
- `dstCancellation` now dynamically calculated to match `srcCancellation` offset
- Added validation requiring `srcCancellationTimestamp` and `dstWithdrawalTimestamp` to be in the future

### Deployed
- Successfully deployed and verified on Base (8453) and Optimism (10) mainnet
- **Base Addresses**:
  - Factory: `0x4E03F2dA3433626c4ed65544b6A99a013f5768d2` ✅ Verified
  - EscrowSrc: `0xA835C525d0BD76baFC56920230E13fD37015E7D2` ✅ Verified
  - EscrowDst: `0xaAB8a9cd52f55c536b776172e2C2CfdB6444359e` ✅ Verified
- **Optimism Addresses**:
  - Factory: `0x0EB761170E01d403a84d6237b5A1776eE2091eA3` ✅ Verified
  - EscrowSrc: `0x92BB1E1c068fF5d26fCf4031193618FEaCfcC593` ✅ Verified
  - EscrowDst: `0xbFa072CCB0d0a6d31b00A70718b75C1CDA09De73` ✅ Verified

### Impact
- Restores full protocol functionality
- Enables instant atomic swaps with any cancellation time (5 minutes, 1 hour, etc.)
- Maintains tight 60-second cross-chain timing validation
- No changes to external interfaces - fully backward compatible

### Migration
- Update resolver configurations to point to v3.0.1 factory addresses
- v3.0.0 factory should be considered deprecated and unusable
- No code changes required - interfaces remain the same

## [3.0.0] - 2025-08-15 [DEPRECATED - CRITICAL BUG]

### WARNING
- **DO NOT USE THIS VERSION** - Contains critical bug that breaks all atomic swaps
- All escrow creation fails with `InvalidCreationTime` error
- Use v3.0.1 instead which contains the fix

### Added
- Whitelist bypass functionality for permissionless access
  - New `whitelistBypassed` flag in SimplifiedEscrowFactory
  - Set to `true` by default in constructor for easier onboarding
  - Allows all addresses to act as resolvers without whitelisting
- Comprehensive test suite for v3.0.0 changes (`test/V3_0_Changes.t.sol`)
- Unified deployment script (`script/DeployMainnet.s.sol`) for all versions
- Deployment automation script (`scripts/deploy-mainnet.sh`) with verification
- Contract verification instructions in CLAUDE.md

### Changed
- **BREAKING**: Reduced timing constraints for improved UX:
  - TIMESTAMP_TOLERANCE reduced from 300 to 60 seconds
  - srcWithdrawal: Can now be 0 seconds (immediate withdrawal supported)
  - srcPublicWithdrawal: Reduced to 10 minutes (was 30 minutes)
  - srcCancellation: Reduced to 20 minutes (was 1 hour)
  - All timelock periods proportionally reduced
- Updated factory constructor to fix argument order (rescueDelay, accessToken)
- Consolidated deployment scripts into single unified version
- Improved deployment documentation with verification status tracking

### Fixed
- Constructor argument order in factory deployment scripts
- Restored zeframlou-create3-factory dependency files that were accidentally removed

### Deployment
- Successfully deployed v3.0.0 to Base (8453) and Optimism (10) mainnet
- All contracts verified on both Basescan and Optimistic Etherscan
- Deterministic addresses via CREATE3:
  - Factory: `0xa820F5dB10AE506D22c7654036a4B74F861367dB`
  - EscrowSrc: `0xaf7D19bfAC3479627196Cc9C9aDF0FB67A4441AE`
  - EscrowDst: `0x334787690D3112a4eCB10ACAa1013c12A3893E74`

### Removed
- Legacy v2.2 and v2.3 deployment scripts (replaced with unified version)

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