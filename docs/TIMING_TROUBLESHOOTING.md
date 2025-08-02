# Timing Troubleshooting Guide

## Overview

This guide helps resolve timing-related issues in the Bridge-Me-Not cross-chain atomic swap protocol. With 1-second block mining enabled, the protocol is now more responsive and easier to test.

## Key Timing Improvements

### 1. **1-Second Block Mining**
Both Anvil chains now mine blocks every second (`--block-time 1`), providing:
- Predictable timestamp increments
- Faster test execution
- Reduced timestamp drift
- More granular timelock control

### 2. **Optimized Timelock Windows**
Timelock stages have been reduced from minutes to seconds:
- **Withdrawal**: 0s (immediate)
- **Public Withdrawal**: 10s
- **Cancellation**: 30s
- **Public Cancellation**: 45s

### 3. **Timestamp Synchronization**
Use `./scripts/sync-chain-timestamps.sh` to:
- Check current timestamps on both chains
- Automatically sync if drift > 2 seconds
- Monitor timestamp drift in real-time

### 4. **Timing Helpers**
New utilities in `scripts/timing-helpers.sh`:
- `get_chain_timestamp`: Get current timestamp
- `wait_for_timestamp`: Wait for specific time
- `mine_to_timestamp`: Force mine to timestamp
- `show_timing_status`: Display timing info

## Common Issues and Solutions

### Issue 1: InvalidCreationTime Error

**Symptom**: Transaction reverts with `InvalidCreationTime()`

**Cause**: Destination chain timestamp validation fails

**Solution**:
```bash
# Synchronize timestamps before testing
./scripts/sync-chain-timestamps.sh

# Wait for sync to complete (shows real-time drift)
# Press Ctrl+C when drift is < 2 seconds
```

### Issue 2: Missed Timelock Windows

**Symptom**: Cannot withdraw/cancel within expected window

**Cause**: Operation attempted outside valid timelock period

**Solution**:
```bash
# Check current timing status
source scripts/timing-helpers.sh
show_timing_status $(get_chain_timestamp "http://localhost:8545")

# Shows active/pending windows:
# - Withdrawal: Active (0-30s)
# - Cancellation: Pending (starts in Xs)
```

### Issue 3: Timestamp Drift During Test

**Symptom**: Chains diverge during long-running tests

**Cause**: Independent block mining on each chain

**Solution**:
```bash
# Run sync in background during tests
./scripts/sync-chain-timestamps.sh &
SYNC_PID=$!

# Run your test
./scripts/test-live-swap.sh

# Stop sync when done
kill $SYNC_PID
```

### Issue 4: Slow Test Execution

**Symptom**: Tests take too long waiting for timelocks

**Cause**: Not utilizing 1-second blocks effectively

**Solution**:
```bash
# Force mine to specific timestamp
source scripts/timing-helpers.sh
mine_to_timestamp "http://localhost:8545" $(($(date +%s) + 30)) "Chain A"
```

## Testing Best Practices

### 1. Pre-Test Setup
```bash
# Start chains with 1-second blocks
./scripts/multi-chain-setup.sh

# Synchronize timestamps
./scripts/sync-chain-timestamps.sh

# Deploy contracts
./scripts/deploy-both-chains.sh
```

### 2. During Testing
- Monitor timing status between phases
- Check timestamp drift if errors occur
- Use timing helpers for debugging

### 3. Debugging Commands
```bash
# Check individual chain timestamps
curl -s -X POST http://localhost:8545 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_getBlockByNumber","params":["latest", false],"id":1}' \
  | jq -r '.result.timestamp' | xargs printf "%d\n" | xargs -I {} date -r {}

# Monitor block production
watch -n 1 'curl -s localhost:8545 -X POST -H "Content-Type: application/json" \
  -d "{\"jsonrpc\":\"2.0\",\"method\":\"eth_blockNumber\",\"params\":[],\"id\":1}" \
  | jq -r ".result" | xargs printf "%d\n"'
```

## Advanced Timing Control

### Manual Timestamp Setting
```bash
# Set specific timestamp on Chain A
curl -X POST http://localhost:8545 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"anvil_setNextBlockTimestamp","params":[1754133700],"id":1}'

# Mine block to apply
curl -X POST http://localhost:8545 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"anvil_mine","params":["0x1"],"id":1}'
```

### Automated Mining Control
```bash
# Pause auto-mining
curl -X POST http://localhost:8545 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"anvil_autoImpersonateAccount","params":[false],"id":1}'

# Resume auto-mining
curl -X POST http://localhost:8545 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"anvil_autoImpersonateAccount","params":[true],"id":1}'
```

## Production Considerations

While 1-second blocks work well for testing, production environments require:
- Larger timelock windows (minutes/hours)
- Higher timestamp tolerance (5+ minutes)
- Chain-specific block time assumptions
- Monitoring for reorgs and timestamp manipulation

## Summary

The timing improvements make the protocol much easier to test:
1. **1-second blocks** eliminate long waits
2. **Timestamp sync** prevents drift issues
3. **Timing helpers** provide visibility
4. **Shorter timelocks** speed up test cycles

For any timing issues not covered here, check:
- Chain connectivity: `nc -z localhost 8545`
- Block production: Watch block numbers increment
- Timestamp drift: Run sync script
- Contract state: Check escrow timelocks