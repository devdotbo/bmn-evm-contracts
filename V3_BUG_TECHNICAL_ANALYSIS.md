# Technical Deep Dive: v3.0.0 InvalidImmutables Bug

## Address Calculation Breakdown

### How CREATE2 Works
```
address = keccak256(0xff ++ deployer ++ salt ++ keccak256(bytecode))[12:]
```

### Current (Broken) Flow

#### 1. Implementation Deployment
```solidity
// DeployMainnet.s.sol deploys via CREATE3
CREATE3_FACTORY.deploy(salt, EscrowDst.creationCode)
// Result: msg.sender in constructor = 0x93FEC2C00BfE902F733B57c5a6CeeD7CD1384AE1
// Therefore: FACTORY = 0x93FEC2C00BfE902F733B57c5a6CeeD7CD1384AE1 ❌
```

#### 2. Proxy Creation
```solidity
// SimplifiedEscrowFactory.sol creates proxy
escrow = ESCROW_DST_IMPLEMENTATION.cloneDeterministic(salt);
// Actual deployer = 0xa820F5dB10AE506D22c7654036a4B74F861367dB ✅
```

#### 3. Validation (FAILS)
```solidity
// Escrow.sol validation
bytes32 salt = immutables.hash();
address expected = Create2.computeAddress(
    salt, 
    PROXY_BYTECODE_HASH,  
    FACTORY  // Wrong! Uses CREATE3 factory instead of SimplifiedEscrowFactory
);
if (expected != address(this)) revert InvalidImmutables();
```

## Detailed CREATE2 Calculation

### What Should Happen
```
Deployer: 0xa820F5dB10AE506D22c7654036a4B74F861367dB (SimplifiedEscrowFactory)
Salt: keccak256(immutables) = 0x3059d409...
Bytecode Hash: 0xb834e10c9fd6c0b94e8c1f93bcb88965be7d12cd1ad09a1f08bc7fbd292a73c5

Expected Address = keccak256(
    0xff ++
    0xa820F5dB10AE506D22c7654036a4B74F861367dB ++  // SimplifiedEscrowFactory
    0x3059d409... ++                                 // salt
    0xb834e10c...                                    // proxy bytecode hash
)[12:]
```

### What Actually Happens
```
Deployer: 0x93FEC2C00BfE902F733B57c5a6CeeD7CD1384AE1 (CREATE3 Factory) ❌
Salt: keccak256(immutables) = 0x3059d409...
Bytecode Hash: 0xb834e10c9fd6c0b94e8c1f93bcb88965be7d12cd1ad09a1f08bc7fbd292a73c5

Computed Address = keccak256(
    0xff ++
    0x93FEC2C00BfE902F733B57c5a6CeeD7CD1384AE1 ++  // Wrong factory! ❌
    0x3059d409... ++                                 // salt
    0xb834e10c...                                    // proxy bytecode hash
)[12:]

Result: Computed address ≠ Actual proxy address → InvalidImmutables()
```

## Proxy Bytecode Analysis

### OpenZeppelin Clones Pattern
```
3d602d80600a3d3981f3363d3d373d3d3d363d73
<20-byte implementation address>
5af43d82803e903d91602b57fd5bf3
```

Total: 45 bytes

### ProxyHashLib Calculation
```solidity
function computeProxyBytecodeHash(address implementation) {
    // Constructs the same bytecode pattern
    // Returns: keccak256(bytecode)
}
```

The proxy bytecode calculation is **correct**. The issue is purely the FACTORY address.

## Memory Layout During Validation

### Immutables Struct (256 bytes)
```
0x00: orderHash      (32 bytes)
0x20: hashlock       (32 bytes)
0x40: maker          (32 bytes) - uint256 wrapped address
0x60: taker          (32 bytes) - uint256 wrapped address
0x80: token          (32 bytes) - uint256 wrapped address
0xA0: amount         (32 bytes)
0xC0: safetyDeposit  (32 bytes)
0xE0: timelocks      (32 bytes)
```

### Salt Calculation
```solidity
salt = keccak256(immutables) // Hash all 256 bytes
```

## Factory Address Mismatch

### Current State
```
Implementation's FACTORY: 0x93FEC2C00BfE902F733B57c5a6CeeD7CD1384AE1
Actual Factory:          0xa820F5dB10AE506D22c7654036a4B74F861367dB
```

### Why It Happens
1. CREATE3 uses intermediate proxy contracts
2. The final `msg.sender` is CREATE3's proxy, not the original caller
3. BaseEscrow assumes direct deployment by SimplifiedEscrowFactory

## Fix Implementation Details

### Option 1: Constructor Parameter
```solidity
// BaseEscrow.sol
constructor(uint32 rescueDelay, IERC20 accessToken, address _factory) {
    RESCUE_DELAY = rescueDelay;
    _ACCESS_TOKEN = accessToken;
    FACTORY = _factory;  // Explicitly set
}
```

### Option 2: Compute Factory Address
```solidity
// Use CREATE3 to predict factory address
address public immutable FACTORY = ICREATE3(0x93FEC2C00BfE902F733B57c5a6CeeD7CD1384AE1)
    .getDeployed(DEPLOYER, FACTORY_SALT);
```

### Option 3: Factory Registry Pattern
```solidity
// Global registry contract
interface IFactoryRegistry {
    function getFactory() external view returns (address);
}

// In BaseEscrow
address public immutable FACTORY = IFactoryRegistry(REGISTRY).getFactory();
```

## Verification Steps

### 1. Check Current FACTORY Value
```bash
cast call 0x334787690D3112a4eCB10ACAa1013c12A3893E74 "FACTORY()" \
  --rpc-url optimism
# Returns: 0x93FEC2C00BfE902F733B57c5a6CeeD7CD1384AE1 ❌
```

### 2. Check Expected Factory
```bash
# SimplifiedEscrowFactory address
echo "0xa820F5dB10AE506D22c7654036a4B74F861367dB"
```

### 3. Test Fix
```solidity
// Deploy new implementation with correct factory
EscrowDst impl = new EscrowDst(
    RESCUE_DELAY, 
    BMN_TOKEN, 
    0xa820F5dB10AE506D22c7654036a4B74F861367dB  // Correct factory
);

// Verify
assert(impl.FACTORY() == 0xa820F5dB10AE506D22c7654036a4B74F861367dB);
```

## Gas Impact of Fix

The fix has minimal gas impact:
- Constructor: +1 SLOAD to read parameter (~100 gas)
- No runtime impact (FACTORY is immutable)
- No proxy size change

## Lessons Learned

1. **Test Full Flow**: Always test complete atomic swap including withdrawal
2. **Verify Immutables**: Check all immutable values post-deployment
3. **CREATE3 Gotchas**: Be aware of intermediate proxy effects on `msg.sender`
4. **Integration Tests**: Unit tests missed this because they deploy directly

## Recommended Testing

```solidity
contract V3IntegrationTest {
    function test_FullAtomicSwap() {
        // 1. Create order
        // 2. Fill order
        // 3. Create dst escrow
        // 4. Wait for timelock
        // 5. Withdraw ← This fails in v3.0.0
        // 6. Verify funds transferred
    }
    
    function test_FactoryAddressCorrect() {
        assertEq(
            escrowImpl.FACTORY(), 
            address(simplifiedFactory),
            "FACTORY mismatch"
        );
    }
}
```

---

*Technical analysis for BMN Protocol v3.0.0 bug*
*Prepared: 2025-08-15*