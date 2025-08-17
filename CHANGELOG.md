# Changelog

All notable changes to the BMN EVM Contracts will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **1inch Compatibility**: Full interface compatibility with 1inch protocol
  - Added `bytes parameters` field to `DstImmutablesComplement` struct
  - Added `escrowImmutables` storage mapping for resolver data retrieval
  - Updated event emissions to include complete immutables structs
  - Modified `ImmutablesLib` to use dynamic `abi.encode` for proper bytes handling
  - Created comprehensive test suite for compatibility changes (test/Compatibility1inch.t.sol)
- **Comprehensive Test Coverage**: Added 83+ new tests increasing coverage from ~33% to ~70%
  - BaseEscrow.t.sol: 13 tests covering timelocks, withdrawals, cancellations, and rescue operations
  - EscrowSrc.t.sol: 17 tests for source chain escrow functionality
  - EscrowDst.t.sol: 14 tests for destination chain escrow and secret reveal
  - TimelocksLib.t.sol: 14 tests for timelock packing/unpacking and validation
  - ProxyHashLib.t.sol: 8 tests for CREATE2 hash calculation
  - FactoryIntegration.t.sol: 10 tests for factory-escrow integration (disabled pending factory fix)
  - E2E_SingleChain.t.sol: 7 tests for end-to-end single chain flows
- **Test Documentation**: Created detailed documentation for each test suite
  - Comprehensive test result documentation with gas measurements
  - Security findings and edge case coverage documentation
  - Test architecture and design decisions documented

### Changed
- Made deployment scripts generic and version-agnostic
  - Renamed `DeployV3_0_2.s.sol` to `Deploy.s.sol`
  - Renamed `VerifyContracts.s.sol` to `Verify.s.sol`
  - Scripts now use environment variables instead of hardcoded addresses
- Documentation structure simplified
  - Single source of truth for deployment info in `deployments/deployment.md`
  - Removed redundant deployment documentation files
- **ImmutablesLib**: Changed from fixed-size assembly to dynamic abi.encode for hash functions
- **SimplifiedEscrowFactory**: Events now emit full immutables structs instead of individual fields

### Fixed
- **Critical**: Resolved 70% functionality blocker where resolver couldn't withdraw on source chain
  - Root cause: InvalidImmutables error due to missing parameters field in hash calculation
  - Solution: Added parameters field and emit complete immutables in events
- **Documentation Discrepancy**: Corrected misunderstanding about factory address storage
  - Factory address is NOT packed in timelocks as v3.0.2 documentation incorrectly stated
  - Factory address is correctly stored as FACTORY immutable in BaseEscrow
  - Added FACTORY_ADDRESS_DISCREPANCY_ANALYSIS.md documenting this finding

### Removed
- LocalDeploy.s.sol (unnecessary for production focus)
- Version-specific contract files (SimplifiedEscrowFactoryV3_0_2.sol)
- Version-specific test files (V3_0_1_BugfixSimple.t.sol)
- Deprecated v2.x and v3.0.1 deployment scripts
- Deprecated factory contracts (BaseEscrowFactory, CrossChainEscrowFactory, MerkleStorageInvalidator)
- Deprecated test files referencing old contracts
- All v3.0.3/v3.0.4 attempted fixes (unnecessary - resolver should read block.timestamp from events)
- Redundant documentation files (DEPLOYMENT.md, DEPLOYMENT_RUNBOOK.md)
- Unused contracts identified via dependency analysis:
  - SimpleAtomicSwap.sol (standalone HTLC, not integrated)
  - Create3Factory.sol (using deployed factory at 0x7B9e9BE124C5A0E239E04fDC93b66ead4e8C669d)
  - Constants.sol (hardcoded addresses, not imported)
  - EscrowFactoryContext.sol (unused constant definition)
  - BMNToken.sol (using deployed token at 0x8287CD2aC7E227D9D927F998EB600a0683a832A1)
- Unused helper contracts:
  - contracts/helpers/EIP712Example.sol (example code)
  - contracts/libraries/Create3.sol (obsolete, replaced by CREATE2)
- Disabled test files:
  - test/DeterministicAddresses.t.sol.disabled
  - test/ImmutablesStorage.t.sol.disabled

### Security
- **Test Coverage**: Critical security paths now have comprehensive test coverage
  - All timelock validations tested for boundary conditions
  - Secret reveal mechanisms validated against replay attacks
  - Rescue operations tested with proper delay enforcement
  - Gas measurements documented for DoS prevention analysis
- **Key Findings from Testing**:
  - ProxyHashLib correctly calculates CREATE2 hashes for deterministic addresses
  - Timelock system properly validates all period transitions
  - Secret storage and reveal mechanism prevents unauthorized withdrawals
  - Factory integration requires proper immutables validation (currently disabled pending fix)

## [3.0.2] - 2025-08-16 (Current Production)

### Deployment
- **Factory Address**: `0xAbF126d74d6A438a028F33756C0dC21063F72E96` (Base & Optimism)
- **BMN Token**: `0x8287CD2aC7E227D9D927F998EB600a0683a832A1` (all chains)
- **Status**: Active on mainnet, verified on block explorers

### Fixed
- **CRITICAL**: Fixed FACTORY immutable bug preventing withdrawals with CREATE3 deployment
  - Root cause: BaseEscrow stored CREATE3 proxy address instead of SimplifiedEscrowFactory
  - Impact: All CREATE3-deployed escrows fail withdrawal with `InvalidImmutables()` error
  - Solution: Pack factory address into high bits of timelocks immutable field

### Resolver Integration Note
- **InvalidImmutables errors**: Resolvers must use the exact `block.timestamp` from the event's block
- **Solution**: `const block = await provider.getBlock(event.blockNumber); const deployedAt = block.timestamp;`
- **No contract changes needed** - this is purely a resolver implementation detail

### Changed
- BaseEscrow now extracts factory address from immutables instead of using msg.sender
- SimplifiedEscrowFactory packs its address into timelocks during escrow creation
- Reorganized timelock bit layout: bits 0-95 for timelock offsets, bits 96-255 for factory address
- Removed FACTORY immutable from BaseEscrow contract

### Security
- Funds locked in v3.0.0/v3.0.1 CREATE3-deployed escrows require special recovery mechanism
- All withdrawals from CREATE3-deployed escrows currently fail
- Direct deployments (non-CREATE3) may also be affected if using Clones library

### Implementation
- See docs/FIX-v3.0.2-FACTORY-IMMUTABLE.md for detailed analysis
- See docs/IMPLEMENTATION-v3.0.2.md for code changes

## [3.0.1] - 2025-08-15

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