# Final Protocol Deployment

## CREATE2 Deployments (Identical on All Chains)

- **Factory**: `0xc72ed1E8a0649e51Cd046a0FfccC8f8c0bf385Fa`
- **EscrowSrc Implementation**: `0xcCF2DEd118EC06185DC99E1a42a078754ae9c84c`
- **EscrowDst Implementation**: `0xb5A9FBEB81830006A9C03aBB33d02574346C5A9a`

## BMN Token
- **Address**: `0x8287CD2aC7E227D9D927F998EB600a0683a832A1` (same on all chains)

## Architecture

1. **Factory creates escrows** - But uses `block.timestamp` causing address prediction issues
2. **TypeScript Resolver (Bob)** - Monitors events and handles actual addresses
3. **No more on-chain resolver contracts** - Pure event-driven off-chain resolution

## Next Steps

Go to `bmn-evm-resolver` project to implement the TypeScript resolver service.