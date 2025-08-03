# CrossChainEscrowFactory Usage Guide

## Deployed Contract

The CrossChainEscrowFactory is deployed at the same address on both Base and Etherlink:
- **Factory Address**: `0xc72ed1E8a0649e51Cd046a0FfccC8f8c0bf385Fa`
- **BMN Token**: `0x8287CD2aC7E227D9D927F998EB600a0683a832A1` (18 decimals)

## Key Concepts

The CrossChainEscrowFactory integrates with 1inch Limit Order Protocol:

1. **Source Escrow Creation**: Happens automatically through the limit order protocol's `postInteraction` hook
2. **Destination Escrow Creation**: Can be done directly via `createDstEscrow()`

## How It Works

### 1. Source Chain (e.g., Base)
- User creates a limit order through 1inch protocol
- When the order is filled, the factory's `postInteraction` hook is triggered
- This automatically deploys the source escrow and locks the maker's tokens

### 2. Destination Chain (e.g., Etherlink)
- Resolver calls `createDstEscrow()` directly on the factory
- Must pre-fund the escrow address with safety deposit (ETH)
- Escrow is deployed and resolver's tokens are locked

### 3. Atomic Swap Execution
- Maker withdraws from destination escrow (reveals secret)
- Taker/Resolver uses revealed secret to withdraw from source escrow

## Available Functions

### For Destination Escrow Creation
```solidity
function createDstEscrow(
    IBaseEscrow.Immutables calldata dstImmutables,
    uint256 srcCancellationTimestamp
) external payable
```

### To Calculate Escrow Addresses
```solidity
function addressOfEscrowSrc(IBaseEscrow.Immutables calldata immutables) external view returns (address)
function addressOfEscrowDst(IBaseEscrow.Immutables calldata immutables) external view returns (address)
```

## Testing

For testing without the full limit order protocol integration:
1. Deploy a TestEscrowFactory that allows direct source escrow creation
2. Use the 1inch SDK to create proper limit orders
3. Monitor existing atomic swaps on-chain

## Current Status

The factory is fully deployed and operational. Previous atomic swaps have been successfully executed as evidenced by the balance changes in the test accounts.