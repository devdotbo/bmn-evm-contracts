# Step-by-Step Implementation Guide for Simplified Atomic Swap

## Prerequisites

- Solidity 0.8.0 or higher
- Hardhat or Foundry for development
- Two test networks (or local chains)
- Basic understanding of Hash Timelock Contracts (HTLC)

## Step 1: Project Setup

### Create New Project

```bash
mkdir simple-atomic-swap
cd simple-atomic-swap
forge init --no-git
```

### Project Structure

```
simple-atomic-swap/
├── src/
│   ├── SimpleEscrow.sol
│   ├── SimpleFactory.sol
│   └── interfaces/
│       ├── ISimpleEscrow.sol
│       └── ISimpleFactory.sol
├── test/
│   └── SimpleAtomicSwap.t.sol
├── script/
│   ├── Deploy.s.sol
│   └── TestSwap.s.sol
└── foundry.toml
```

## Step 2: Implement Core Contracts

### 2.1 Create Token Interface

```solidity
// src/interfaces/IToken.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IToken {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}
```

### 2.2 Implement SimpleEscrow

```solidity
// src/SimpleEscrow.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/IToken.sol";

contract SimpleEscrow {
    // State variables
    address public immutable token;
    address public immutable creator;
    address public immutable recipient;
    uint256 public immutable amount;
    bytes32 public immutable hashlock;
    uint256 public immutable refundTime;
    
    bool public withdrawn;
    bool public refunded;
    
    // Events
    event Withdrawn(address recipient, bytes32 secret);
    event Refunded(address creator);
    
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
    }
    
    function withdraw(bytes32 secret) external {
        require(!withdrawn && !refunded, "Already completed");
        require(keccak256(abi.encode(secret)) == hashlock, "Invalid secret");
        
        withdrawn = true;
        IToken(token).transfer(recipient, amount);
        
        emit Withdrawn(recipient, secret);
    }
    
    function refund() external {
        require(!withdrawn && !refunded, "Already completed");
        require(block.timestamp >= refundTime, "Too early");
        require(msg.sender == creator, "Only creator");
        
        refunded = true;
        IToken(token).transfer(creator, amount);
        
        emit Refunded(creator);
    }
}
```

### 2.3 Implement SimpleFactory

```solidity
// src/SimpleFactory.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./SimpleEscrow.sol";

contract SimpleFactory {
    event EscrowCreated(address escrow, address creator, address recipient);
    
    function createEscrow(
        address token,
        uint256 amount,
        address recipient,
        bytes32 hashlock,
        uint256 refundTime
    ) external returns (address) {
        SimpleEscrow escrow = new SimpleEscrow(
            token,
            msg.sender,
            recipient,
            amount,
            hashlock,
            refundTime
        );
        
        emit EscrowCreated(address(escrow), msg.sender, recipient);
        return address(escrow);
    }
}
```

## Step 3: Write Tests

### 3.1 Basic Test Setup

```solidity
// test/SimpleAtomicSwap.t.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/SimpleFactory.sol";
import "../src/SimpleEscrow.sol";

contract MockToken {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    
    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
    }
    
    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }
    
    function transfer(address to, uint256 amount) external returns (bool) {
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }
    
    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        require(balanceOf[from] >= amount, "Insufficient balance");
        require(allowance[from][msg.sender] >= amount, "Insufficient allowance");
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        allowance[from][msg.sender] -= amount;
        return true;
    }
}

contract SimpleAtomicSwapTest is Test {
    SimpleFactory factory;
    MockToken tokenA;
    MockToken tokenB;
    
    address alice = address(0x1);
    address bob = address(0x2);
    
    bytes32 secret = keccak256("test_secret");
    bytes32 hashlock;
    
    function setUp() public {
        factory = new SimpleFactory();
        tokenA = new MockToken();
        tokenB = new MockToken();
        
        hashlock = keccak256(abi.encode(secret));
        
        // Fund accounts
        tokenA.mint(alice, 1000e18);
        tokenB.mint(bob, 1000e18);
    }
    
    function testSuccessfulSwap() public {
        // Alice creates escrow on Chain A
        vm.startPrank(alice);
        tokenA.approve(address(factory), 100e18);
        address escrowA = factory.createEscrow(
            address(tokenA),
            100e18,
            bob,
            hashlock,
            block.timestamp + 1 hours
        );
        vm.stopPrank();
        
        // Bob creates escrow on Chain B
        vm.startPrank(bob);
        tokenB.approve(address(factory), 50e18);
        address escrowB = factory.createEscrow(
            address(tokenB),
            50e18,
            alice,
            hashlock,
            block.timestamp + 30 minutes
        );
        
        // Bob withdraws from escrow A
        SimpleEscrow(escrowA).withdraw(secret);
        vm.stopPrank();
        
        // Alice withdraws from escrow B
        vm.prank(alice);
        SimpleEscrow(escrowB).withdraw(secret);
        
        // Verify final balances
        assertEq(tokenA.balanceOf(alice), 900e18);
        assertEq(tokenA.balanceOf(bob), 100e18);
        assertEq(tokenB.balanceOf(alice), 50e18);
        assertEq(tokenB.balanceOf(bob), 950e18);
    }
}
```

## Step 4: Deployment Script

