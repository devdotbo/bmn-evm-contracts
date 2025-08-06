# Resolver Whitelist Guide

## Overview

The CrossChainEscrowFactory v2.1.0 implements a **resolver whitelist** as a critical security feature. Only whitelisted addresses can act as resolvers and execute atomic swaps in the Bridge-Me-Not protocol.

## Why Whitelisting?

The whitelist mechanism provides:
- **Security**: Prevents malicious actors from creating invalid escrows
- **Quality Control**: Ensures only trusted resolvers participate
- **Emergency Control**: Ability to revoke access if a resolver is compromised
- **Compliance**: Supports regulatory requirements for known participants

## Architecture

### Contract Implementation

The whitelist is implemented in `CrossChainEscrowFactory.sol`:

```solidity
// Storage
mapping(address => bool) public whitelistedResolvers;
uint256 public resolverCount;

// Events
event ResolverWhitelisted(address indexed resolver);
event ResolverRemoved(address indexed resolver);

// Modifiers
modifier onlyWhitelistedResolver() {
    require(whitelistedResolvers[msg.sender], "Not whitelisted resolver");
    _;
}
```

### Key Functions

- `addResolverToWhitelist(address)` - Add a resolver (owner only)
- `removeResolverFromWhitelist(address)` - Remove a resolver (owner only)
- `whitelistedResolvers(address)` - Check if address is whitelisted
- `resolverCount()` - Get total number of whitelisted resolvers

## Deployment Addresses

### Production (v2.1.0)
- **Base & Optimism Factory**: `0xBc9A20A9FCb7571B2593e85D2533E10e3e9dC61A`
- **Initial Resolver (Bob)**: `0xfdF1dDeB176BEA06c7430166e67E615bC312b7B5`
- **Factory Owner**: `0x5f29827e25dc174a6A51C99e6811Bbd7581285b0`

### Local Development
- **Factory addresses vary** (check deployment output)
- **Test Resolver (Bob)**: `0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC`
- **Deployer/Owner**: `0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266`

## Management Scripts

### 1. Add Resolver (Production)

```bash
# Set environment variables
export FACTORY_V2_ADDRESS=0xBc9A20A9FCb7571B2593e85D2533E10e3e9dC61A
export ACTION=add-resolver
export RESOLVER_ADDRESS=0xYourResolverAddress
export DEPLOYER_PRIVATE_KEY=0xYourPrivateKey

# Add to Base
source .env && forge script script/ManageFactoryV2.s.sol \
    --rpc-url $BASE_RPC_URL \
    --broadcast

# Add to Optimism
source .env && forge script script/ManageFactoryV2.s.sol \
    --rpc-url $OPTIMISM_RPC_URL \
    --broadcast
```

### 2. Remove Resolver

```bash
export ACTION=remove-resolver
export RESOLVER_ADDRESS=0xResolverToRemove

source .env && forge script script/ManageFactoryV2.s.sol \
    --rpc-url $BASE_RPC_URL \
    --broadcast
```

### 3. Check Whitelist Status

```bash
export ACTION=list-resolvers

source .env && forge script script/ManageFactoryV2.s.sol \
    --rpc-url $BASE_RPC_URL
```

### 4. Local Deployment with Whitelist

```bash
# Deploy factory v2.1.0 locally with Bob whitelisted
./scripts/deploy-local-v2.sh

# This automatically:
# - Deploys factory on both local chains
# - Whitelists Bob (0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC)
# - Whitelists Deployer for testing flexibility
# - Mints BMN tokens for access control
```

## Command Line Operations

### Check if Address is Whitelisted

```bash
# Check on Base
cast call 0xBc9A20A9FCb7571B2593e85D2533E10e3e9dC61A \
    "whitelistedResolvers(address)(bool)" \
    0xYourResolverAddress \
    --rpc-url https://base.rpc.thirdweb.com

# Check on local chain
cast call $FACTORY_ADDRESS \
    "whitelistedResolvers(address)(bool)" \
    0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC \
    --rpc-url http://localhost:8545
```

### Get Resolver Count

```bash
cast call $FACTORY_ADDRESS \
    "resolverCount()(uint256)" \
    --rpc-url $RPC_URL
```

### Add Resolver (Direct Transaction)

```bash
# Only works if you're the owner
cast send $FACTORY_ADDRESS \
    "addResolverToWhitelist(address)" \
    0xNewResolverAddress \
    --private-key $OWNER_PRIVATE_KEY \
    --rpc-url $RPC_URL
```

## Whitelist Events

Monitor whitelist changes through events:

```bash
# Watch for new whitelisted resolvers
cast logs --address $FACTORY_ADDRESS \
    --from-block latest \
    "ResolverWhitelisted(address)" \
    --rpc-url $RPC_URL

# Watch for removed resolvers
cast logs --address $FACTORY_ADDRESS \
    --from-block latest \
    "ResolverRemoved(address)" \
    --rpc-url $RPC_URL
```

## Integration Guide

### For Resolver Developers

1. **Request Whitelisting**: Contact the factory owner with:
   - Your resolver address
   - Proof of BMN token holdings
   - Description of your resolver implementation
   - Security audit (if available)

2. **Verify Whitelisting**: Before starting operations:
   ```javascript
   const isWhitelisted = await factory.whitelistedResolvers(myAddress);
   if (!isWhitelisted) {
       throw new Error("Not whitelisted - contact factory owner");
   }
   ```

