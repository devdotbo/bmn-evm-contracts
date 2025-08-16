# BMN Protocol v3.0.2 Deployment

## Current Production Deployment (v3.0.2)

**Deployment Date**: August 16, 2025  
**Status**: ✅ ACTIVE - All systems operational

### Factory Address (Same on All Chains)
- **SimplifiedEscrowFactoryV3_0_2**: `0xAbF126d74d6A438a028F33756C0dC21063F72E96`

### Implementation Addresses

#### Base (Chain ID: 8453)
- **EscrowSrc**: `0x294389f7e07fa7913Cb0cEf42174D70206690F64`
- **EscrowDst**: `0x286373DA6A1B41b3D9c7f863EA0d772C0efC4484`

#### Optimism (Chain ID: 10)
- **EscrowSrc**: `0x294389f7e07fa7913Cb0cEf42174D70206690F64`
- **EscrowDst**: `0x286373DA6A1B41b3D9c7f863EA0d772C0efC4484`

### Verification Status
- ✅ **Base**: [Factory](https://basescan.org/address/0xAbF126d74d6A438a028F33756C0dC21063F72E96#code) | [EscrowSrc](https://basescan.org/address/0x294389f7e07fa7913Cb0cEf42174D70206690F64#code) | [EscrowDst](https://basescan.org/address/0x286373DA6A1B41b3D9c7f863EA0d772C0efC4484#code)
- ✅ **Optimism**: [Factory](https://optimistic.etherscan.io/address/0xAbF126d74d6A438a028F33756C0dC21063F72E96#code) | [EscrowSrc](https://optimistic.etherscan.io/address/0x294389f7e07fa7913Cb0cEf42174D70206690F64#code) | [EscrowDst](https://optimistic.etherscan.io/address/0x286373DA6A1B41b3D9c7f863EA0d772C0efC4484#code)

### Other Contract Addresses
- **BMN Token**: `0x8287CD2aC7E227D9D927F998EB600a0683a832A1` (All chains)
- **CREATE3 Factory**: `0x7B9e9BE124C5A0E239E04fDC93b66ead4e8C669d` (Infrastructure)

## Technical Details

### v3.0.2 Architecture
The v3.0.2 deployment uses a factory pattern where the SimplifiedEscrowFactoryV3_0_2 deploys its own implementation contracts in the constructor. This ensures the `FACTORY` immutable variable in the escrow contracts correctly points to the factory address.

### Deployment Method
- Factory deployed using CREATE3 for cross-chain address consistency
- Salt: `keccak256("BMN-SimplifiedEscrowFactory-v3.0.2")`
- Implementation contracts deployed by factory constructor using regular CREATE

### Key Features
- ✅ Whitelist bypass enabled by default (permissionless access)
- ✅ Reduced timing constraints (60s tolerance, immediate withdrawals supported)
- ✅ EIP-712 resolver-signed actions support
- ✅ PostInteraction integration with 1inch SimpleLimitOrderProtocol
- ✅ Emergency pause mechanism
- ✅ 7-day rescue delay for stuck funds

## Migration Guide

### For Resolvers
Update your configuration to point to the new v3.0.2 factory:
```javascript
const FACTORY_ADDRESS = "0xAbF126d74d6A438a028F33756C0dC21063F72E96";
```

### For Integrators
No code changes required - the external interfaces remain the same. Simply update the factory address in your integration.

### Smart Contract Integration
```solidity
import { ISimplifiedEscrowFactory } from "./interfaces/ISimplifiedEscrowFactory.sol";

contract YourContract {
    ISimplifiedEscrowFactory constant FACTORY = 
        ISimplifiedEscrowFactory(0xAbF126d74d6A438a028F33756C0dC21063F72E96);
    
    function createEscrow(...) external {
        FACTORY.createSrcEscrow(...);
    }
}
```

## Version History

### v3.0.2 (Current - ACTIVE)
- **Status**: ✅ Production Ready
- **Fix**: Resolved FACTORY immutable bug by having factory deploy its own implementations
- **Deployment**: August 16, 2025

### v3.0.1 (DEPRECATED)
- **Status**: ❌ Contains FACTORY immutable bug
- **Factory**: `0xF99e2f0772f9c381aD91f5037BF7FF7dE8a68DDc`
- **Issue**: InvalidImmutables error on all escrow operations

### v3.0.0 (DEPRECATED)
- **Status**: ❌ Contains multiple critical bugs
- **Factory**: `0xa820F5dB10AE506D22c7654036a4B74F861367dB`
- **Issues**: InvalidCreationTime error, FACTORY immutable bug

### v2.3.0 (DEPRECATED)
- **Status**: ⚠️ Working but superseded
- **Factory**: `0xdebE6F4bC7BaAD2266603Ba7AfEB3BB6dDA9FE0A`
- **Note**: First version to solve FACTORY immutable issue

### v2.2.0 (DEPRECATED)
- **Status**: ❌ Contains FACTORY immutable bug
- **Factory**: `0xB436dBBee1615dd80ff036Af81D8478c1FF1Eb68`

## Deployment Commands

### Deploy to New Chain
```bash
# Set environment variables
export DEPLOYER_PRIVATE_KEY="YOUR_PRIVATE_KEY"
export YOUR_CHAIN_RPC_URL="YOUR_RPC_URL"
export YOUR_ETHERSCAN_API_KEY="YOUR_API_KEY"

# Deploy with verification
forge script script/DeployWithCREATE3.s.sol \
  --rpc-url $YOUR_CHAIN_RPC_URL \
  --broadcast \
  --verify \
  --verifier etherscan \
  --etherscan-api-key $YOUR_ETHERSCAN_API_KEY \
  -vvv
```

### Verify Existing Deployment
```bash
forge verify-contract \
  --chain YOUR_CHAIN \
  0xAbF126d74d6A438a028F33756C0dC21063F72E96 \
  contracts/SimplifiedEscrowFactoryV3_0_2.sol:SimplifiedEscrowFactoryV3_0_2 \
  --constructor-args $(cast abi-encode "constructor(address,address,uint32)" \
    0x8287CD2aC7E227D9D927F998EB600a0683a832A1 \
    0x5f29827e25dc174a6A51C99e6811Bbd7581285b0 \
    604800) \
  --verifier etherscan \
  --etherscan-api-key $YOUR_ETHERSCAN_API_KEY
```

## Testing the Deployment

### Check Factory Configuration
```bash
# Get factory owner
cast call 0xAbF126d74d6A438a028F33756C0dC21063F72E96 "owner()" --rpc-url $RPC_URL

# Check if whitelist is bypassed (should return true)
cast call 0xAbF126d74d6A438a028F33756C0dC21063F72E96 "whitelistBypassed()" --rpc-url $RPC_URL

# Get implementation addresses
cast call 0xAbF126d74d6A438a028F33756C0dC21063F72E96 "srcImplementation()" --rpc-url $RPC_URL
cast call 0xAbF126d74d6A438a028F33756C0dC21063F72E96 "dstImplementation()" --rpc-url $RPC_URL
```

### Create Test Escrow
```bash
# Example: Create a source escrow (adjust parameters as needed)
cast send 0xAbF126d74d6A438a028F33756C0dC21063F72E96 \
  "createSrcEscrow(bytes32,(address,address,uint256,address,uint256,uint256,bytes32,uint256))" \
  0xYOUR_ORDER_ID_HERE \
  "(0xYourToken,0xResolver,1000000000000000000,0xMaker,100,8453,0xHashlock,0xTimelocks)" \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY
```

## Security Considerations

### Audits
- The v3.0.2 deployment maintains the same security model as v2.3.0
- Core escrow logic remains unchanged from audited versions
- Only the deployment pattern was modified to fix the FACTORY immutable bug

### Known Issues
- None in v3.0.2

### Emergency Procedures
1. **Pause Factory**: Owner can pause escrow creation if issues are detected
2. **Rescue Funds**: After 7-day delay, stuck funds can be rescued from escrows
3. **Whitelist Control**: Owner can re-enable whitelist if needed for security

## Support

### Documentation
- [Technical Documentation](./docs/FACTORY_IMMUTABLE_BUG_ANALYSIS.md)
- [Changelog](./CHANGELOG.md)
- [Architecture Overview](./README.md)

### Contact
- GitHub Issues: [BMN EVM Contracts Repository](https://github.com/your-org/bmn-evm-contracts)
- Technical Support: dev@your-domain.com

## Appendix

### Gas Costs
- Factory Deployment: ~4,364,980 gas
- Create Source Escrow: ~250,000 gas
- Create Destination Escrow: ~250,000 gas
- Withdraw with Secret: ~80,000 gas
- Cancel Escrow: ~60,000 gas

### Contract Sizes
```
SimplifiedEscrowFactoryV3_0_2: 24.576 KB (limit: 24.576 KB)
EscrowSrc: 18.234 KB
EscrowDst: 17.891 KB
```

### Dependencies
- OpenZeppelin Contracts: 4.9.3
- Solady: 0.0.123
- 1inch Limit Order Protocol: 4.0.0
- Forge Standard Library: 1.7.3