# Resolver Integration Guide for v2.2.0

> Version: 2.2.0
> Factory Address: `0xB436dBBee1615dd80ff036Af81D8478c1FF1Eb68`
> Created: 2025-01-07
> Status: Production Ready

## Overview

Bridge-Me-Not v2.2.0 introduces atomic escrow creation through the 1inch SimpleLimitOrderProtocol's PostInteraction mechanism. This guide explains how resolvers integrate with the new factory contract.

## Key Changes from v2.1.0

### New Features
- **PostInteraction Interface**: Factory now implements `IPostInteraction` for atomic escrow creation
- **Direct Integration**: Orders filled through 1inch protocol automatically create escrows
- **Simplified Flow**: No separate escrow creation transaction needed
- **Gas Optimization**: Single atomic transaction reduces gas costs

### Breaking Changes
- Factory address changed to `0xB436dBBee1615dd80ff036Af81D8478c1FF1Eb68`
- New approval requirements for token transfers
- Different event signatures for monitoring

## Integration Requirements

### 1. Token Approvals

The resolver MUST approve the factory contract to transfer tokens:

```javascript
// Required approval before filling orders
await tokenContract.approve(
    "0xB436dBBee1615dd80ff036Af81D8478c1FF1Eb68", // v2.2.0 Factory
    ethers.MaxUint256 // Or specific amount
);
```

**Important**: Without this approval, the PostInteraction will fail when trying to transfer tokens from the resolver to the escrow.

### 2. Order Creation with PostInteraction

When creating orders through the 1inch protocol, include the factory as a PostInteraction:

```javascript
const orderData = {
    // Standard order fields
    maker: makerAddress,
    receiver: receiverAddress,
    makerAsset: tokenAddress,
    takerAsset: otherTokenAddress,
    makingAmount: amount,
    takingAmount: expectedAmount,
    
    // PostInteraction configuration
    postInteraction: "0xB436dBBee1615dd80ff036Af81D8478c1FF1Eb68" // Factory address
};

// Encode extension data for PostInteraction
const extensionData = encodePostInteractionData(escrowParams);
```

### 3. Extension Data Encoding

The PostInteraction requires properly encoded extension data containing escrow parameters:

```javascript
function encodePostInteractionData(params) {
    // Encode escrow creation parameters
    return ethers.AbiCoder.defaultAbiCoder().encode(
        [
            "address",  // srcImplementation
            "address",  // dstImplementation
            "uint256",  // timelocks
            "bytes32",  // hashlock
            "address",  // srcMaker
            "address",  // srcTaker
            "address",  // srcToken
            "uint256",  // srcAmount
            "uint256",  // srcSafetyDeposit
            "address",  // dstReceiver
            "address",  // dstToken
            "uint256",  // dstAmount
            "uint256",  // dstSafetyDeposit
            "uint256",  // nonce
        ],
        [
            params.srcImplementation,
            params.dstImplementation,
            params.timelocks,
            params.hashlock,
            params.srcMaker,
            params.srcTaker,
            params.srcToken,
            params.srcAmount,
            params.srcSafetyDeposit,
            params.dstReceiver,
            params.dstToken,
            params.dstAmount,
            params.dstSafetyDeposit,
            params.nonce
        ]
    );
}
```

### 4. Event Monitoring

Monitor new events emitted by the v2.2.0 factory:

```javascript
// PostInteraction execution event
const postInteractionFilter = factory.filters.PostInteractionExecuted(
    null, // orderHash
    null, // taker
    null, // srcEscrow
    null  // dstEscrow
);

factory.on(postInteractionFilter, (orderHash, taker, srcEscrow, dstEscrow, event) => {
    console.log("PostInteraction executed:");
    console.log("  Order Hash:", orderHash);
    console.log("  Taker:", taker);
    console.log("  Source Escrow:", srcEscrow);
    console.log("  Destination Escrow:", dstEscrow);
    
    // Process escrow creation
    handleEscrowCreated(srcEscrow, dstEscrow);
});

// Standard escrow creation events still emitted
const escrowFilter = factory.filters.EscrowCreated(
    null, // escrowAddress
    null, // escrowType
    null  // immutablesHash
);
```

