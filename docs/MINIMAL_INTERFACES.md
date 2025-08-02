# Minimal Interface Definitions for Simplified Atomic Swap

## Overview

This document provides minimal, clean interface definitions for a simplified atomic swap protocol. These interfaces strip away all unnecessary complexity while maintaining core functionality.

## Core Interfaces

### ISimpleEscrow

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ISimpleEscrow {
    // Events
    event Funded(address indexed creator, uint256 amount);
    event Withdrawn(address indexed recipient, bytes32 secret);
    event Refunded(address indexed creator);
    
    // Core Functions
    function withdraw(bytes32 secret) external;
    function refund() external;
    
    // View Functions
    function getDetails() external view returns (
        address token,
        address creator,
        address recipient,
        uint256 amount,
        bytes32 hashlock,
        uint256 refundTime,
        bool isWithdrawn,
        bool isRefunded
    );
}
```

### ISimpleFactory

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ISimpleFactory {
    // Events
    event EscrowCreated(
        address indexed escrow,
        address indexed creator,
        address indexed recipient,
        address token,
        uint256 amount,
        bytes32 hashlock
    );
    
    // Creation Function
    function createEscrow(
        address token,
        uint256 amount,
        address recipient,
        bytes32 hashlock,
        uint256 refundTime
    ) external returns (address escrow);
    
    // Address Calculation
    function computeEscrowAddress(
        address creator,
        address token,
        uint256 amount,
        address recipient,
        bytes32 hashlock
    ) external view returns (address);
}
```

## Essential Structs

### No Complex Structs!

Unlike the original implementation, we avoid complex nested structs:

```solidity
// ❌ Original - Too Complex
struct Immutables {
    bytes32 orderHash;
    bytes32 hashlock;
    Address maker;
    Address taker;
    Address token;
    uint256 amount;
    uint256 safetyDeposit;
    Timelocks timelocks;
}

// ✅ Simplified - Just Parameters
// No structs needed - use function parameters directly
```

## Minimal Token Interface

```solidity
// Only what we actually need from ERC20
interface IToken {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
}
```

## Complete Example Implementation

### SimpleEscrow.sol

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ISimpleEscrow.sol";
import "./IToken.sol";

contract SimpleEscrow is ISimpleEscrow {
    // Immutable storage (gas efficient)
    address public immutable token;
    address public immutable creator;
    address public immutable recipient;
    uint256 public immutable amount;
    bytes32 public immutable hashlock;
    uint256 public immutable refundTime;
    
    // Mutable state
    bool public isWithdrawn;
    bool public isRefunded;
    
    constructor(
        address _token,
        address _creator,
        address _recipient,
        uint256 _amount,
        bytes32 _hashlock,
        uint256 _refundTime
    ) {
        token = _token;
        creator = _creator;
        recipient = _recipient;
        amount = _amount;
        hashlock = _hashlock;
        refundTime = _refundTime;
        
        // Transfer tokens to escrow
        require(
            IToken(_token).transferFrom(_creator, address(this), _amount),
            "Transfer failed"
        );
        
        emit Funded(_creator, _amount);
    }
    
    function withdraw(bytes32 secret) external override {
        require(!isWithdrawn && !isRefunded, "Already completed");
        require(keccak256(abi.encode(secret)) == hashlock, "Invalid secret");
        
        isWithdrawn = true;
        
        require(
            IToken(token).transfer(recipient, amount),
            "Transfer failed"
        );
        
        emit Withdrawn(recipient, secret);
    }
    
    function refund() external override {
        require(!isWithdrawn && !isRefunded, "Already completed");
        require(block.timestamp >= refundTime, "Too early");
        require(msg.sender == creator, "Only creator");
        
        isRefunded = true;
        
        require(
            IToken(token).transfer(creator, amount),
            "Transfer failed"
        );
        
        emit Refunded(creator);
    }
    
    function getDetails() external view override returns (
        address,
        address,
        address,
        uint256,
        bytes32,
        uint256,
        bool,
        bool
    ) {
        return (
            token,
            creator,
            recipient,
            amount,
            hashlock,
            refundTime,
            isWithdrawn,
            isRefunded
        );
    }
}
```

### SimpleFactory.sol

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ISimpleFactory.sol";
import "./SimpleEscrow.sol";

contract SimpleFactory is ISimpleFactory {
    function createEscrow(
        address token,
        uint256 amount,
        address recipient,
        bytes32 hashlock,
        uint256 refundTime
    ) external override returns (address escrow) {
        // Simple validation
        require(token != address(0), "Invalid token");
        require(recipient != address(0), "Invalid recipient");
        require(amount > 0, "Invalid amount");
        require(refundTime > block.timestamp, "Invalid refund time");
        
        // Deploy new escrow
        escrow = address(new SimpleEscrow(
            token,
            msg.sender,
            recipient,
            amount,
            hashlock,
            refundTime
        ));
        
        emit EscrowCreated(
            escrow,
            msg.sender,
            recipient,
            token,
            amount,
            hashlock
        );
        
        return escrow;
    }
    
    function computeEscrowAddress(
        address creator,
        address token,
        uint256 amount,
        address recipient,
        bytes32 hashlock
    ) external view override returns (address) {
        // Simple CREATE2 calculation
        bytes32 salt = keccak256(abi.encode(
            creator,
            token,
            amount,
            recipient,
            hashlock
        ));
        
        bytes memory bytecode = type(SimpleEscrow).creationCode;
        bytes32 hash = keccak256(abi.encodePacked(
            bytes1(0xff),
            address(this),
            salt,
            keccak256(bytecode)
        ));
        
        return address(uint160(uint256(hash)));
    }
}
```

