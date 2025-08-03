# Mainnet Test Final Report

## Test Status: EXPIRED

The mainnet cross-chain atomic swap test between Base and Etherlink has **expired** due to exceeding the withdrawal time window.

## Timeline of Events

1. **17:51:35 UTC** - Order created with secret on Base
2. **17:51:37 UTC** - Source escrow deployed on Base (Alice locks 10 BMN)
3. **17:51:56 UTC** - Destination escrow deployed on Etherlink (Bob locks 10 BMN)
4. **~18:00 UTC** - Alice withdraws from destination escrow, revealing secret
5. **18:13:17 UTC** - Attempted Bob's withdrawal from source - **FAILED: InvalidTime()**

## Timelock Analysis

The source escrow had the following timelock configuration:
- **Withdrawal Window**: 0-900 seconds (0-15 minutes)
- **Cancellation Window**: 900+ seconds (15+ minutes)

By the time we attempted Bob's withdrawal (1300 seconds after deployment), we were already 400 seconds into the cancellation period.

## Key Issues Encountered

### 1. Address Calculation Mismatch
- **Problem**: Factory uses `block.timestamp` when deploying, but script calculated address before mining
- **Impact**: 15-second discrepancy between expected and actual deployment
- **Solution**: Implemented `vm.recordLogs()` to capture actual deployed address from events

### 2. State File Corruption
- **Problem**: Multiple nested levels in JSON structure (`.existing.existing.existing.secret`)
- **Impact**: Scripts couldn't parse state correctly
- **Solution**: Created `CleanStateFile.s.sol` to flatten the structure

### 3. Timestamp Synchronization
- **Problem**: Immutables validation requires exact deployment timestamp
- **Impact**: `InvalidImmutables()` errors during withdrawal attempts
- **Solution**: Store actual deployment timestamp and use it for immutables reconstruction

### 4. Time Window Expiration
- **Problem**: 15-minute withdrawal window was too short for debugging
- **Impact**: Swap expired before completion
- **Solution**: Need longer time windows for mainnet testing

## Partial Success

Despite the expiration, the test was partially successful:
- ✅ Order creation worked
- ✅ Source escrow deployment successful
- ✅ Destination escrow deployment successful
- ✅ Secret reveal mechanism worked
- ✅ Alice withdrew from destination (Bob received 10 BMN on Etherlink)
- ❌ Bob couldn't withdraw from source (time expired)

## Final Token Balances

**Base (Chain 8453)**
- Alice: 1990 BMN (locked 10 in expired escrow)
- Bob: 2000 BMN (unable to claim from source)

**Etherlink (Chain 42793)**
- Alice: 2000 BMN (expected 2010, but tokens went to Bob)
- Bob: 2010 BMN (received 10 from destination escrow)

## Lessons Learned

1. **Always use event logs for deployed addresses** - Never try to predict CREATE2 addresses
2. **Account for block timestamp variations** - Script execution time ≠ mining time
3. **Use longer time windows for testing** - 15 minutes is too short for debugging
4. **Implement proper state management** - Avoid nested JSON structures
5. **Test timelock calculations separately** - Verify windows before mainnet deployment
6. **Consider multicall patterns** - Batch operations to reduce timing issues

## Recommendations

1. **Increase test time windows** to at least 1 hour for mainnet testing
2. **Implement retry mechanisms** for failed transactions
3. **Add timelock status checks** before attempting withdrawals
4. **Create recovery scripts** for expired swaps
5. **Use deterministic testing** with controlled block timestamps
6. **Implement comprehensive logging** for all state changes

## Code Improvements Made

1. **LiveTestMainnet.s.sol** - Added proper event handling with `vm.recordLogs()`
2. **FixSourceWithdrawal.s.sol** - Created to handle withdrawal with correct timestamps
3. **CleanStateFile.s.sol** - Fixes corrupted JSON state files
4. **CheckTimelocks.s.sol** - Analyzes current timelock status
5. **DebugMainnetAddress.s.sol** - Helps diagnose address calculation issues

## Next Steps

To complete the swap, someone needs to cancel the source escrow to recover Alice's locked tokens. After the public cancellation period, anyone can trigger this cancellation.