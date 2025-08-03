# Resolver Agent State Documentation

## Current Mainnet Test Status

### Overview
The mainnet cross-chain atomic swap test between Base and Etherlink has partially succeeded but encountered issues with address calculation and timestamp synchronization.

### Completed Steps

1. **Order Creation (Base)** ✅
   - Secret: `0x065ffa72d04873fca0bb49ad393714a5ad7874e3f48530479a8d3311269dd3c3`
   - Hashlock: `0x8734851858690223c82cf16d033a3179edc41df4dc8b1dbe45211bd19b19b77f`

2. **Source Escrow Creation (Base)** ✅
   - Address: `0xE73bFBDA2536DeD96dDCe725C31cc14FBE30d846`
   - Alice locked 10 BMN tokens
   - Deploy time: 1754229097

3. **Destination Escrow Creation (Etherlink)** ⚠️
   - Expected address: `0x123E3050719EAD96862a370C0a00CABc1BD7aB4c`
   - Actual address: `0xfDa2D0E5aa2441D1Fc02Bc3BF423da37F5ca42D9`
   - Deploy time: 1754229116 (15 seconds later than expected)
   - Bob locked 10 BMN tokens + safety deposit

4. **Destination Withdrawal (Etherlink)** ✅
   - Alice revealed the secret
   - Tokens went to Bob (maker on destination chain)
   - Transaction successful but Alice received 0 BMN (expected behavior)

5. **Source Withdrawal (Base)** ❌
   - Failed with `InvalidImmutables()` error
   - Timestamp mismatch preventing Bob from claiming tokens

### Key Issues Identified

1. **Address Calculation Mismatch**
   - Factory uses `block.timestamp` when deploying escrows
   - Script predicts address before transaction is mined
   - 15-second delay between calculation and actual deployment

2. **Immutables Validation**
   - Escrows validate immutables including timelocks
   - Timelocks contain deployment timestamp
   - Mismatch causes `InvalidImmutables()` errors

3. **State File Corruption**
   - Nested structure became corrupted during updates
   - Paths like `.existing.existing.existing.secret` indicate multiple nesting levels

### Solution Implementation

#### Using vm.recordLogs() for Event-Driven Deployment

```solidity
// Record logs to capture the event
vm.recordLogs();
IEscrowFactory(etherlink.factory).createDstEscrow{value: SAFETY_DEPOSIT}(dstImmutables, srcCancellationTimestamp);

// Get the logs and find DstEscrowCreated event
Vm.Log[] memory logs = vm.getRecordedLogs();
address actualDstEscrow;
uint256 actualDeploymentTime = block.timestamp;

for (uint256 i = 0; i < logs.length; i++) {
    if (logs[i].emitter == etherlink.factory && 
        logs[i].topics[0] == keccak256("DstEscrowCreated(address,bytes32,address)")) {
        // The event has non-indexed parameters, so decode from data
        (actualDstEscrow,,) = abi.decode(logs[i].data, (address, bytes32, address));
        break;
    }
}
```

### Current Token Balances

**Base (Chain 8453)**
- Alice: 1990 BMN (locked 10 in source escrow)
- Bob: 2000 BMN (waiting to withdraw from source)

**Etherlink (Chain 42793)**
- Alice: 2000 BMN (expected 2010 after withdrawal)
- Bob: 2010 BMN (received 10 from destination escrow)

### Next Steps for Resolver

1. **Fix Source Withdrawal**
   - Calculate correct immutables with actual deployment timestamp
   - Retry withdrawal with proper parameters

2. **Update LiveTestMainnet.s.sol**
   - Implement proper event handling for all escrow deployments
   - Store actual deployment parameters in state file
   - Handle timestamp synchronization correctly

3. **Clean State Management**
   - Fix nested JSON structure in state file
   - Implement proper state transitions
   - Add validation for state consistency

### Resolver Agent Tasks

1. Monitor order creation events on source chain
2. Deploy destination escrow with correct parameters
3. Wait for maker withdrawal and secret reveal
4. Execute taker withdrawal on source chain
5. Handle edge cases and timeouts

### Important Constants

- Swap Amount: 10 BMN (10e18)
- Safety Deposit: 0.00001 ETH
- BMN Token on Base: `0x8287CD2aC7E227D9D927F998EB600a0683a832A1`
- BMN Token on Etherlink: `0x8287CD2aC7E227D9D927F998EB600a0683a832A1`
- Factory on Base: `0xD2a2200c9C45eCd2F6030d54d8B27B882493E812`
- Factory on Etherlink: `0x6b3E1410513DcC0874E367CbD79Ee3448D6478C9`

### Lessons Learned

1. Always use event logs for deployed addresses, never predict
2. Account for block timestamp differences between script and mining
3. Maintain clean state file structure to avoid nested corruption
4. Test withdrawal immutables calculation separately before mainnet
5. Consider using multicall for atomic operations where possible