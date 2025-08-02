# Simplified Cross-Chain Atomic Swap Design

## Overview

This document outlines a dramatically simplified version of the cross-chain atomic swap protocol that maintains core functionality while eliminating unnecessary complexity. The goal is to create a system that is easy to understand, test, and deploy.

## Core Principles

1. **Minimal Dependencies**: No external protocol requirements
2. **Direct Operations**: All functions directly callable
3. **Simple State**: Reduced state management complexity
4. **Clear Roles**: Unambiguous participant responsibilities
5. **Easy Testing**: Single-script test capability

## Simplified Architecture

### 1. Two Contracts Only

```
SimplifiedAtomicSwap/
├── SimpleEscrow.sol      // Combined src/dst functionality
└── SimpleFactory.sol     // Direct creation, no callbacks
```

### 2. Unified Escrow Contract

Instead of separate `EscrowSrc` and `EscrowDst`, use a single contract:

```solidity
contract SimpleEscrow {
    struct SwapParams {
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        uint256 amountOut;
        address initiator;
        address responder;
        bytes32 hashlock;
        uint256 timelock;
    }
    
    enum State { Empty, Funded, Withdrawn, Refunded }
    
    State public state;
    SwapParams public params;
    
    function fund() external;
    function withdraw(bytes32 secret) external;
    function refund() external;
}
```

### 3. Direct Factory Operations

```solidity
contract SimpleFactory {
    // Direct creation - no callbacks, no integrations
    function createEscrow(
        address token,
        uint256 amount,
        address recipient,
        bytes32 hashlock,
        uint256 timelock
    ) external returns (address escrow);
    
    // Deterministic address calculation
    function computeEscrowAddress(
        address token,
        uint256 amount,
        address recipient,
        bytes32 hashlock
    ) external view returns (address);
}
```

## Simplified Flow

### Step 1: Alice Creates Escrow on Chain A
```solidity
// Alice directly creates and funds escrow
bytes32 secret = keccak256("my_secret");
bytes32 hashlock = keccak256(abi.encode(secret));

address escrowA = factory.createEscrow(
    tokenA,
    amountA,
    bob,
    hashlock,
    timestamp + 1 hour
);
```

### Step 2: Bob Creates Escrow on Chain B
```solidity
// Bob sees Alice's escrow and creates matching one
address escrowB = factory.createEscrow(
    tokenB,
    amountB,
    alice,
    hashlock,  // Same hashlock
    timestamp + 30 minutes  // Shorter timelock
);
```

### Step 3: Bob Withdraws on Chain A
```solidity
// Bob reveals secret to claim tokens
SimpleEscrow(escrowA).withdraw(secret);
```

### Step 4: Alice Withdraws on Chain B
```solidity
// Alice uses revealed secret
SimpleEscrow(escrowB).withdraw(secret);
```

## Key Simplifications

### 1. Timelock System

**Original**: 7 different timelock stages with complex packing
**Simplified**: Single timelock per escrow

```solidity
// Original - complex
struct Timelocks {
    uint32 srcWithdrawalStart;
    uint32 srcPublicWithdrawalStart;
    uint32 srcCancellationStart;
    // ... 4 more
}

// Simplified
uint256 public refundTime;  // That's it!
```

### 2. No Packed Structs

**Original**: Complex immutables with hashing
**Simplified**: Direct storage variables

```solidity
// Original
IBaseEscrow.Immutables memory immutables = IBaseEscrow.Immutables({
    orderHash: orderHash,
    hashlock: hashlock,
    maker: Address.wrap(uint160(alice)),
    // ... many more fields
});

// Simplified
hashlock = _hashlock;
recipient = _recipient;
amount = _amount;
```

### 3. No External Integrations

**Original**: Required Limit Order Protocol
**Simplified**: Standalone operation

### 4. Simple Testing

**Original**: 5-step process with chain switching
**Simplified**: Single test script

```javascript
// Complete test in one script
async function testAtomicSwap() {
    // Deploy on both chains
    const factoryA = await deployFactory(chainA);
    const factoryB = await deployFactory(chainB);
    
    // Create escrows
    const escrowA = await createEscrow(factoryA, ...);
    const escrowB = await createEscrow(factoryB, ...);
    
    // Execute swap
    await withdraw(escrowA, secret);
    await withdraw(escrowB, secret);
    
    // Verify
    assert(balances changed correctly);
}
```

## Removed Complexity

### 1. Removed Features
- Order system integration
- Multi-stage timelocks
- Safety deposits
- Rescue mechanisms
- Access token requirements
- Fee token system
- Maker/taker traits
- Public withdrawal phases

### 2. Removed Libraries
- TimelocksLib (complex packing)
- ImmutablesLib (hashing logic)
- ProxyHashLib (CREATE2 calculations)
- Complex type wrappers

### 3. Removed Patterns
- Callback-based creation
- Extension system
- Resolver validation
- Multi-role permissions

## Benefits of Simplified Design

### 1. Easier to Understand
- Clear flow: create → fund → withdraw/refund
- No hidden interactions
- Direct function calls

### 2. Easier to Test
- No multi-chain coordination required
- Can test with simple scripts
- No state file management

### 3. Easier to Audit
- Minimal attack surface
- Clear state transitions
- No complex integrations

### 4. Easier to Deploy
- Two contracts only
- No configuration required
- Works immediately

## Trade-offs

### What We Keep
✅ Atomic swap guarantee
✅ Hashlock security
✅ Timelock protection
✅ Cross-chain compatibility
✅ Deterministic addresses

### What We Lose
❌ Order book integration
❌ Advanced timelock strategies
❌ Griefing protection (safety deposits)
❌ Emergency rescue mechanisms
❌ Gas optimizations

## Migration Path

For projects needing more features:

1. **Start Simple**: Deploy basic version
2. **Add Features**: Incrementally add complexity
3. **Maintain Compatibility**: Keep simple interface
4. **Optional Modules**: Make advanced features optional

## Example Implementation Sketch

```solidity
// Complete SimpleEscrow.sol
contract SimpleEscrow {
    address public immutable token;
    address public immutable recipient;
    uint256 public immutable amount;
    bytes32 public immutable hashlock;
    uint256 public immutable refundTime;
    address public immutable creator;
    
    bool public withdrawn;
    bool public refunded;
    
    constructor(
        address _token,
        address _recipient,
        uint256 _amount,
        bytes32 _hashlock,
        uint256 _refundTime
    ) {
        token = _token;
        recipient = _recipient;
        amount = _amount;
        hashlock = _hashlock;
        refundTime = _refundTime;
        creator = msg.sender;
        
        // Auto-transfer tokens on creation
        IERC20(token).transferFrom(creator, address(this), amount);
    }
    
    function withdraw(bytes32 secret) external {
        require(!withdrawn && !refunded, "Already finished");
        require(keccak256(abi.encode(secret)) == hashlock, "Invalid secret");
        
        withdrawn = true;
        IERC20(token).transfer(recipient, amount);
        emit Withdrawn(recipient, secret);
    }
    
    function refund() external {
        require(!withdrawn && !refunded, "Already finished");
        require(block.timestamp >= refundTime, "Too early");
        
        refunded = true;
        IERC20(token).transfer(creator, amount);
        emit Refunded(creator);
    }
}
```

This simplified design eliminates 90% of the complexity while maintaining the core atomic swap functionality.