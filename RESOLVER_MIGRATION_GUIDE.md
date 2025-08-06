# Resolver Migration Guide: Factory v1.1.0 → v2.1.0

## Critical Update Notice

**IMMEDIATE ACTION REQUIRED**: The CrossChainEscrowFactory is being upgraded from v1.1.0 to v2.1.0 to add essential security features. All resolver operators must migrate to the new factory addresses.

## Migration Timeline

- **Deployment Date**: August 6, 2025
- **Migration Window**: 24-48 hours
- **Old Factory Deprecation**: 30 days after v2.1.0 deployment

## What's Changing

### Security Enhancements in v2.1.0

1. **Resolver Whitelist System**: Only whitelisted addresses can create destination escrows
2. **Emergency Pause Mechanism**: Protocol can be paused in case of security issues
3. **Enhanced Access Control**: Improved owner-only functions
4. **Same ABI**: No code changes required in resolver implementation

### Factory Addresses

#### Old Factory Addresses (v1.1.0) - TO BE DEPRECATED
| Network | Factory Address | Status |
|---------|----------------|--------|
| Base | `0x2B2d52Cf0080a01f457A4f64F41cbca500f787b1` | INSECURE |
| Etherlink | `0x2B2d52Cf0080a01f457A4f64F41cbca500f787b1` | INSECURE |
| Optimism | `0xB916C3edbFe574fFCBa688A6B92F72106479bD6c` | INSECURE |

#### New Factory Addresses (v2.1.0) - SECURE
| Network | Factory Address | Status |
|---------|----------------|--------|
| Base | `0xBc9A20A9FCb7571B2593e85D2533E10e3e9dC61A` | SECURE |
| Etherlink | N/A - Not deployed | N/A |
| Optimism | `0xBc9A20A9FCb7571B2593e85D2533E10e3e9dC61A` | SECURE |

*Deployed on August 6, 2025*

## Migration Steps

### Step 1: Update Configuration

Update your resolver configuration file with the new factory addresses:

```javascript
// config.json or .env
{
  "networks": {
    "base": {
      "factory": "0xBc9A20A9FCb7571B2593e85D2533E10e3e9dC61A",  // v2.1.0
      "rpc": "YOUR_BASE_RPC_URL"
    },
    "etherlink": {
      "factory": "N/A - Not deployed",  // Skip Etherlink
      "rpc": "YOUR_ETHERLINK_RPC_URL"
    },
    "optimism": {
      "factory": "0xBc9A20A9FCb7571B2593e85D2533E10e3e9dC61A",  // v2.1.0
      "rpc": "YOUR_OPTIMISM_RPC_URL"
    }
  }
}
```

### Step 2: Verify Whitelist Status

Check if your resolver address is whitelisted on the new factory:

```bash
# Using cast (Foundry)
cast call [FACTORY_ADDRESS] "whitelistedResolvers(address)(bool)" [YOUR_RESOLVER_ADDRESS] --rpc-url [RPC_URL]

# Expected output: true (if whitelisted)
```

### Step 3: Test Connection

Run a test to ensure your resolver can interact with the new factory:

```javascript
// test-connection.js
const { ethers } = require('ethers');

async function testConnection() {
    const provider = new ethers.JsonRpcProvider(RPC_URL);
    const factory = new ethers.Contract(FACTORY_ADDRESS, FACTORY_ABI, provider);
    
    // Check factory version
    const version = await factory.VERSION();
    console.log('Factory version:', version);
    // Should output: "2.1.0-bmn-secure"
    
    // Check if your resolver is whitelisted
    const isWhitelisted = await factory.whitelistedResolvers(YOUR_RESOLVER_ADDRESS);
    console.log('Resolver whitelisted:', isWhitelisted);
    // Should output: true
    
    // Check if factory is paused
    const isPaused = await factory.emergencyPaused();
    console.log('Factory paused:', isPaused);
    // Should output: false (unless emergency)
}

testConnection();
```

### Step 4: Update Monitoring

Update your monitoring and alerting systems:

