# BMN V2 Token Deployment Status & Critical Issue

## 🚨 Critical Finding: Wrong Contract Deployed

### Executive Summary
The BMN V2 token at `0xf410a63e825C162274c3295F13EcA1Dd1202b5cC` has incorrect bytecode deployed. This causes transfers to emit events correctly but fail to update recipient balances.

### Evidence
1. **Bytecode Mismatch**:
   - Expected BMNAccessTokenV2 bytecode hash: `0x8bb6d8caa71b497082052440f0509e08322a70328f20ea9245fc79de83805ef5`
   - Actual deployed bytecode hash: `0x626e0f0e42bbeb6c6be16d8f816c6e7688d12c9842492c57889eea664cd045c0`
   - **These DO NOT match!**

2. **Symptoms**:
   - Transfer events emit correctly
   - Deployer balance decreases (1000 → 900 BMN)
   - Recipient balances remain 0
   - Total supply updates correctly

### Root Cause Analysis

The deployment script (`DeployBMNV2Mainnet.s.sol`) has a critical issue with CREATE2 deployment:

1. **Address Calculation**: Uses `Create2.computeAddress()` with `CREATE2_FACTORY`
2. **Actual Deployment**: Uses `new BMNAccessTokenV2{salt: SALT}(deployer)`

These two methods produce different addresses because:
- `Create2.computeAddress()` assumes deployment through the CREATE2 factory at `0x4e59b44847b379578588920cA78FbF26c0B4956C`
- `new {salt:}` uses the deployer's address as the CREATE2 origin

### Current State
- **Contract Address**: `0xf410a63e825C162274c3295F13EcA1Dd1202b5cC` (on Base and Etherlink)
- **Deployer**: `0x5f29827e25dc174a6A51C99e6811Bbd7581285b0`
- **Decimals**: Claims to be 18 (via `decimals()` function)
- **Total Supply**: 1000 BMN (all in deployer's account)
- **Failed Transfers**:
  - Alice: Should have 100 BMN, has 0
  - Bob: Should have 100 BMN, has 0

## 🛠️ Comprehensive Fix Plan

### Phase 1: Verify & Diagnose (Immediate)
1. **Decode the deployed bytecode** to understand what contract is actually deployed
2. **Check if it's a proxy** that might be pointing to wrong implementation
3. **Verify storage slot locations** for balance mappings

### Phase 2: Deploy Correct Contract (Priority)
1. **Fix deployment script** to use proper CREATE2 method:
   ```solidity
   // Option A: Use CREATE2 factory directly
   bytes memory bytecode = abi.encodePacked(
       type(BMNAccessTokenV2).creationCode,
       abi.encode(deployer)
   );
   address token = Create2.deploy(0, SALT, bytecode);
   
   // Option B: Calculate correct address for direct deployment
   address predictedAddress = computeCreate2Address(
       SALT,
       keccak256(bytecode),
       address(this) // Use deployer contract address, not factory
   );
   ```

2. **Use new salt** to get fresh address (e.g., `keccak256("BMN_V2_CORRECT_DEPLOYMENT")`)

3. **Deploy on both chains** with proper verification

### Phase 3: Migration Strategy
1. **Deploy new BMN V2** with correct implementation
2. **Update all references** in:
   - EscrowFactory contracts
   - Test scripts
   - Resolver configuration
3. **Transfer funds** from old to new contract (if possible)

### Phase 4: Testing & Validation
1. **Test transfers** on new deployment
2. **Verify balances** update correctly
3. **Run full E2E tests** with new token address

## 📋 Action Items

### Immediate (Do Now):
- [ ] Analyze deployed bytecode to understand current contract
- [ ] Create fixed deployment script with proper CREATE2
- [ ] Choose new deployment salt

### Short Term (Next 2 Hours):
- [ ] Deploy corrected BMN V2 on both chains
- [ ] Test basic transfer functionality
- [ ] Update unified test script with new address

### Medium Term (Today):
- [ ] Update all contract references
- [ ] Run full E2E cross-chain tests
- [ ] Document the fix and lessons learned

## 🔧 Technical Details for Resolver

### Environment Variables to Update:
```bash
# New BMN V2 address (after redeployment)
BMN_TOKEN="0x[NEW_ADDRESS_HERE]"
BASE_TOKEN_BMN="0x[NEW_ADDRESS_HERE]"
ETHERLINK_TOKEN_BMN="0x[NEW_ADDRESS_HERE]"
```

### Files to Update:
1. `/bmn-evm-contracts/scripts/test-mainnet-unified.sh` - Line 21
2. `/bmn-evm-resolver/.env` - BMN token addresses
3. Any hardcoded references in resolver code

### Testing Commands:
```bash
# Check balance after new deployment
cast call [NEW_ADDRESS] "balanceOf(address)(uint256)" [ALICE_ADDRESS] --rpc-url [RPC_URL]

# Test transfer
cast send [NEW_ADDRESS] "transfer(address,uint256)" [ALICE_ADDRESS] 100000000000000000000 --private-key $DEPLOYER_PRIVATE_KEY --rpc-url [RPC_URL]
```

## 🚀 Next Steps

1. **I will create the fixed deployment script** with proper CREATE2 usage
2. **Deploy the corrected contract** on both mainnets
3. **Verify transfers work** as expected
4. **Update all configurations** to use the new address

## 📝 Notes for Parallel Work

While I fix the deployment:
- Resolver team can prepare to update token addresses
- Testing team can review the unified test script
- Documentation team can prepare migration notes

The core issue is clear: wrong bytecode deployed due to CREATE2 method mismatch. Fix is straightforward but requires careful execution.