## Usage Example

```solidity
// Step 1: Alice creates secret
bytes32 secret = keccak256(abi.encode("my_secret", block.timestamp));
bytes32 hashlock = keccak256(abi.encode(secret));

// Step 2: Alice approves and creates escrow on Chain A
tokenA.approve(address(factory), 100 ether);
address escrowA = factory.createEscrow(
    address(tokenA),
    100 ether,
    bob,
    hashlock,
    block.timestamp + 1 hours
);

// Step 3: Bob creates matching escrow on Chain B
tokenB.approve(address(factory), 50 ether);
address escrowB = factory.createEscrow(
    address(tokenB),
    50 ether,
    alice,
    hashlock,
    block.timestamp + 30 minutes
);

// Step 4: Bob withdraws on Chain A (reveals secret)
ISimpleEscrow(escrowA).withdraw(secret);

// Step 5: Alice withdraws on Chain B (uses revealed secret)
ISimpleEscrow(escrowB).withdraw(secret);
```

## Key Differences from Original

### 1. No Custom Types
- ❌ No `Address` wrapper type
- ❌ No `Timelocks` packed struct
- ❌ No `MakerTraits` encoding
- ✅ Just standard Solidity types

### 2. No Complex Libraries
- ❌ No TimelocksLib
- ❌ No ImmutablesLib
- ❌ No ProxyHashLib
- ✅ Simple, readable code

### 3. No External Dependencies
- ❌ No Limit Order Protocol
- ❌ No OpenZeppelin upgrades
- ❌ No solidity-utils
- ✅ Minimal imports

### 4. Clear State Machine
```
Created → Funded → Withdrawn
                 ↘ Refunded
```

## Testing Interface

```solidity
interface ISimpleTest {
    function testCompleteSwap() external;
    function testRefundAfterTimeout() external;
    function testInvalidSecret() external;
}
```

## Events for Monitoring

All events use indexed parameters for efficient filtering:

```solidity
event EscrowCreated(address indexed escrow, ...);
event Withdrawn(address indexed recipient, bytes32 secret);
event Refunded(address indexed creator);
```

## Security Considerations

1. **Reentrancy**: Use checks-effects-interactions pattern
2. **Time Manipulation**: Miners can manipulate ±15 seconds
3. **Front-running**: Secret revelation is public
4. **Token Standards**: Assume standard ERC20 behavior

## Gas Optimization

1. Use `immutable` for all constructor parameters
2. Pack `bool` values if adding more state
3. Minimal external calls
4. No dynamic arrays or strings

This minimal interface provides everything needed for atomic swaps without unnecessary complexity.