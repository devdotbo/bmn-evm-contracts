# BaseEscrow Test Documentation

## Overview
Comprehensive test suite for the BaseEscrow abstract contract, covering all 7 required test cases plus additional coverage.

## Test File Location
`/home/user/git/2025_2/unite/bridge-me-not/bmn-evm-contracts/test/BaseEscrow.t.sol`

## Key Findings and Implementation Details

### 1. Immutables Validation Mechanism
- **How it works**: BaseEscrow uses `ImmutablesLib.hash()` to compute a keccak256 hash of the entire Immutables struct
- **Validation**: The `_validateImmutables()` function is abstract and must be implemented by derived contracts
- **Testing approach**: Created a `MockBaseEscrow` that stores an expected hash and compares it during validation
- **Important**: Use `ImmutablesLib.hashMem()` for memory structs, `ImmutablesLib.hash()` for calldata

### 2. RESCUE_DELAY Configuration
- **Actual value**: 604800 seconds (7 days)
- **Source**: Confirmed in `script/Deploy.s.sol` line 35: `uint32 rescueDelay = 7 days;`
- **Storage**: Stored as an immutable in BaseEscrow
- **Usage**: Combined with deployedAt timestamp from timelocks to calculate rescue start time

### 3. Factory Address Storage
- **Current implementation**: Stored as immutable `FACTORY = msg.sender` in BaseEscrow constructor
- **NOT packed in timelocks**: Despite documentation suggesting v3.0.2 would pack factory in bits 96-255 of timelocks, the current implementation uses the immutable approach
- **Access**: Available via public `FACTORY()` getter function
- **Deployment context**: When factory deploys escrow, factory address is captured as msg.sender

### 4. Timelocks Structure
- **Packed format**: Single uint256 with multiple time offsets
- **DeployedAt**: Stored in bits 224-255 (highest 32 bits)
- **Time offsets**: Each stage uses 32 bits, storing seconds from deployment time
- **Rescue calculation**: `rescueStart = deployedAt + RESCUE_DELAY`
- **Factory NOT stored here**: Bits 96-223 are used for timelock stages, not factory address

### 5. Mock Contract Pattern
Created `MockBaseEscrow` contract that:
- Extends BaseEscrow with concrete implementations
- Exposes internal functions via public wrappers for testing
- Implements abstract `_validateImmutables()` with simple hash comparison
- Provides mock `withdraw()` and `cancel()` functions that emit events

### 6. Gas Measurements Observed
From test runs with -vvv output:
- Withdraw with validation: 30,996 gas
- Rescue ERC20 tokens: 41,685 gas  
- Rescue native ETH: 39,473 gas

## Test Coverage Summary

### All 7 Required Tests Implemented:
1. ✅ **testConstructorInitialization**: Verifies RESCUE_DELAY and FACTORY immutables set correctly
2. ✅ **testValidateImmutables**: Tests hash validation with correct/incorrect data
3. ✅ **testRescueBeforeDelay**: Confirms revert when called too early (uses InvalidTime error)
4. ✅ **testRescueAfterDelay**: Successful rescue after 7-day delay period
5. ✅ **testRescueOnlyOwner**: Non-taker rescue attempts fail with InvalidCaller
6. ✅ **testGettersReturnCorrectValues**: All view functions return expected values
7. ✅ **testFactoryAddressExtraction**: Documents how factory is stored (immutable, not in timelocks)

### Additional Tests:
- **testInvalidSecretRejection**: Wrong secrets revert with InvalidSecret
- **testAccessTokenHolderCheck**: Documents access token balance checking
- **testTimeBasedModifiers**: Validates onlyAfter/onlyBefore modifiers
- **testGasMeasurements**: Measures gas costs for key operations

## Running the Tests
```bash
# Run with detailed output
source .env && forge test --match-contract BaseEscrowTest -vvv

# Run specific test
source .env && forge test --match-test testConstructorInitialization -vvv

# Run with gas reporting
source .env && forge test --match-contract BaseEscrowTest --gas-report
```

## Important Notes for Next Agent

1. **Error Selectors**: All error selectors come from `IBaseEscrow` interface, not BaseEscrow contract
   - Use `IBaseEscrow.InvalidTime.selector` not `BaseEscrow.InvalidTime.selector`

2. **Access Control**: 
   - Rescue can only be called by taker (stored in immutables)
   - Factory address is accessible but has no special privileges in BaseEscrow

3. **Time Calculations**:
   - All timelocks store offsets from deployment time, not absolute timestamps
   - Rescue start = deployedAt (from timelocks high bits) + RESCUE_DELAY (immutable)

4. **Testing Pattern**:
   - Must create concrete implementation since BaseEscrow is abstract
   - Use public wrapper functions to test internal functions
   - Set up expected immutables hash before testing validation

5. **Current vs Planned Implementation**:
   - Documentation mentions factory address in timelocks bits 96-255 (v3.0.2 plan)
   - Actual implementation uses `immutable FACTORY = msg.sender`
   - This discrepancy is documented but doesn't affect functionality

## Test Results
All 13 tests passing:
- 13 tests passed
- 0 failed
- 0 skipped
- Total gas used across all tests: ~800k
- Execution time: ~1.3ms