3. **Handle Revocation**: Implement graceful shutdown:
   ```javascript
   // Monitor for removal
   factory.on("ResolverRemoved", (resolver) => {
       if (resolver === myAddress) {
           console.log("Whitelist revoked - stopping operations");
           gracefulShutdown();
       }
   });
   ```

### For Factory Owners

1. **Initial Setup**: Deploy with owner as initial resolver:
   ```solidity
   constructor(...) {
       whitelistedResolvers[msg.sender] = true;
       resolverCount = 1;
   }
   ```

2. **Vetting Process**: Before whitelisting:
   - Verify resolver has sufficient BMN tokens
   - Check resolver's track record (if any)
   - Review resolver implementation
   - Set up monitoring for resolver behavior

3. **Emergency Response**: If resolver misbehaves:
   ```bash
   # Immediately remove from whitelist
   export ACTION=remove-resolver
   export RESOLVER_ADDRESS=0xBadResolver
   
   # Remove from all chains
   for CHAIN in BASE OPTIMISM; do
       forge script script/ManageFactoryV2.s.sol \
           --rpc-url ${CHAIN}_RPC_URL \
           --broadcast
   done
   
   # Optional: Pause factory if critical
   export ACTION=pause
   forge script script/ManageFactoryV2.s.sol --broadcast
   ```

## Security Considerations

### Access Control
- Only factory owner can modify whitelist
- Owner address should use multisig or hardware wallet
- Consider timelock for whitelist changes in production

### Monitoring
- Set up alerts for whitelist changes
- Monitor resolver behavior (success rate, volume)
- Track BMN token holdings of resolvers

### Best Practices
1. **Start Conservative**: Begin with few trusted resolvers
2. **Gradual Expansion**: Add new resolvers incrementally
3. **Regular Audits**: Review resolver activity periodically
4. **Emergency Plan**: Have process for quick revocation
5. **Backup Resolvers**: Maintain multiple active resolvers

## Troubleshooting

### Common Issues

#### "Not whitelisted resolver" Error
```bash
# Check if address is whitelisted
cast call $FACTORY_ADDRESS \
    "whitelistedResolvers(address)(bool)" \
    $YOUR_ADDRESS \
    --rpc-url $RPC_URL

# If false, request whitelisting from owner
```

#### "Already whitelisted" Error
```bash
# Resolver is already in whitelist
# Check current status
export ACTION=list-resolvers
forge script script/ManageFactoryV2.s.sol
```

#### Transaction Reverts When Creating Escrow
```bash
# Ensure:
# 1. Caller is whitelisted
# 2. Factory is not paused
# 3. Sufficient BMN tokens for access

cast call $FACTORY_ADDRESS "emergencyPaused()(bool)" --rpc-url $RPC_URL
cast call $FACTORY_ADDRESS "whitelistedResolvers(address)(bool)" $YOUR_ADDRESS --rpc-url $RPC_URL
```

### Debug Commands

```bash
# Get factory state
cast call $FACTORY_ADDRESS "owner()(address)" --rpc-url $RPC_URL
cast call $FACTORY_ADDRESS "resolverCount()(uint256)" --rpc-url $RPC_URL
cast call $FACTORY_ADDRESS "emergencyPaused()(bool)" --rpc-url $RPC_URL

# Check specific resolver
RESOLVER=0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC
cast call $FACTORY_ADDRESS "whitelistedResolvers(address)(bool)" $RESOLVER --rpc-url $RPC_URL

# Get BMN token balance
cast call $BMN_TOKEN "balanceOf(address)(uint256)" $RESOLVER --rpc-url $RPC_URL
```

## Migration from v1.1.0 to v2.1.0

The v2.1.0 factory introduces whitelisting as a breaking change:

### Key Differences
- **v1.1.0**: Any address with BMN tokens could be resolver
- **v2.1.0**: Only whitelisted addresses can be resolvers

### Migration Steps
1. Deploy new v2.1.0 factory
2. Whitelist existing trusted resolvers
3. Update resolver code to check whitelist status
4. Gradually transition volume to new factory
5. Deprecate old factory once migration complete

### Backward Compatibility
- v2.1.0 escrows are compatible with v1.1.0 escrows
- Same deterministic addressing scheme
- Same timelock and secret mechanisms
- Only difference is resolver access control

## Appendix

### Contract Addresses Summary

| Network | Factory v2.1.0 | Initial Resolver | Owner |
|---------|---------------|------------------|--------|
| Base | 0xBc9A20A9FCb7571B2593e85D2533E10e3e9dC61A | 0xfdF1dDeB176BEA06c7430166e67E615bC312b7B5 | 0x5f29827e25dc174a6A51C99e6811Bbd7581285b0 |
| Optimism | 0xBc9A20A9FCb7571B2593e85D2533E10e3e9dC61A | 0xfdF1dDeB176BEA06c7430166e67E615bC312b7B5 | 0x5f29827e25dc174a6A51C99e6811Bbd7581285b0 |
| Local A | Variable (check deployment) | 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC | 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 |
| Local B | Variable (check deployment) | 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC | 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 |

### Related Documentation
- [Security Features](./SECURITY.md)
- [Factory Management](./FACTORY-MANAGEMENT.md)
- [Deployment Guide](./DEPLOYMENT.md)
- [Emergency Procedures](./EMERGENCY.md)