# 🚨 CRITICAL BUG FIX: v3.0.2 - FACTORY Immutable Issue

## Executive Summary

**Severity**: HIGH  
**Impact**: All v3.0.0 and v3.0.1 deployments using CREATE3  
**Status**: Fix Required  
**Version**: v3.0.2 (Proposed)  

The current v3.0.0 and v3.0.1 contracts have a critical bug where escrows deployed via CREATE3 fail withdrawal validation due to incorrect FACTORY immutable storage.

## Bug Description

### The Issue
When SimplifiedEscrowFactory deploys escrows using CREATE3:
1. Factory calls CREATE3 deployer to create the escrow
2. CREATE3 deploys a proxy that then deploys the actual escrow
3. BaseEscrow constructor sets `FACTORY = msg.sender`
4. But `msg.sender` is the CREATE3 proxy, NOT SimplifiedEscrowFactory
5. Withdrawal validation fails with `InvalidImmutables()` because CREATE2 address computation uses wrong factory

### Impact
- ✅ Escrow creation succeeds
- ✅ Funds are locked in escrow
- ❌ Withdrawals fail with `InvalidImmutables()`
- ❌ Funds become permanently locked

### Affected Deployments
```
CREATE3 Deployments (AFFECTED):
- Base: 0xF99e2f0772f9c381aD91f5037BF7FF7dE8a68DDc
- Optimism: 0xF99e2f0772f9c381aD91f5037BF7FF7dE8a68DDc

v3.0.1 Direct Deployments (ALSO AFFECTED if using Clones):
- Base: 0x4E03F2dA3433626c4ed65544b6A99a013f5768d2
- Optimism: 0x0EB761170E01d403a84d6237b5A1776eE2091eA3
```

## Root Cause Analysis

### Current Code (BROKEN)
```solidity
// BaseEscrow.sol:33
address public immutable FACTORY = msg.sender;  // ❌ Gets CREATE3 proxy address
```

### Call Flow with CREATE3
```
User → SimplifiedEscrowFactory.createSrcEscrow()
    → CREATE3.deploy(salt, creationCode)
        → CREATE3 Proxy (becomes msg.sender)
            → BaseEscrow constructor
                → FACTORY = msg.sender  // ❌ Sets to CREATE3 proxy!
```

### Why CREATE2 Validation Fails
```solidity
// BaseEscrow.sol:142-151 (_validateImmutables)
address expectedAddress = Clones.predictDeterministicAddress(
    implementation,
    _calculateSalt(immutables),
    FACTORY  // ❌ Uses CREATE3 proxy instead of SimplifiedEscrowFactory
);
if (expectedAddress != address(this)) {
    revert InvalidImmutables();  // Always fails!
}
```

## Proposed Fix for v3.0.2

### Solution 1: Factory Address in Immutables (RECOMMENDED)
```solidity
// BaseEscrow.sol
contract BaseEscrow {
    // Remove hardcoded FACTORY immutable
    // address public immutable FACTORY = msg.sender;  // DELETE THIS
    
    function _validateImmutables(Immutables calldata immutables) internal view {
        // Extract factory from immutables (e.g., use high bits of timelocks)
        address factory = address(uint160(immutables.timelocks >> 96));
        
        address expectedAddress = Clones.predictDeterministicAddress(
            implementation,
            _calculateSalt(immutables),
            factory  // ✅ Use factory from immutables
        );
        
        if (expectedAddress != address(this)) {
            revert InvalidImmutables();
        }
    }
}

// SimplifiedEscrowFactory.sol
function createSrcEscrow(BaseEscrow.Immutables calldata immutables) external {
    // Pack factory address into immutables.timelocks high bits
    uint256 packedTimelocks = immutables.timelocks | (uint256(uint160(address(this))) << 96);
    
    BaseEscrow.Immutables memory modifiedImmutables = BaseEscrow.Immutables({
        orderHash: immutables.orderHash,
        hashlock: immutables.hashlock,
        maker: immutables.maker,
        taker: immutables.taker,
        token: immutables.token,
        amount: immutables.amount,
        safetyDeposit: immutables.safetyDeposit,
        timelocks: packedTimelocks  // ✅ Contains factory address
    });
    
    // Deploy with CREATE3 or Clones
    _deploy(modifiedImmutables);
}
```

### Solution 2: Two-Step Initialization (Alternative)
```solidity
// BaseEscrow.sol
contract BaseEscrow {
    address public FACTORY;
    
    function initialize(address factory) external {
        require(FACTORY == address(0), "Already initialized");
        FACTORY = factory;
    }
}

// SimplifiedEscrowFactory.sol
function createSrcEscrow(Immutables calldata immutables) external {
    address escrow = _deploy(immutables);
    BaseEscrow(escrow).initialize(address(this));
}
```