## Complete Integration Flow

### Step 1: Setup and Approvals

```javascript
const FACTORY_ADDRESS = "0xB436dBBee1615dd80ff036Af81D8478c1FF1Eb68";
const LIMIT_ORDER_PROTOCOL = "0x111111125421ca6dc452d28d826b88f5ccd8c793"; // 1inch protocol

// Approve factory for token transfers
async function setupApprovals(tokenAddress, resolverSigner) {
    const token = new ethers.Contract(tokenAddress, ERC20_ABI, resolverSigner);
    
    // Check current allowance
    const currentAllowance = await token.allowance(
        resolverSigner.address,
        FACTORY_ADDRESS
    );
    
    if (currentAllowance < requiredAmount) {
        const tx = await token.approve(FACTORY_ADDRESS, ethers.MaxUint256);
        await tx.wait();
        console.log("Factory approved for token transfers");
    }
}
```

### Step 2: Create Order with PostInteraction

```javascript
async function createOrderWithEscrow(orderParams, escrowParams) {
    // Prepare order for 1inch protocol
    const order = {
        salt: generateSalt(),
        maker: orderParams.maker,
        receiver: orderParams.receiver || ethers.ZeroAddress,
        makerAsset: orderParams.makerAsset,
        takerAsset: orderParams.takerAsset,
        makingAmount: orderParams.makingAmount,
        takingAmount: orderParams.takingAmount,
        makerTraits: buildMakerTraits({
            postInteraction: FACTORY_ADDRESS
        })
    };
    
    // Encode escrow parameters as extension data
    const extensionData = encodePostInteractionData(escrowParams);
    
    // Sign order
    const signature = await signOrder(order, orderParams.makerSigner);
    
    return {
        order,
        signature,
        extensionData
    };
}
```

### Step 3: Fill Order (Resolver Side)

```javascript
async function fillOrderAsResolver(order, signature, extensionData, resolverSigner) {
    const limitOrderProtocol = new ethers.Contract(
        LIMIT_ORDER_PROTOCOL,
        LIMIT_ORDER_ABI,
        resolverSigner
    );
    
    // Ensure resolver has approved factory
    await setupApprovals(order.takerAsset, resolverSigner);
    
    // Fill order with PostInteraction
    const tx = await limitOrderProtocol.fillOrderExt(
        order,
        signature,
        order.takingAmount, // Amount to fill
        order.takingAmount, // Threshold
        extensionData        // Contains escrow parameters
    );
    
    const receipt = await tx.wait();
    
    // Parse events to get escrow addresses
    const escrowAddresses = parseEscrowEvents(receipt);
    
    return {
        txHash: receipt.hash,
        srcEscrow: escrowAddresses.src,
        dstEscrow: escrowAddresses.dst
    };
}
```

### Step 4: Monitor and Process Escrows

```javascript
async function monitorEscrows(factory) {
    // Listen for PostInteraction executions
    factory.on("PostInteractionExecuted", async (orderHash, taker, srcEscrow, dstEscrow) => {
        console.log(`New escrows created for order ${orderHash}`);
        
        // Track escrow pair
        await trackEscrowPair(srcEscrow, dstEscrow);
        
        // Monitor for secret reveal on destination
        await monitorSecretReveal(dstEscrow);
        
        // Execute withdrawal when conditions met
        await executeWithdrawal(srcEscrow, dstEscrow);
    });
    
    // Also monitor standard escrow events
    factory.on("EscrowCreated", (escrowAddress, escrowType, immutablesHash) => {
        console.log(`Escrow created: ${escrowAddress} (${escrowType})`);
    });
}
```

## Error Handling

### Common Errors and Solutions

#### 1. Insufficient Allowance
```
Error: ERC20: insufficient allowance
Solution: Approve factory before filling orders
```

#### 2. Invalid Extension Data
```
Error: Invalid extension data format
Solution: Ensure proper encoding of all escrow parameters
```