1. **Add factory pause monitoring**: Alert if `emergencyPaused()` returns true
2. **Monitor whitelist status**: Alert if your resolver gets removed from whitelist
3. **Track factory events**: Monitor new events like `ResolverWhitelisted`, `EmergencyPause`

### Step 5: Complete Migration

Once testing is successful:

1. **Stop resolver on old factory**: Gracefully shut down operations on v1.1.0
2. **Start resolver on new factory**: Begin operations on v2.1.0
3. **Monitor initial operations**: Watch first few swaps closely
4. **Report issues**: Contact team immediately if any issues arise

## Important Notes

### No Code Changes Required

- The factory ABI remains the same
- Your existing resolver code will work without modifications
- Only the factory address needs to be updated

### Whitelist Requirements

- Your resolver must be whitelisted before it can create destination escrows
- Contact the protocol team if you're not whitelisted
- Whitelist status can be checked on-chain at any time

### Emergency Procedures

If the factory is paused:
1. Your resolver will receive reverts with message "Protocol is paused"
2. Stop attempting new escrow creations
3. Monitor for unpause event
4. Resume operations once unpaused

## Verification Commands

### Check Migration Status

```bash
# Check old factory (should show no recent activity after migration)
cast logs --address [OLD_FACTORY] --from-block [MIGRATION_BLOCK] --rpc-url [RPC_URL]

# Check new factory (should show your resolver's activity)
cast logs --address [NEW_FACTORY] --from-block [MIGRATION_BLOCK] --rpc-url [RPC_URL]
```

### Verify Security Features

```bash
# Check whitelist
cast call [NEW_FACTORY] "whitelistedResolvers(address)(bool)" [YOUR_ADDRESS] --rpc-url [RPC_URL]

# Check pause status
cast call [NEW_FACTORY] "emergencyPaused()(bool)" --rpc-url [RPC_URL]

# Check version
cast call [NEW_FACTORY] "VERSION()(string)" --rpc-url [RPC_URL]
```

## Troubleshooting

### Common Issues

1. **"Not whitelisted resolver" error**
   - Solution: Contact protocol team to get whitelisted
   - Verification: Run whitelist check command above

2. **"Protocol is paused" error**
   - Solution: Wait for protocol to be unpaused
   - Check status: `emergencyPaused()` function

3. **Transaction reverts without clear error**
   - Check whitelist status
   - Verify factory address is correct
   - Ensure you're using the correct chain

### Support Channels

- **Technical Issues**: Open issue at github.com/bridge-me-not/bmn-contracts
- **Urgent Issues**: Contact security team (see internal documentation)
- **General Questions**: Discord channel #resolver-support

## FAQ

**Q: Do I need to update my resolver code?**
A: No, only the factory address needs to be updated.

**Q: What happens to pending swaps on the old factory?**
A: Complete all pending swaps before migration. The old factory will remain operational for 30 days.

**Q: Can I operate on both factories simultaneously?**
A: Yes, during the migration period, but it's recommended to migrate fully as soon as possible.

**Q: What if I'm not whitelisted on the new factory?**
A: Contact the protocol team immediately. Initial resolvers from v1.1.0 should be pre-whitelisted.

**Q: How do I know if the factory is paused?**
A: Check `emergencyPaused()` returns false. Your transactions will revert with "Protocol is paused" if it's paused.

## Post-Migration Checklist

- [ ] Updated factory addresses in configuration
- [ ] Verified resolver is whitelisted
- [ ] Tested connection to new factory
- [ ] Updated monitoring systems
- [ ] Completed at least one successful swap
- [ ] Documented migration completion time
- [ ] Removed old factory configuration (after 30 days)

## Security Reminders

1. **Never share your private keys**
2. **Verify factory addresses from official sources only**
3. **Test on testnet first if available**
4. **Monitor your resolver's performance closely after migration**
5. **Keep your resolver software updated**

---

**Document Version**: 1.0
**Last Updated**: January 6, 2025
**Status**: READY FOR DEPLOYMENT

*This guide will be updated with actual deployment addresses once v2.1.0 is deployed.*