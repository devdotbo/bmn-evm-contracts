# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## ⚠️ SECURITY WARNING

**NEVER commit sensitive data to the repository!**

- Private keys, API keys, passwords, and secrets must ALWAYS be stored in `.env` files
- Use `.env.example` files with placeholder values to document required environment variables
- Ensure `.env` is in `.gitignore` (already configured)
- All scripts should read sensitive data from environment variables, not hardcoded values
- Even test/development keys should follow this practice to maintain good security habits

## Important Instructions

**ALWAYS source .env before running forge commands.** All forge commands should be prefixed with `source .env &&` to ensure environment variables are loaded.

**ALWAYS commit changes immediately after making them, one file at a time.** This ensures clean commit history and prevents loss of work.

**NEVER use emojis in code, commit messages, or any files.** Emojis cause compilation errors and should be replaced with text alternatives like [OK], [ERROR], [WARNING], etc.

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

# Live chain testing (affects real balances)
./scripts/test-live-swap.sh    # Run full cross-chain swap test on live chains
./scripts/test-live-chains.sh  # Run fork-based test (doesn't affect real balances)
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

# Deploy to local chain (ensure .env file exists with DEPLOYER_PRIVATE_KEY)
source .env && forge script script/LocalDeploy.s.sol --rpc-url http://localhost:8545 --broadcast --private-key $DEPLOYER_PRIVATE_KEY

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
3. CREATE3 ensures deterministic addresses across chains (bytecode-independent)

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
- Timestamp tolerance (5 minutes) handles chain timestamp drift

## Configuration

**Solidity Version**: 0.8.23
**Optimizer**: Enabled with 1,000,000 runs
**Via-IR**: Enabled for better optimization
**EVM Version**: cancun (required for CREATE3)

## CREATE3 Deployment

**CREATE3 Factory**: `0x7B9e9BE124C5A0E239E04fDC93b66ead4e8C669d` (shared across Base and Etherlink)

### Production Deployments

**Main Protocol Contracts**:
- EscrowSrc: `0x77CC1A51dC5855bcF0d9f1c1FceaeE7fb855a535`
- EscrowDst: `0x36938b7899A17362520AA741C0E0dA0c8EfE5e3b`
- CrossChainEscrowFactory: `0x75ee15F6BfDd06Aee499ed95e8D92a114659f4d1`

**Resolver Infrastructure**:
- Resolver Factory: `0xe767202fD26104267CFD8bD8cfBd1A44450DC343`

### Deployment Commands
```bash
# Deploy main contracts
source .env && forge script script/DeployWithCREATE3.s.sol --rpc-url $BASE_RPC_URL --broadcast
source .env && forge script script/DeployWithCREATE3.s.sol --rpc-url $ETHERLINK_RPC_URL --broadcast

# Deploy resolver infrastructure
source .env && forge script script/DeployResolverCREATE3.s.sol --rpc-url $BASE_RPC_URL --broadcast
source .env && forge script script/DeployResolverCREATE3.s.sol --rpc-url $ETHERLINK_RPC_URL --broadcast
```

## Key Test Accounts (Anvil)
- Deployer: `0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266`
- Alice (Account 1): `0x70997970C51812dc3A010C7d01b50e0d17dc79C8`
- Bob/Resolver (Account 2): `0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC`

## Related Projects

### bmn-evm-resolver
The resolver implementation is in a separate Deno/TypeScript project at `../bmn-evm-resolver`.

Key components:
- **Contract ABIs**: Copied from `out/` after building
- **Chain Configuration**: Local Anvil instances on ports 8545 (Chain A) and 8546 (Chain B)
- **Implementation**: Bob (resolver) monitors orders and executes swaps, Alice (test client) creates orders

### Building for Resolver
When contracts are updated:
1. Run `forge build` to generate new ABIs
2. Copy required ABIs to resolver: `cp out/<Contract>.sol/<Contract>.json ../bmn-evm-resolver/abis/`
3. Key ABIs needed: EscrowFactory, EscrowSrc, EscrowDst, TokenMock, LimitOrderProtocol, IERC20

