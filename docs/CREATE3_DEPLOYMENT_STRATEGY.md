# CREATE3 Deployment Strategy for BMN Token

## Executive Summary

This document outlines the CREATE3 deployment strategy for achieving deterministic cross-chain BMN token addresses on Base (8453) and Etherlink (42793) mainnets.

## CREATE3 vs CREATE2: Technical Analysis

### CREATE2 Limitations
- **Address Dependency**: CREATE2 addresses depend on:
  - Deployer address
  - Salt
  - **Contract bytecode** (including constructor args)
- **Cross-chain Challenge**: Different constructor parameters or compiler versions result in different addresses
- **Nonce Independence**: While CREATE2 is nonce-independent, bytecode changes break determinism

### CREATE3 Advantages
- **Bytecode Independence**: Addresses depend only on:
  - Deployer address
  - Salt
- **True Cross-chain Determinism**: Same address regardless of:
  - Constructor parameters
  - Compiler version
  - Contract modifications
- **Upgrade Flexibility**: Can deploy different implementations to same address

### How CREATE3 Works

```
1. CREATE2 deploys a minimal proxy contract
   - Proxy address = f(deployer, salt, PROXY_BYTECODE)
   - PROXY_BYTECODE is constant across all deployments

2. Proxy uses CREATE to deploy actual contract
   - Final address = f(proxy_address, nonce=1)
   - Since proxy is deterministic, final address is deterministic
```

## Architecture Design

### Contract Structure

```
┌─────────────────────┐
│  Create3Factory     │  <- Deployed via CREATE2 (same address on all chains)
├─────────────────────┤
│ - deploy()          │
│ - getDeploymentAddr │
│ - authorization     │
└──────────┬──────────┘
           │
           │ Uses
           ▼
┌─────────────────────┐
│  Create3 Library    │  <- Core CREATE3 implementation
├─────────────────────┤
│ - create3()         │
│ - addressOf()       │
│ - Proxy deployment  │
└─────────────────────┘
           │
           │ Deploys
           ▼
┌─────────────────────┐
│  BMNAccessTokenV2   │  <- Final token contract
├─────────────────────┤
│ - ERC20 token       │
│ - Access control    │
│ - Same addr X-chain │
└─────────────────────┘
```

### Deployment Flow

1. **Phase 1: Factory Deployment**
   ```solidity
   // Deploy CREATE3 factory using CREATE2
   address factory = CREATE2.deploy(FACTORY_SALT, factoryBytecode);
   // Same factory address on all chains
   ```

2. **Phase 2: Token Deployment**
   ```solidity
   // Deploy BMN token using CREATE3
   address bmn = factory.deploy(BMN_SALT, tokenBytecode);
   // Same token address on all chains
   ```

## Gas Analysis

### CREATE3 Gas Costs

| Operation | Gas Cost | Notes |
|-----------|----------|-------|
| CREATE2 Proxy Deployment | ~55,000 | One-time proxy creation |
| CREATE Final Deployment | ~Variable | Depends on contract size |
| BMN Token Deployment | ~2,500,000 | Full ERC20 + access control |
| Total CREATE3 Overhead | ~55,000 | Additional cost vs direct deployment |

### Cost Comparison

```
Direct Deployment:     ~2,500,000 gas
CREATE2 Deployment:    ~2,500,000 gas
CREATE3 Deployment:    ~2,555,000 gas (2.2% overhead)
```

The 55k gas overhead is negligible compared to the benefits of deterministic cross-chain addresses.

## Deployment Scripts

### 1. Factory Deployment Script
- **File**: `DeployCreate3Factory.s.sol`
- **Purpose**: Deploy CREATE3 factory at deterministic address
- **Method**: Uses CREATE2 with known factory (0x4e59b44847b379578588920cA78FbF26c0B4956C)

### 2. Token Deployment Script
- **File**: `DeployBMNWithCreate3.s.sol`
- **Purpose**: Deploy BMN token using CREATE3
- **Features**:
  - Calculates deterministic addresses
  - Handles multi-chain deployment
  - Includes verification steps

## Verification Strategy

### On-chain Verification

