# Hackathon Deployment Results

## Successful Mainnet Deployments

### Base Mainnet (Chain ID: 8453)
- **TestEscrowFactory**: `0xBF293D1ad9C2C9a963f8527A221B5C4924C664D4`
- **CrossChainResolverV2**: `0xeaee1Fd7a1Fe2BC10f83391Df456Fe841602bc77`
- **Fee Token**: `0x9A998b1f605dd2c029FFFb055ba8e4481e06Ab92`
- **Access Token**: `0xa9d0EDf871e8F92f4b7a6e9d0a9F06b345D2B919`
- **BMN Token**: `0x9C32618CeeC96b9DC0b7c0976c4b4cf2Ee452988`

### Etherlink Mainnet (Chain ID: 42793)
- **TestEscrowFactory**: `0x15Ce25FA34a29ce21Ae320BBF943DEf01cB9b384`
- **CrossChainResolverV2**: `0x3bCACdBEC5DdF9Ec29da0E04a7d846845396A354`
- **Fee Token**: `0x403c34B879B117903850dC21c44d3c31350755EA`
- **Access Token**: `0x2fDeEcA7E31e1144e8A58Bc22610f631EE7738Bc`
- **BMN Token**: `0x9C32618CeeC96b9DC0b7c0976c4b4cf2Ee452988`

## Key Innovation

We solved the CREATE2 address prediction problem by implementing a 1inch Fusion-style resolver pattern:
- Pre-deployed resolver on both chains manages swaps
- No address prediction needed - escrows tracked in mappings
- Event-driven architecture for cross-chain monitoring
- Clean separation of concerns

## Architecture

```
User (Alice) → CrossChainResolverV2 → TestEscrowFactory → EscrowSrc
                    ↓
            Emits SwapInitiated
                    ↓
Resolver (Bob) monitors events
                    ↓
        Creates destination escrow
                    ↓
            CrossChainResolverV2 → TestEscrowFactory → EscrowDst
```

## Next Steps for Testing

1. Fund resolvers with BMN tokens:
   ```bash
   # Base
   cast send 0x9C32618CeeC96b9DC0b7c0976c4b4cf2Ee452988 \
     "transfer(address,uint256)" \
     0xeaee1Fd7a1Fe2BC10f83391Df456Fe841602bc77 \
     100000000000000000000 \
     --rpc-url $BASE_RPC_URL \
     --private-key $ALICE_PRIVATE_KEY
   
   # Etherlink  
   cast send 0x9C32618CeeC96b9DC0b7c0976c4b4cf2Ee452988 \
     "transfer(address,uint256)" \
     0x3bCACdBEC5DdF9Ec29da0E04a7d846845396A354 \
     100000000000000000000 \
     --rpc-url $ETHERLINK_RPC_URL \
     --private-key $BOB_PRIVATE_KEY
   ```

2. Initiate swap on Base:
   ```bash
   cast send 0xeaee1Fd7a1Fe2BC10f83391Df456Fe841602bc77 \
     "initiateSwap(bytes32,address,address,uint256,uint256,uint256)" \
     <hashlock> <taker> <token> <amount> <dstChainId> <timelocks> \
     --value 0.001ether \
     --rpc-url $BASE_RPC_URL \
     --private-key $ALICE_PRIVATE_KEY
   ```

3. Monitor SwapInitiated event and create destination escrow

## Time to Hackathon Deadline

Deployment completed with approximately 45 minutes remaining before hackathon deadline!