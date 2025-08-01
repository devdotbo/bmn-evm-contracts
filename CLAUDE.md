# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Essential Commands

### Build and Compilation
```bash
forge build              # Build all contracts
forge build --sizes      # Build with contract size information
forge clean             # Clean build artifacts
```

### Testing
```bash
forge test              # Run all tests
forge test -vvv         # Run tests with detailed output
forge test --match-test <TestName>    # Run specific test
forge test --match-contract <Contract> # Test specific contract
forge coverage          # Generate coverage report
```

### Code Quality
```bash
forge fmt               # Format code
forge fmt --check       # Check formatting without changes
```

### Local Development
```bash
# Start multi-chain test environment (2 Anvil instances)
./scripts/multi-chain-setup.sh

# Deploy to local chain
PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
forge script script/LocalDeploy.s.sol --rpc-url http://localhost:8545 --broadcast

# Run resolver (in separate terminal)
node scripts/resolver.js
```

## Architecture Overview

This is a cross-chain atomic swap protocol implementing Hash Timelock Contracts (HTLC) without bridges. The system uses deterministic escrow addresses and timelocks to ensure atomicity.

### Core Flow
1. **Order Creation**: User creates order with hashlock on source chain
2. **Source Lock**: Tokens locked in `EscrowSrc` with timelocks
3. **Destination Lock**: Resolver deploys `EscrowDst` and locks tokens
4. **Secret Reveal**: Resolver reveals secret, enabling both parties to claim
5. **Atomic Completion**: Both withdrawals happen or neither does

### Key Contracts

**EscrowFactory** (`contracts/EscrowFactory.sol`)
- Deploys escrows with deterministic addresses using CREATE2
- Inherits from BaseEscrowFactory and resolver validation extensions
- Manages both source and destination implementations

**EscrowSrc** (`contracts/EscrowSrc.sol`)
- Locks maker's tokens on source chain
- Withdrawable by taker with valid secret during withdrawal window
- Cancellable by maker after cancellation timelock

**EscrowDst** (`contracts/EscrowDst.sol`)
- Locks resolver's tokens on destination chain
- Reveals secret when maker withdraws
- Includes safety deposit mechanism

**BaseEscrow** (`contracts/BaseEscrow.sol`)
- Common functionality for both escrow types
- Manages timelocks, secrets, and rescue operations

### Timelock System

Timelocks are packed into a single uint256 with stages:
- **SrcWithdrawal**: Taker-only withdrawal period
- **SrcPublicWithdrawal**: Anyone can trigger withdrawal
- **SrcCancellation**: Maker can cancel
- **SrcPublicCancellation**: Anyone can cancel
- **DstWithdrawal/DstCancellation**: Similar for destination chain

### Libraries

**TimelocksLib** (`contracts/libraries/TimelocksLib.sol`)
- Packs/unpacks timelock stages into uint256
- Calculates period starts from deployment timestamp

**ImmutablesLib** (`contracts/libraries/ImmutablesLib.sol`)
- Validates and hashes escrow immutable parameters
- Used for deterministic address calculation

**ProxyHashLib** (`contracts/libraries/ProxyHashLib.sol`)
- Computes bytecode hash for CREATE2 deployment

## Contract Interactions

### Deployment Pattern
1. Factory stores implementation addresses
2. Uses minimal proxy pattern for gas efficiency
3. CREATE2 ensures deterministic addresses across chains

### Secret Management
- Hashlock set at order creation
- Secret revealed on destination chain withdrawal
- Secret enables source chain withdrawal
- Invalid secret prevents any withdrawal

### Safety Mechanisms
- Safety deposits prevent griefing
- Rescue delay (configurable) for stuck funds
- Access token for resolver participation
- Timelocks ensure fair cancellation windows

## Configuration

**Solidity Version**: 0.8.23
**Optimizer**: Enabled with 1,000,000 runs
**Via-IR**: Enabled for better optimization

## Key Test Accounts (Anvil)
- Deployer: `0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266`
- Alice (Account 1): `0x70997970C51812dc3A010C7d01b50e0d17dc79C8`
- Bob/Resolver (Account 2): `0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC`