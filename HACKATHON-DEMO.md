# CrossChainResolverV2 Live Demo

## Deployed Contracts

### Base Mainnet
- Resolver: `0xeaee1Fd7a1Fe2BC10f83391Df456Fe841602bc77`
- Factory: `0xBF293D1ad9C2C9a963f8527A221B5C4924C664D4`

### Etherlink Mainnet
- Resolver: `0x3bCACdBEC5DdF9Ec29da0E04a7d846845396A354`
- Factory: `0x15Ce25FA34a29ce21Ae320BBF943DEf01cB9b384`

## Demo Flow

### 1. Fund Accounts with BMN Tokens

First, ensure Alice has BMN on Base and Bob has BMN on Etherlink:

```bash
# Check balances
cast call 0x9C32618CeeC96b9DC0b7c0976c4b4cf2Ee452988 "balanceOf(address)" $ALICE_ADDRESS --rpc-url $BASE_RPC_URL
cast call 0x9C32618CeeC96b9DC0b7c0976c4b4cf2Ee452988 "balanceOf(address)" $BOB_ADDRESS --rpc-url $ETHERLINK_RPC_URL
```

### 2. Initiate Swap on Base

Run the test script to initiate a swap:

```bash
source .env && forge script script/TestResolverLive.s.sol --rpc-url $BASE_RPC_URL --broadcast
```

This will:
- Create a secret and hashlock
- Approve BMN tokens
- Call `initiateSwap()` on the Base resolver
- Emit a `SwapInitiated` event with the swap ID

### 3. Create Destination Escrow on Etherlink

The resolver (Bob) monitors the SwapInitiated event and creates the destination escrow:

```bash
# Get the swap ID from the event
SWAP_ID=<swap_id_from_event>

# Create destination escrow
cast send 0x3bCACdBEC5DdF9Ec29da0E04a7d846845396A354 \
  "createDestinationEscrow(bytes32,address,address,address,uint256,bytes32,uint256,uint256)" \
  $SWAP_ID $ALICE_ADDRESS $BOB_ADDRESS 0x9C32618CeeC96b9DC0b7c0976c4b4cf2Ee452988 \
  10000000000000000000 $HASHLOCK $TIMELOCKS $SRC_TIMESTAMP \
  --value 0.001ether \
  --rpc-url $ETHERLINK_RPC_URL \
  --private-key $BOB_PRIVATE_KEY
```

### 4. Complete the Swap

Bob withdraws on Etherlink (reveals secret):
```bash
cast send 0x3bCACdBEC5DdF9Ec29da0E04a7d846845396A354 \
  "withdraw(bytes32,bytes32,bool)" \
  $SWAP_ID $SECRET false \
  --rpc-url $ETHERLINK_RPC_URL \
  --private-key $BOB_PRIVATE_KEY
```

Alice withdraws on Base (uses revealed secret):
```bash
cast send 0xeaee1Fd7a1Fe2BC10f83391Df456Fe841602bc77 \
  "withdraw(bytes32,bytes32,bool)" \
  $SWAP_ID $SECRET true \
  --rpc-url $BASE_RPC_URL \
  --private-key $ALICE_PRIVATE_KEY
```

## Key Innovation

Unlike traditional approaches that rely on CREATE2 address prediction (which fails with `block.timestamp`), our 1inch-style resolver:

1. **Pre-deployed on both chains** - No address prediction needed
2. **Event-driven** - Easy to monitor and automate
3. **Swap ID tracking** - Clean state management
4. **No timestamp issues** - Resolver handles deployment timing

## Architecture Benefits

```
Traditional (Fails):
Alice → Predict Address → Deploy → Mismatch! → InvalidImmutables()

Our Solution (Works):
Alice → Resolver.initiateSwap() → Event → Resolver tracks → Success!
```

## Success Metrics

- ✅ No address prediction errors
- ✅ Clean event-based monitoring
- ✅ Atomic cross-chain swaps
- ✅ Production-ready pattern
- ✅ Deployed on mainnets