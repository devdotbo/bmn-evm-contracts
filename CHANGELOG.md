# Changelog

All notable changes to the BMN EVM Contracts will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [3.0.2] - 2025-01-18

### Fixed
- **CRITICAL**: Fixed `InvalidImmutables` error that made all escrow operations fail in v3.0.0 and v3.0.1
  - Root cause: `FACTORY` immutable in escrows captured CREATE3 factory address instead of SimplifiedEscrowFactory address
  - When implementations deployed via CREATE3, `msg.sender` = CREATE3 factory (0x7B9e9...)
  - But proxy clones deployed by SimplifiedEscrowFactory, causing address mismatch in validation
  - Solution: Factory now deploys its own implementations in constructor (like v2.3.0 did)
  
### Changed
- Created `SimplifiedEscrowFactoryV3_0_2` that deploys implementations in constructor
- Implementation addresses now chain-specific (acceptable trade-off)
- Factory address remains consistent across chains via CREATE3
- Updated deployment script to only deploy factory (implementations handled by factory)

### Technical Details
- Factory constructor calls `new EscrowSrc()` and `new EscrowDst()`
- Ensures `msg.sender` during implementation deployment = SimplifiedEscrowFactory
- `FACTORY` immutable now correctly points to factory address
- Validation in `_validateImmutables` now passes correctly

### Deployment
- Factory deployed via CREATE3 with salt: `keccak256("BMN-SimplifiedEscrowFactory-v3.0.2")`
- Implementation addresses will differ per chain (deployed by factory)
- Predicted factory address: Will be deterministic across all chains

### Impact
- Restores full protocol functionality broken in v3.0.0 and v3.0.1
- All escrow operations (create, withdraw, cancel) now work correctly
- Maintains cross-chain factory address consistency
- No external interface changes - fully backward compatible

### Migration
- Update resolver configurations to point to v3.0.2 factory address
- v3.0.0 and v3.0.1 factories should be considered broken and unusable
- No code changes required for integrators - interfaces remain the same

## [3.0.1] - 2025-01-18 [DEPRECATED - CONTAINS FACTORY BUG]

### WARNING
- **DO NOT USE THIS VERSION** - While it fixed the InvalidCreationTime bug from v3.0.0, it still contains the FACTORY immutable bug
- All escrow operations fail with `InvalidImmutables` error
- Use v3.0.2 instead which contains all fixes

### Fixed
- **CRITICAL**: Fixed `InvalidCreationTime` error that made all atomic swaps fail in v3.0.0
  - Root cause: Hardcoded 2-hour `dstCancellation` timeout incompatible with reduced 60s `TIMESTAMP_TOLERANCE`
  - Solution: Aligned `dstCancellation` with `srcCancellation` to ensure validation always passes
  - Added timestamp validation to prevent underflow when timestamps are in the past

### Changed
- `dstCancellation` now dynamically calculated to match `srcCancellation` offset
- Added validation requiring `srcCancellationTimestamp` and `dstWithdrawalTimestamp` to be in the future

### Deployed
- Successfully deployed using CREATE3 for cross-chain address consistency
- Verified on Base (8453) and Optimism (10) mainnet
- **Same Addresses on All Chains**:
  - Factory: `0xF99e2f0772f9c381aD91f5037BF7FF7dE8a68DDc` ✅ Verified
  - EscrowSrc: `0xF899Ee616C512f5E9Ea499fbd4F60AAA1DdC2D6f` ✅ Verified
  - EscrowDst: `0x42fc825085a2aAd6c4b536Ba3321aCA8B32982B1` ✅ Verified
  - CREATE3 Factory: `0x7B9e9BE124C5A0E239E04fDC93b66ead4e8C669d`

### Impact
- Restores full protocol functionality
- Enables instant atomic swaps with any cancellation time (5 minutes, 1 hour, etc.)
- Maintains tight 60-second cross-chain timing validation
- No changes to external interfaces - fully backward compatible

### Migration
- Update resolver configurations to point to v3.0.1 factory addresses
- v3.0.0 factory should be considered deprecated and unusable
- No code changes required - interfaces remain the same

## [3.0.0] - 2025-08-15 [DEPRECATED - MULTIPLE CRITICAL BUGS]

### WARNING
- **DO NOT USE THIS VERSION** - Contains multiple critical bugs:
  1. All escrow creation fails with `InvalidCreationTime` error (fixed in v3.0.1)
  2. FACTORY immutable bug causes `InvalidImmutables` error (fixed in v3.0.2)
- Use v3.0.2 instead which contains all fixes

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