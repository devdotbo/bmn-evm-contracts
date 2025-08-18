# BMN Protocol Deployments

## Current Production Deployment (v4.0.0) - LATEST

**SimplifiedEscrowFactory v4.0.0**: `0x5782442ED775a6FF7DA5FBcD8F612C8Bc4b285d3`
- **Base (Chain ID 8453)**: `0x5782442ED775a6FF7DA5FBcD8F612C8Bc4b285d3`
- **Optimism (Chain ID 10)**: `0x5782442ED775a6FF7DA5FBcD8F612C8Bc4b285d3`
- **Deployment Date**: August 17, 2025
- **Deployed via**: CREATE3 (same address on both chains)

### Implementation Contracts (Same on Both Chains)
- **EscrowSrc**: `0x7540917a576E4f5d08Bc567650586fA1D5C00b57`
- **EscrowDst**: `0x5FD53b763C2360B7ed6F11C96b95E0B26586D2F5`

### Verification Status
- ✅ **Base**: All contracts verified on [Basescan](https://basescan.org/address/0x5782442ED775a6FF7DA5FBcD8F612C8Bc4b285d3#code)
- ✅ **Optimism**: All contracts verified on [Optimistic Etherscan](https://optimistic.etherscan.io/address/0x5782442ED775a6FF7DA5FBcD8F612C8Bc4b285d3#code)

### Key Configuration
- **SimpleLimitOrderProtocol**: `0xe767105dcfB3034a346578afd2aFD8e583171489` (Bridge-Me-Not custom implementation on both chains)
- **Owner**: `0x5f29827e25dc174a6A51C99e6811Bbd7581285b0`
- **Rescue Delay**: 604800 seconds (7 days)
- **Whitelisted Resolver**: `0xfdF1dDeB176BEA06c7430166e67E615bC312b7B5` (Bob)

## 🚨 BREAKING CHANGES: v3 → v4

### Major Architecture Changes

#### 1. **Complete 1inch Protocol Integration**
- Factory now inherits from `SimpleSettlement` (1inch settlement extension)
- Direct integration with SimpleLimitOrderProtocol via `postInteraction()` entry point
- Removed standalone implementation pattern in favor of constructor-based deployment

#### 2. **Constructor Parameters Changed**
```solidity
// v3.0.2 Constructor
constructor(address _owner, uint32 _rescueDelay, IERC20 _accessToken, address _weth)

// v4.0.0 Constructor - NEW PARAMETER ORDER AND ADDITIONS
constructor(
    address limitOrderProtocol,  // NEW: Required 1inch protocol address
    address owner,               // Moved position
    uint32 rescueDelay,
    IERC20 accessToken,
    address weth
)
```

#### 3. **Implementation Deployment Pattern**
- **v3**: Used immutable implementation addresses set in constructor
- **v4**: Deploys implementations in constructor directly
- Implementations are now created during factory deployment, not separately

#### 4. **PostInteraction Flow (NEW)**
```solidity
// Primary entry point from 1inch protocol
function _postInteraction(
    IOrderMixin.Order calldata order,
    bytes calldata extension,
    bytes32 orderHash,
    address taker,
    uint256 makingAmount,
    uint256 takingAmount,
    uint256 remainingMakingAmount,
    bytes calldata extraData
) internal override
```

### Migration Requirements

#### For Resolvers:
1. **New Order Flow**: Orders now come through 1inch SimpleLimitOrderProtocol
2. **Token Approval Changes**: 
   - Makers approve SimpleLimitOrderProtocol (not factory)
   - Resolvers/Takers must approve factory for token transfers
3. **Event Monitoring**: Listen for `PostInteractionEscrowCreated` events
4. **Parameter Encoding**: Extra data must follow specific format for fees and cross-chain params

#### For Integrators:
1. **Update Factory Address**: New address `0x5782442ED775a6FF7DA5FBcD8F612C8Bc4b285d3`
2. **Update ABI**: Factory now includes SimpleSettlement functions
3. **Order Creation**: Create orders via 1inch protocol, not directly on factory
4. **Approval Flow**: 
   ```javascript
   // Maker approves 1inch protocol
   await token.approve(limitOrderProtocol, amount);
   
   // Resolver approves factory
   await token.approve(factory, amount);
   ```

### New Features in v4

1. **1inch Native Integration**: Full compatibility with 1inch limit order ecosystem
2. **Improved Gas Efficiency**: Constructor-based implementation deployment
3. **Enhanced Security**: Leverages battle-tested 1inch protocol
4. **Simplified Order Management**: Orders managed by 1inch protocol

### API Changes

#### Removed Functions:
- Direct order creation methods (now via 1inch)
- Standalone implementation setters

#### New Functions:
- `postInteraction()`: Entry point from 1inch protocol
- Settlement-related functions from SimpleSettlement

### Integration Example

```javascript
// v4.0.0 Integration Pattern
const limitOrderProtocol = "0xe767105dcfB3034a346578afd2aFD8e583171489"; // Bridge-Me-Not SimpleLimitOrderProtocol
const factory = "0x5782442ED775a6FF7DA5FBcD8F612C8Bc4b285d3";

// 1. Maker creates order via Bridge-Me-Not SimpleLimitOrderProtocol
const order = {
    salt: generateSalt(),
    maker: makerAddress,
    receiver: factory,  // Factory receives tokens
    makerAsset: tokenA,
    takerAsset: tokenB,
    makingAmount: amount,
    takingAmount: expectedAmount,
    makerTraits: buildMakerTraits()
};

// 2. Maker signs order (EIP-712)
const signature = await signOrder(order);

// 3. Resolver fills order through 1inch
// This triggers factory.postInteraction() automatically
await limitOrderProtocol.fillOrder(order, signature, makingAmount, takingAmount, extraData);
```

## Important: Resolver Integration Instructions

### How to Calculate Immutables for Withdrawals

When resolvers need to withdraw from escrows, they MUST use the exact `block.timestamp` from when the escrow was created:

```javascript
// Step 1: Listen for escrow creation event
const filter = factory.filters.PostInteractionEscrowCreated();
factory.on(filter, async (escrow, hashlock, sender, taker, amount, event) => {
    
    // Step 2: Get the block where the escrow was created
    const block = await provider.getBlock(event.blockNumber);
    const deployedAt = block.timestamp; // THIS is the exact timestamp the factory used
    
    // Step 3: Build immutables using this exact timestamp
    const packedTimelocks = buildTimelocks(deployedAt, srcCancellation, dstWithdrawal);
    
    // Step 4: Create immutables struct
    const immutables = {
        orderHash: orderHash,
        hashlock: hashlock,
        maker: makerAddress,
        taker: takerAddress,
        token: tokenAddress,
        amount: amount,
        safetyDeposit: safetyDeposit,
        timelocks: packedTimelocks
    };
    
    // Step 5: Use these immutables for withdrawal
    await escrow.withdraw(immutables, secret);
});
```

### Building Timelocks Correctly

```javascript
function buildTimelocks(deployedAt, srcCancellationTimestamp, dstWithdrawalTimestamp) {
    // Pack timelocks exactly as SimplifiedEscrowFactory does
    let packed = BigInt(deployedAt) << 224n;                                    // deployedAt
    packed |= BigInt(0) << 0n;                                                  // srcWithdrawal: 0 offset
    packed |= BigInt(60) << 32n;                                                // srcPublicWithdrawal: 60s offset
    packed |= BigInt(srcCancellationTimestamp - deployedAt) << 64n;            // srcCancellation offset
    packed |= BigInt(srcCancellationTimestamp - deployedAt + 60) << 96n;       // srcPublicCancellation offset
    packed |= BigInt(dstWithdrawalTimestamp - deployedAt) << 128n;             // dstWithdrawal offset
    packed |= BigInt(dstWithdrawalTimestamp - deployedAt + 60) << 160n;        // dstPublicWithdrawal offset
    packed |= BigInt(srcCancellationTimestamp - deployedAt) << 192n;           // dstCancellation (aligned with src)
    
    return packed;
}
```

### Common Mistakes to Avoid

❌ **WRONG**: Trying to predict `block.timestamp`
```javascript
const deployedAt = Math.floor(Date.now() / 1000); // DON'T DO THIS
```

✅ **CORRECT**: Reading actual `block.timestamp` from event
```javascript
const block = await provider.getBlock(event.blockNumber);
const deployedAt = block.timestamp; // DO THIS
```

## Previous Deployments

### v3.0.2 (Deprecated)
- **SimplifiedEscrowFactory**: `0xAbF126d74d6A438a028F33756C0dC21063F72E96`
- **Deployment Date**: August 16, 2025
- **Status**: Deprecated - Migrate to v4.0.0

### BMN Token (Still Active)
- **Address**: `0x8287CD2aC7E227D9D927F998EB600a0683a832A1` (all chains)
- **Note**: BMN token remains at same address, no migration needed

## Technical Details

### Architecture
- Uses Clone proxy pattern for gas-efficient escrow deployment
- CREATE3 for cross-chain deterministic addresses
- EIP-712 for secure off-chain signature validation
- 1inch SimpleSettlement for order management

### Key Contracts
- **SimplifiedEscrowFactory**: Main factory contract with 1inch integration
- **EscrowSrc**: Source chain escrow implementation
- **EscrowDst**: Destination chain escrow implementation
- **SimpleLimitOrderProtocol**: 1inch protocol for order management

### Security Features
- Resolver whitelist (with bypass option for permissionless mode)
- Emergency pause mechanism
- Rescue delay for stuck funds recovery
- Time-based access controls for withdrawals/cancellations
- Battle-tested 1inch protocol security

## Support

For integration support or questions:
- Review the technical documentation in `/docs`
- Check example integrations in `/test`
- Review 1inch documentation for order creation
- Contact the development team

## Deployment Commands

To verify deployment status:
```bash
# Check Base deployment
cast call 0x5782442ED775a6FF7DA5FBcD8F612C8Bc4b285d3 "owner()(address)" --rpc-url https://mainnet.base.org

# Check Optimism deployment  
cast call 0x5782442ED775a6FF7DA5FBcD8F612C8Bc4b285d3 "owner()(address)" --rpc-url https://mainnet.optimism.io

# Verify resolver is whitelisted
cast call 0x5782442ED775a6FF7DA5FBcD8F612C8Bc4b285d3 "isResolver(address)(bool)" 0xfdF1dDeB176BEA06c7430166e67E615bC312b7B5 --rpc-url https://mainnet.base.org
```