### Solution 3: Factory Registry (Complex but Flexible)
```solidity
// FactoryRegistry.sol
contract FactoryRegistry {
    mapping(address => address) public escrowToFactory;
    
    function registerEscrow(address escrow) external {
        escrowToFactory[escrow] = msg.sender;
    }
}

// BaseEscrow.sol
function _validateImmutables(Immutables calldata immutables) internal view {
    address factory = IFactoryRegistry(REGISTRY).escrowToFactory(address(this));
    // ... validate using factory
}
```

## Deployment Plan

### Phase 1: Testing (Immediate)
```bash
# 1. Deploy v3.0.2 contracts to testnet
forge script script/Deploy.s.sol --rpc-url $TESTNET_RPC

# 2. Test complete flow
- Create order with v3.0.2 factory
- Execute swap (create escrows)
- Verify withdrawal succeeds
- Test cancellation flows
```

### Phase 2: Mainnet Deployment
```bash
# 1. Deploy new factory contracts
forge script script/DeployV302.s.sol --rpc-url $BASE_RPC --broadcast
forge script script/DeployV302.s.sol --rpc-url $OPTIMISM_RPC --broadcast

# 2. Update resolver configuration
- Update .env with v3.0.2 factory addresses
- Regenerate contract bindings
```

### Phase 3: Migration Support
```solidity
// MigrationHelper.sol (if needed for stuck funds)
contract MigrationHelper {
    function emergencyWithdraw(
        address oldEscrow,
        bytes32 secret,
        Immutables calldata immutables
    ) external {
        // Admin-only recovery mechanism for stuck funds
        require(msg.sender == ADMIN, "Unauthorized");
        // ... validate and transfer funds
    }
}
```

## Testing Requirements

### Unit Tests
```solidity
// test/BaseEscrow.t.sol
function test_WithdrawWithCREATE3Deployment() public {
    // Deploy factory using CREATE3
    factory = CREATE3.deploy(salt, factoryBytecode);
    
    // Create escrow through factory
    factory.createSrcEscrow(immutables);
    
    // Withdraw should succeed
    escrow.withdraw(secret, immutables);
}

function test_ValidateImmutablesWithCorrectFactory() public {
    // Should not revert with correct factory in immutables
}
```

### Integration Tests
1. Full atomic swap flow with CREATE3 deployment
2. Withdrawal timing validation
3. Cancellation flows
4. Gas optimization verification

## Verification Steps

### Before Fix (v3.0.0/v3.0.1)
```bash
# Will fail with InvalidImmutables
cast call $ESCROW "FACTORY()" --rpc-url $RPC
# Returns: 0xF99e2f0772f9c381aD91f5037BF7FF7dE8a68DDc (CREATE3 factory)
```

### After Fix (v3.0.2)
```bash
# Should succeed
cast call $ESCROW "validateImmutables((bytes32,bytes32,uint256,uint256,uint256,uint256,uint256,uint256))" \
  --rpc-url $RPC
# No revert = success
```

## Timeline

- **Day 1**: Implement fix in contracts
- **Day 2**: Deploy to testnet, run tests
- **Day 3**: Security review
- **Day 4**: Mainnet deployment
- **Day 5**: Update resolver, monitor

## Risk Assessment

### Risks
1. **Locked Funds**: Existing v3.0.0/v3.0.1 escrows have locked funds
2. **Deployment Complexity**: Need coordinated multi-chain deployment
3. **Resolver Updates**: All resolvers must update to v3.0.2

### Mitigations
1. **Emergency Admin**: Deploy with time-locked admin for recovery
2. **Gradual Migration**: Support both v3.0.1 and v3.0.2 temporarily
3. **Clear Communication**: Notify all integrators immediately

## Recommended Implementation

Use **Solution 1** (Factory in Immutables) because:
- ✅ No additional storage slots
- ✅ No initialization transactions
- ✅ Works with CREATE3 and direct deployment
- ✅ Minimal code changes
- ✅ Gas efficient

## Code Changes Required

### Files to Modify
1. `contracts/BaseEscrow.sol` - Remove FACTORY immutable, update validation
2. `contracts/SimplifiedEscrowFactory.sol` - Pack factory into immutables
3. `contracts/interfaces/IBaseEscrow.sol` - Update Immutables struct docs
4. `test/BaseEscrow.t.sol` - Add CREATE3 tests
5. `script/DeployV302.s.sol` - New deployment script

### Estimated LOC Changes
- BaseEscrow.sol: ~10 lines
- SimplifiedEscrowFactory.sol: ~15 lines
- Tests: ~50 lines
- Total: ~75 lines

## Conclusion

The FACTORY immutable bug is critical and affects all CREATE3 deployments. The fix is straightforward but requires careful deployment and migration planning. Version 3.0.2 should be deployed immediately to prevent further locked funds.

## Contact

For questions or concerns:
- GitHub Issues: [bmn-evm-contracts/issues]
- Security: security@bridgemenot.eth

---

*Document Version: 1.0*  
*Date: 2025-01-15*  
*Author: BMN Protocol Team*