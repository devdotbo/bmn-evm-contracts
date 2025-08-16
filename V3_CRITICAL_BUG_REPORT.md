# 🚨 CRITICAL BUG: v3.0.0 InvalidImmutables Error

## Executive Summary
The v3.0.0 BMN protocol contracts have a **critical bug** that makes all atomic swaps fail during withdrawal with `InvalidImmutables()` error. The bug is in `BaseEscrow.sol` where the `FACTORY` immutable is incorrectly set to `msg.sender` during deployment via CREATE3.

**Impact**: All v3.0.0 atomic swaps are broken and funds cannot be withdrawn.

## Bug Details

### Root Cause
In `contracts/BaseEscrow.sol:33`:
```solidity
address public immutable FACTORY = msg.sender;
```

This assumes the factory deploys the implementation directly, but in v3.0.0:
1. Implementation contracts are deployed via **CREATE3 factory** (`0x93FEC2C00BfE902F733B57c5a6CeeD7CD1384AE1`)
2. Escrow proxies are created by **SimplifiedEscrowFactory** (`0xa820F5dB10AE506D22c7654036a4B74F861367dB`)
3. The `FACTORY` immutable gets set to CREATE3 factory instead of SimplifiedEscrowFactory
4. When validating immutables, the wrong factory address is used in CREATE2 calculation

### Validation Flow
In `contracts/Escrow.sol:28-33`:
```solidity
function _validateImmutables(Immutables calldata immutables) internal view virtual override {
    bytes32 salt = immutables.hash();
    if (Create2.computeAddress(salt, PROXY_BYTECODE_HASH, FACTORY) != address(this)) {
        revert InvalidImmutables();
    }
}
```

The validation fails because:
- `FACTORY` = `0x93FEC2C00BfE902F733B57c5a6CeeD7CD1384AE1` (CREATE3 factory)
- But proxies are created by `0xa820F5dB10AE506D22c7654036a4B74F861367dB` (SimplifiedEscrowFactory)
- CREATE2 address calculation uses wrong factory address

## Proof of Bug

### Test Case
```solidity
// Deploy implementation via CREATE3
EscrowDst impl = CREATE3.deploy(salt, EscrowDst.creationCode);
// impl.FACTORY == 0x93FEC2C00BfE902F733B57c5a6CeeD7CD1384AE1 ❌ Wrong!

// Create proxy via SimplifiedEscrowFactory
address proxy = SimplifiedEscrowFactory.createDstEscrow(immutables);
// Proxy expects FACTORY == 0xa820F5dB10AE506D22c7654036a4B74F861367dB

// Withdrawal fails
proxy.withdraw(secret, immutables); // Reverts: InvalidImmutables()
```

### On-chain Evidence
Transaction: `0xce969b09830011ab1d091061530102c02b906a344128f9dd75e08ccb8cea9895`
- Created escrow at `0x51B9B216bfb473720875b5848055817FCb835d96`
- Withdrawal always fails with `InvalidImmutables()`
- Factory predicts correct address, but escrow validation fails

## Bug Fix

### Solution 1: Pass Factory Address in Constructor (Recommended)
```solidity
// BaseEscrow.sol
abstract contract BaseEscrow is IBaseEscrow, SoladyEIP712 {
    // ...
    address public immutable FACTORY;
    
    constructor(uint32 rescueDelay, IERC20 accessToken, address factory) {
        RESCUE_DELAY = rescueDelay;
        _ACCESS_TOKEN = accessToken;
        FACTORY = factory; // Pass factory explicitly
    }
}

// EscrowSrc.sol & EscrowDst.sol
constructor(uint32 rescueDelay, IERC20 accessToken, address factory) 
    BaseEscrow(rescueDelay, accessToken, factory) 
{
    // ...
}
```

### Solution 2: Use Deterministic Factory Address
```solidity
// BaseEscrow.sol
// Hardcode the SimplifiedEscrowFactory address for each chain
address public immutable FACTORY = 0xa820F5dB10AE506D22c7654036a4B74F861367dB;
```

### Solution 3: Factory Deploys Implementations
Have SimplifiedEscrowFactory deploy the implementation contracts directly instead of using CREATE3.

## Deployment Fix Instructions

### For v3.0.1 Deployment

1. **Update BaseEscrow.sol**:
```solidity
constructor(uint32 rescueDelay, IERC20 accessToken, address factory) {
    RESCUE_DELAY = rescueDelay;
    _ACCESS_TOKEN = accessToken;
    FACTORY = factory;
}
```

2. **Update EscrowSrc.sol & EscrowDst.sol**:
```solidity
constructor(uint32 rescueDelay, IERC20 accessToken, address factory) 
    BaseEscrow(rescueDelay, accessToken, factory) 
{}
```

3. **Update DeployMainnet.s.sol**:
```solidity
// When deploying implementations, predict factory address first
address predictedFactory = ICREATE3(CREATE3_FACTORY).getDeployed(deployer, factorySalt);

// Deploy with factory address
bytes memory srcBytecode = abi.encodePacked(
    type(EscrowSrc).creationCode,
    abi.encode(
        uint32(RESCUE_DELAY),
        IERC20(Constants.BMN_TOKEN),
        predictedFactory  // Pass factory address
    )
);
```

## Immediate Mitigation

### For Users
- **DO NOT USE v3.0.0 contracts** - withdrawals will fail
- Use v2.3.0 contracts until v3.0.1 is deployed
- Any funds in v3.0.0 escrows can only be recovered via rescue after delay

### For Developers
- Deploy v3.0.1 with the fix immediately
- Add integration tests that verify withdrawal works
- Consider adding a test that checks `escrow.FACTORY() == factory.address`

## Testing Recommendations

### Add Integration Test
```solidity
function test_WithdrawalWorks() public {
    // Create escrow
    Immutables memory imm = createTestImmutables();
    address escrow = factory.createDstEscrow(imm);
    
    // Verify FACTORY is correct
    assertEq(IEscrow(escrow).FACTORY(), address(factory));
    
    // Test withdrawal
    vm.prank(taker);
    IEscrow(escrow).withdraw(secret, imm);
    // Should not revert
}
```

### Add Factory Validation
```solidity
function test_FactoryAddressCorrect() public {
    // Deploy implementation with factory address
    EscrowDst impl = new EscrowDst(RESCUE_DELAY, BMN_TOKEN, address(factory));
    
    // Verify FACTORY is set correctly
    assertEq(impl.FACTORY(), address(factory));
}
```

## Severity Assessment

- **Severity**: CRITICAL
- **Impact**: Complete DoS of atomic swaps
- **Likelihood**: 100% (affects all v3.0.0 swaps)
- **Affected Contracts**: All v3.0.0 escrows on Base and Optimism
- **Risk**: Funds locked until rescue delay (30+ days)

## Recommendations

1. **Immediate**: Deploy v3.0.1 with fix
2. **Short-term**: Audit all immutable variables in proxy patterns
3. **Long-term**: Add comprehensive integration tests for full swap flow
4. **Process**: Test on testnet with full atomic swap before mainnet deployment

## Timeline

- **Bug Discovered**: 2025-08-15
- **Root Cause Identified**: FACTORY immutable incorrectly set
- **Fix Proposed**: Pass factory address in constructor
- **Recommended Action**: Deploy v3.0.1 immediately

---

*Report prepared by BMN Protocol Security Analysis*
*Contact: security@1inch.io*