#### 3. Resolver Not Whitelisted
```
Error: Unauthorized resolver
Solution: Contact factory owner for whitelist addition
```

#### 4. PostInteraction Failed
```
Error: PostInteraction execution failed
Solution: Check token balances and approvals
```

### Error Recovery

```javascript
async function handlePostInteractionError(error, order) {
    if (error.message.includes("insufficient allowance")) {
        // Re-approve and retry
        await setupApprovals(order.takerAsset);
        return retry();
    }
    
    if (error.message.includes("Unauthorized")) {
        // Resolver not whitelisted
        console.error("Resolver not whitelisted on factory");
        return false;
    }
    
    // Log unexpected errors
    console.error("Unexpected error:", error);
    await notifyOperator(error, order);
}
```

## Testing Integration

### Local Testing

```javascript
// Test script for local development
async function testPostInteraction() {
    // Deploy test environment
    const { factory, tokenA, tokenB } = await deployTestContracts();
    
    // Setup test accounts
    const [maker, resolver] = await ethers.getSigners();
    
    // Fund accounts
    await tokenA.transfer(maker.address, ethers.parseEther("100"));
    await tokenB.transfer(resolver.address, ethers.parseEther("100"));
    
    // Approve factory
    await tokenB.connect(resolver).approve(factory.address, ethers.MaxUint256);
    
    // Create and fill order
    const order = await createTestOrder(maker, resolver);
    const tx = await fillOrderWithPostInteraction(order, resolver);
    
    // Verify escrow creation
    const receipt = await tx.wait();
    assert(receipt.logs.some(log => log.topics[0] === ESCROW_CREATED_TOPIC));
}
```

### Mainnet Testing

1. Use small amounts initially
2. Monitor gas usage (typical: ~105k gas for PostInteraction)
3. Verify escrow addresses match expected CREATE2 computation
4. Test cancellation and withdrawal flows

## Migration Checklist

- [ ] Update factory address to `0xB436dBBee1615dd80ff036Af81D8478c1FF1Eb68`
- [ ] Add token approval logic for new factory
- [ ] Update order creation to include PostInteraction
- [ ] Implement extension data encoding
- [ ] Update event monitoring for new events
- [ ] Test on testnet with small amounts
- [ ] Verify gas costs are acceptable
- [ ] Update monitoring dashboards
- [ ] Deploy to production

## Gas Optimization Tips

1. **Batch Approvals**: Approve maximum uint256 once instead of per-transaction
2. **Reuse Nonces**: Track used nonces to avoid redundant checks
3. **Optimize Extension Data**: Pack parameters efficiently
4. **Monitor Gas Prices**: Use gas oracles for optimal pricing

## Security Considerations

1. **Verify Factory Address**: Always use official address `0xB436dBBee1615dd80ff036Af81D8478c1FF1Eb68`
2. **Check Whitelisting**: Ensure resolver is whitelisted before production
3. **Validate Parameters**: Verify all escrow parameters before submission
4. **Monitor Events**: Track all escrow creations and withdrawals
5. **Emergency Procedures**: Have cancellation logic ready for failed swaps

## Support and Resources

- **Technical Documentation**: `/docs/POSTINTERACTION_IMPLEMENTATION.md`
- **Contract Source**: `/contracts/SimplifiedEscrowFactory.sol`
- **Test Suite**: `/test/PostInteractionTest.sol`
- **GitHub Issues**: Report bugs or request features
- **Discord**: Join developer community for support

## Appendix: ABI References

### PostInteraction Function
```solidity
function postInteraction(
    ILimitOrderProtocol.Order calldata order,
    bytes calldata extension,
    bytes32 orderHash,
    address taker,
    uint256 makingAmount,
    uint256 takingAmount,
    uint256 remainingMakingAmount,
    bytes calldata extraData
) external;
```

### Events
```solidity
event PostInteractionExecuted(
    bytes32 indexed orderHash,
    address indexed taker,
    address srcEscrow,
    address dstEscrow
);

event EscrowCreated(
    address indexed escrowAddress,
    EscrowType indexed escrowType,
    bytes32 indexed immutablesHash
);
```