### TestEscrowFactory for Development
For local testing, we deploy `TestEscrowFactory` instead of the regular `EscrowFactory`:
- Allows direct source escrow creation without going through the limit order protocol
- Useful for testing escrow functionality in isolation
- **DO NOT USE IN PRODUCTION** - bypasses security checks
- Deployed automatically by `LocalDeploy.s.sol` for local chains

## Known Issues

### Missing Dependencies
Some 1inch dependencies are not in the submodules. Temporary stub files were created:
- `lib/limit-order-settlement/contracts/extensions/BaseExtension.sol`
- `lib/limit-order-settlement/contracts/extensions/ResolverValidationExtension.sol`

These are minimal implementations for compilation. For production, use proper 1inch implementations.

### Test Script Comparison

**Live Chain Tests** (`test-live-swap.sh` + `LiveTestChains.s.sol`):
- Affects real chain balances
- Uses direct RPC connections without forks
- Best for testing actual protocol behavior
- Requires running Anvil chains via mprocs

**Fork-based Tests** (`test-live-chains.sh` + `TestLiveChains.s.sol`):
- Uses Forge's fork functionality 
- Does not affect real chain balances
- Isolated test environment
- Good for development/debugging

### Expected Test Warnings
When running cross-chain tests, you may see these warnings which are expected and can be ignored:

1. **"Multi chain deployment is still under development"** - Informational warning from Forge about multi-chain features
2. **"Script contains transaction to address without code"** - Expected behavior when pre-funding escrow addresses before deployment
3. **"IO error: not a terminal"** - Occurs when Forge runs in non-interactive script mode
4. **"Warning: EIP-3855 is not supported"** - Occurs if chains don't have `--hardfork shanghai` enabled

The test scripts are configured to suppress or filter these warnings while keeping important error messages visible.

### Timestamp Tolerance

The protocol includes a 5-minute timestamp tolerance to handle chain timestamp drift:
- Multiple Anvil instances may have different timestamps
- Production chains can have minor timestamp variations
- The tolerance is implemented in `BaseEscrowFactory.sol` as `TIMESTAMP_TOLERANCE = 300 seconds`
- This prevents `InvalidCreationTime` errors while maintaining security

### Troubleshooting Token Balance Issues

If running test scripts doesn't change token balances as expected:

#### 1. Verify Script Selection
- Use `test-live-swap.sh` (affects real chains) not `test-live-chains.sh` (uses forks)
- Fork-based tests create isolated environments that don't affect actual chain state

#### 2. Check Prerequisites
```bash
# Verify chains are running
nc -z localhost 8545 && nc -z localhost 8546

# Check deployments exist
ls -la deployments/

# Verify initial token balances
./scripts/check-deployment.sh
```

#### 3. Debug with Enhanced Scripts
```bash
# Run with full error visibility
VERBOSE=true ./scripts/test-live-swap.sh

# Use debug version with extensive logging
./scripts/test-live-swap-debug.sh

# Test individual steps
./scripts/test-single-step.sh create-order
./scripts/test-single-step.sh check-balances
```

#### 4. Common Issues and Solutions
- **Silent transaction failures**: Use VERBOSE=true to see full output
- **Account funding**: Ensure Alice has TKA on Chain A, Bob has TKB on Chain B
- **Gas issues**: Check accounts have sufficient ETH for transactions
- **Chain connectivity**: Verify both Anvil instances are running with correct hardfork
- **State file corruption**: Delete `deployments/test-state.json` and restart

#### 5. Expected Balance Changes
```
Initial:  Alice: 1000 TKA, 100 TKB | Bob: 500 TKA, 1000 TKB
Final:    Alice: 990 TKA, 110 TKB  | Bob: 510 TKA, 990 TKB
```

If balances don't change, the issue is likely with transaction broadcasting or escrow logic.