1. **Address Verification**
   ```solidity
   // Pre-calculate expected address
   address expected = factory.getDeploymentAddress(deployer, salt);
   
   // Deploy
   address actual = factory.deploy(salt, bytecode);
   
   // Verify
   require(actual == expected, "Address mismatch");
   ```

2. **Cross-chain Consistency**
   ```bash
   # Script verifies same address on all chains
   forge script VerifyCreate3Deployment --multi
   ```

### Block Explorer Verification

For each chain:
1. Verify factory deployment transaction
2. Verify token deployment transaction
3. Confirm addresses match across chains
4. Verify source code on explorers

## Error Handling

### Deployment Errors

| Error | Cause | Solution |
|-------|-------|----------|
| `TargetAlreadyExists` | Address already has code | Use different salt |
| `ErrorCreatingProxy` | CREATE2 failed | Check factory deployment |
| `ErrorCreatingContract` | CREATE failed | Check bytecode/constructor |
| `Unauthorized` | Deployer not authorized | Authorize via factory owner |

### Recovery Procedures

1. **Failed Deployment**
   - Use new salt for fresh address
   - Or wait for all chains to fail, then retry

2. **Partial Deployment**
   - Continue deployment on remaining chains
   - Addresses remain deterministic

## Security Considerations

1. **Factory Authorization**
   - Only authorized addresses can deploy
   - Prevents griefing attacks
   - Owner can add/remove deployers

2. **Salt Management**
   - Use descriptive, unique salts
   - Include version in salt for upgrades
   - Document all used salts

3. **Deployment Verification**
   - Always verify addresses before use
   - Check bytecode on all chains
   - Confirm ownership and parameters

## Integration with Cross-chain Infrastructure

### Benefits for Bridge-Me-Not

1. **Simplified Escrow Logic**
   - No need for token address mapping
   - Same BMN address on all chains
   - Reduces configuration complexity

2. **Enhanced Security**
   - Eliminates address confusion
   - Prevents wrong-token errors
   - Simplifies verification

3. **Future Expansion**
   - Easy to add new chains
   - Deterministic addresses guaranteed
   - No protocol changes needed

### Configuration Updates

```solidity
// Before: Chain-specific addresses
mapping(uint256 => address) chainToToken;

// After: Single address for all chains
address constant BMN_TOKEN = 0x...; // Same everywhere
```

## Deployment Checklist

### Pre-deployment
- [ ] Set up RPC endpoints for all chains
- [ ] Fund deployer address on all chains
- [ ] Verify CREATE2 factory exists (0x4e59b44847b379578588920cA78FbF26c0B4956C)
- [ ] Review and test deployment scripts

### Factory Deployment
- [ ] Deploy CREATE3 factory on Base
- [ ] Deploy CREATE3 factory on Etherlink
- [ ] Verify factory addresses match
- [ ] Authorize token deployers

### Token Deployment
- [ ] Calculate expected token address
- [ ] Deploy BMN token on Base
- [ ] Deploy BMN token on Etherlink
- [ ] Verify token addresses match
- [ ] Set up initial token configuration

### Post-deployment
- [ ] Verify contracts on block explorers
- [ ] Update protocol configuration
- [ ] Test cross-chain functionality
- [ ] Document final addresses

## Cost Estimation

### Total Deployment Costs

| Component | Base (ETH) | Etherlink (XTZ) |
|-----------|------------|-----------------|
| Factory Deployment | 0.002 ETH | 0.5 XTZ |
| Token Deployment | 0.008 ETH | 2.0 XTZ |
| Verification | 0.001 ETH | 0.2 XTZ |
| **Total per Chain** | **0.011 ETH** | **2.7 XTZ** |

*Estimates based on 30 gwei gas price and current XTZ rates*

## Conclusion

CREATE3 provides the optimal solution for deterministic cross-chain token deployment:
- **2.2% gas overhead** is negligible
- **Guaranteed same addresses** across all chains
- **Future-proof** for protocol expansion
- **Simplified configuration** and reduced errors

The implementation provides a robust, secure, and maintainable approach to cross-chain token deployment for the Bridge-Me-Not protocol.