```solidity
// script/Deploy.s.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/SimpleFactory.sol";

contract Deploy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        
        SimpleFactory factory = new SimpleFactory();
        
        console.log("Factory deployed at:", address(factory));
        
        vm.stopBroadcast();
    }
}
```

## Step 5: Cross-Chain Test Script

### 5.1 JavaScript Test Script (Recommended)

```javascript
// scripts/test-swap.js
const { ethers } = require("ethers");

async function testCrossChainSwap() {
    // Setup providers
    const providerA = new ethers.JsonRpcProvider("http://localhost:8545");
    const providerB = new ethers.JsonRpcProvider("http://localhost:8546");
    
    // Setup signers
    const alice = new ethers.Wallet(process.env.ALICE_KEY, providerA);
    const bob = new ethers.Wallet(process.env.BOB_KEY, providerB);
    
    // Contract addresses (from deployment)
    const factoryA = "0x...";
    const factoryB = "0x...";
    const tokenA = "0x...";
    const tokenB = "0x...";
    
    // Create secret
    const secret = ethers.randomBytes(32);
    const hashlock = ethers.keccak256(secret);
    
    // Step 1: Alice creates escrow on Chain A
    console.log("Alice creating escrow on Chain A...");
    const txA = await factoryA.connect(alice).createEscrow(
        tokenA,
        ethers.parseEther("100"),
        bob.address,
        hashlock,
        Math.floor(Date.now() / 1000) + 3600
    );
    const receiptA = await txA.wait();
    const escrowA = receiptA.logs[0].args.escrow;
    
    // Step 2: Bob creates escrow on Chain B
    console.log("Bob creating escrow on Chain B...");
    const txB = await factoryB.connect(bob).createEscrow(
        tokenB,
        ethers.parseEther("50"),
        alice.address,
        hashlock,
        Math.floor(Date.now() / 1000) + 1800
    );
    const receiptB = await txB.wait();
    const escrowB = receiptB.logs[0].args.escrow;
    
    // Step 3: Bob withdraws on Chain A
    console.log("Bob withdrawing on Chain A...");
    await escrowA.connect(bob).withdraw(secret);
    
    // Step 4: Alice withdraws on Chain B
    console.log("Alice withdrawing on Chain B...");
    await escrowB.connect(alice).withdraw(secret);
    
    console.log("Swap completed successfully!");
}
```

## Step 6: Local Testing Setup

### 6.1 Start Two Anvil Instances

```bash
# Terminal 1 - Chain A
anvil --port 8545 --chain-id 1337

# Terminal 2 - Chain B  
anvil --port 8546 --chain-id 1338
```

### 6.2 Deploy Contracts

```bash
# Deploy to Chain A
forge script script/Deploy.s.sol --rpc-url http://localhost:8545 --broadcast

# Deploy to Chain B
forge script script/Deploy.s.sol --rpc-url http://localhost:8546 --broadcast
```

### 6.3 Fund Test Accounts

```bash
# Use cast to mint tokens or deploy mock tokens with mint function
```

## Step 7: Common Issues and Solutions

### Issue 1: Timestamp Synchronization

**Problem**: Chain timestamps differ
**Solution**: Add tolerance or use block numbers

```solidity
// Add 5 minute tolerance
require(block.timestamp >= refundTime - 300, "Too early");
```

### Issue 2: Gas Estimation

**Problem**: CREATE2 gas estimation fails
**Solution**: Use simple CREATE instead

```solidity
// Instead of CREATE2
SimpleEscrow escrow = new SimpleEscrow(...);
```

### Issue 3: Token Approval

**Problem**: Forgot to approve tokens
**Solution**: Always check allowance first

```solidity
require(token.allowance(creator, address(this)) >= amount, "Approve tokens first");
```

## Step 8: Production Considerations

### 8.1 Add Safety Features

```solidity
// Add minimum timelock
require(refundTime >= block.timestamp + 300, "Timelock too short");

// Add maximum amount check
require(amount <= 10000e18, "Amount too large");
```

### 8.2 Gas Optimizations

```solidity
// Use custom errors instead of strings
error AlreadyCompleted();
error InvalidSecret();
error TooEarly();

// Replace requires
if (withdrawn || refunded) revert AlreadyCompleted();
```

### 8.3 Event Monitoring

```javascript
// Monitor for withdrawals
escrow.on("Withdrawn", (recipient, secret) => {
    console.log(`Withdrawn by ${recipient}, secret: ${secret}`);
    // Trigger Chain B withdrawal
});
```

## Step 9: Testing Checklist

- [ ] Test successful swap
- [ ] Test refund after timeout
- [ ] Test invalid secret rejection
- [ ] Test early refund rejection
- [ ] Test double-spend prevention
- [ ] Test with different token amounts
- [ ] Test with very short timelocks
- [ ] Test with very long timelocks

## Step 10: Deployment Checklist

- [ ] Deploy factories to both chains
- [ ] Verify contracts on explorer
- [ ] Document factory addresses
- [ ] Create user documentation
- [ ] Set up monitoring
- [ ] Test with small amounts first
- [ ] Have emergency pause plan

## Conclusion

This simplified implementation:
- Reduces complexity by 90%
- Maintains atomic swap security
- Easy to test and deploy
- Clear upgrade path

Start with this simple version and add features only as needed. Most use cases don't need the complexity of the full protocol.