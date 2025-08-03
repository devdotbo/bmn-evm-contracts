# CREATE3 Implementations Comparison

## CREATE3 Implementations Found

### 1. Project's Own Implementation
**Location**: `/contracts/libraries/Create3.sol` & `/contracts/Create3Factory.sol`
- Custom implementation based on EIP-3171 pattern
- Author: Agustin Aguilar (adapted)
- Solidity: 0.8.23

### 2. Zeframlou's CREATE3 Factory
**Location**: `/dependencies/zeframlou-create3-factory-567d6ec78cd0545f2fb18135dcb68298a5a1ef09/`
- References Solmate's CREATE3 implementation
- Author: zefram.eth
- Minimal wrapper around Solmate

### 3. 1inch's ICreate3Deployer Interface
**Location**: `/lib/limit-order-protocol/contracts/interfaces/ICreate3Deployer.sol`
- Interface only, no implementation
- Deployed instances on multiple chains
- Address: 0x65B3Db8bAeF0215A1F9B14c506D2a3078b2C84AE (mainnet)

### 4. 0xSequence CREATE3 (Referenced)
**Location**: Referenced in `/lib/solidity-utils/contracts/tests/mocks/Create3Mock.sol`
- Not included in dependencies
- Used via import `@0xsequence/create3/contracts/Create3.sol`

## Key Differences

### 1. Implementation Approach

**Project's Create3.sol**:
```solidity
// Two-step process with proxy deployment
bytes internal constant PROXY_CHILD_BYTECODE = hex"67_36_3d_3d_37_36_3d_34_f0_3d_52_60_08_60_18_f3";
bytes32 internal constant KECCAK256_PROXY_CHILD_BYTECODE = 0x21c35dbe1b344a2488cf3321d6ce542f8e9f305544ff09e4993a62319a497c1f;
```
- Uses hardcoded proxy bytecode
- Implements full CREATE3 logic internally
- Includes helper functions (codeSize, addressOf)
- Supports ETH value deployment

**Zeframlou's Factory**:
```solidity
import {CREATE3} from "solmate/utils/CREATE3.sol";
// Delegates to Solmate implementation
```
- Thin wrapper around Solmate
- Minimal code, relies on external dependency
- Namespacing via deployer address

**1inch's Interface**:
```solidity
interface ICreate3Deployer {
    function deploy(bytes32 salt, bytes calldata code) external returns (address);
    function addressOf(bytes32 salt) external view returns (address);
}
```
- Interface only for existing deployments
- Standardized across multiple chains

### 2. Salt Management

**Project's Implementation**:
- Factory adds deployer namespace: `keccak256(abi.encodePacked(msg.sender, salt))`
- Prevents collision between deployers
- Authorization system for deployment control

**Zeframlou's Implementation**:
- Same namespacing approach: `keccak256(abi.encodePacked(deployer, salt))`
- Open deployment (no authorization)

### 3. Features Comparison

| Feature | Project's Create3 | Zeframlou | 1inch Interface |
|---------|------------------|-----------|-----------------|
| Authorization | ✓ (owner-controlled) | ✗ | Unknown |
| ETH Value Support | ✓ | ✓ | Unknown |
| Deployment Tracking | ✓ (mappings) | ✗ | Unknown |
| Error Handling | Custom errors | Relies on Solmate | Unknown |
| Gas Optimization | High (1M optimizer runs) | Depends on Solmate | N/A |
| Code Size Check | ✓ | Depends on Solmate | Unknown |
| Event Emissions | ✓ | ✗ | Unknown |

### 4. Security Considerations

**Project's Implementation**:
- Authorization prevents unauthorized deployments
- Checks for existing code before deployment
- Clear error messages
- Owner-controlled access

**Zeframlou's Implementation**:
- Open to all deployers
- Security depends on Solmate's implementation
- Simpler attack surface

### 5. Gas Costs

**Project's Implementation**:
- Optimized with 1,000,000 optimizer runs
- Additional overhead for authorization checks
- Storage for deployment tracking

**Zeframlou's Implementation**:
- Minimal overhead
- Gas cost mainly from Solmate's CREATE3

## Pros/Cons of Each

### Project's Implementation

**Pros**:
- Self-contained, no external dependencies
- Authorization system for controlled access
- Comprehensive deployment tracking
- Well-documented and tested
- Supports ETH value transfers
- Custom error handling

**Cons**:
- Larger code footprint
- More complex than necessary for simple use cases
- Additional gas for authorization and tracking

### Zeframlou's Implementation

**Pros**:
- Minimal code to audit
- Battle-tested Solmate dependency
- Simple and straightforward
- Lower deployment cost

**Cons**:
- External dependency on Solmate
- No built-in access control
- No deployment tracking
- Less feature-rich

### 1inch Interface

**Pros**:
- Already deployed on multiple chains
- Standardized addresses
- No deployment needed

**Cons**:
- No control over implementation
- Cannot modify or upgrade
- Must trust 1inch's deployment

## Recommendation for Which to Use

### For the Bridge-Me-Not Protocol: **Use Project's Implementation**

**Reasoning**:

1. **Security Requirements**: The protocol handles cross-chain swaps and requires controlled deployment of escrow contracts. The authorization system prevents malicious actors from deploying fake escrows.

2. **No External Dependencies**: Given the protocol's security-critical nature, avoiding external dependencies reduces attack surface and audit complexity.

3. **Deployment Tracking**: The built-in deployment tracking helps monitor and verify escrow deployments across chains.

4. **Already Integrated**: The Create3Factory is already built and tested within the project ecosystem.

5. **Consistent with Project Standards**: Uses same Solidity version (0.8.23) and coding standards as rest of the protocol.

### Alternative Considerations:

- **For Testing/Development**: Could use 1inch's deployed CREATE3 to save gas on testnets
- **For Other Projects**: Zeframlou's implementation is excellent for simpler use cases without authorization needs
- **For Maximum Compatibility**: Using 1inch's deployed contracts ensures same addresses as other protocols

### Migration Path (if needed):

If switching implementations later:
1. Deploy new factory with different salt namespace
2. Update deployment scripts to use new factory
3. Maintain backward compatibility for existing deployments
4. Document address calculation differences