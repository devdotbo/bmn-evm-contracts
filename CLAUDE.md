# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## ⛔ ATTENTION CLAUDE CODE: Security Protocol

**I MUST follow these rules to prevent security breaches:**

1. **NEVER write actual API keys, tokens, or secrets** - even if provided by the user
2. **ALWAYS replace secrets with placeholders** before writing to ANY file
3. **DETECT and SANITIZE** all RPC URLs and connection strings
4. **REFUSE to commit** if any actual secrets are detected
5. **WARN the user** whenever I detect and replace a potential secret

**Pattern Recognition - I will detect and replace:**
- Any string that looks like an API key (20+ alphanumeric characters after 'key', 'token', 'secret')
- RPC URLs with embedded keys (e.g., `https://provider.com/network/actualkey123`)
- Private keys (64 hex characters starting with 0x)
- Mnemonic phrases (12 or 24 word sequences)
- Database connection strings with passwords

**My Response When Detecting Secrets:**
```
⚠️ SECURITY: Detected potential secret in content.
Replacing with placeholder: YOUR_KEY_HERE
Original pattern: [first 4 chars]...[last 4 chars]
Please use environment variables instead.
```

## 🚨 CRITICAL SECURITY RULES - READ FIRST!

### ❌ NEVER COMMIT THESE (Even in Documentation!)

**API Keys & RPC Endpoints:**
- NEVER write actual API keys in ANY file (not even .md files!)
- NEVER include API keys in RPC URLs:
  - ❌ WRONG: `https://rpc.ankr.com/optimism/abc123def456ghi789jkl012mno345pqr678stu901vwx234yz`
  - ✅ RIGHT: `https://rpc.ankr.com/optimism/YOUR_API_KEY_HERE`
  - ✅ RIGHT: `https://rpc.ankr.com/optimism/$ANKR_API_KEY` (env variable)

**Private Keys & Secrets:**
- NEVER commit private keys (even test ones, except Anvil defaults)
- NEVER commit mnemonic phrases
- NEVER commit passwords or JWT tokens
- NEVER commit service account credentials

**Common Exposure Patterns to Avoid:**
```bash
# ❌ NEVER DO THIS in deployment docs:
OPTIMISM_RPC="https://lb.drpc.org/base/Xyz123Abc456Def789Ghi012Jkl"

# ✅ ALWAYS DO THIS:
OPTIMISM_RPC="https://lb.drpc.org/base/YOUR_DRPC_KEY_HERE"
OPTIMISM_RPC="https://lb.drpc.org/base/$DRPC_API_KEY"
```

### 🛡️ SAFE DOCUMENTATION PRACTICES

When documenting deployments or configurations:
1. **ALWAYS use placeholders** for sensitive values
2. **NEVER copy actual .env values** into documentation
3. **CHECK TWICE** before committing any .md file with URLs

Safe patterns for documentation:
```markdown
## Configuration
- RPC URL: `https://provider.com/network/YOUR_API_KEY`
- API Key: `YOUR_API_KEY_HERE`
- Private Key: `0xYOUR_PRIVATE_KEY_HERE`
- Contract Address: `0x1234...` (addresses are OK to share)
```

### 🔍 PRE-COMMIT SECURITY CHECKS

**Automated Pre-Commit Hook (RECOMMENDED):**

Install the automated security check that runs before every commit:
```bash
./scripts/install-pre-commit-hook.sh
```

This will automatically block commits containing:
- API keys and tokens
- RPC URLs with embedded keys
- Private keys (except Anvil defaults)
- .env files

**Manual checks before commit:**

```bash
# Quick scan for exposed secrets in staged files
git diff --cached | grep -E "(api[_-]?key|private[_-]?key|secret|password|token|bearer).*[:=].*[a-zA-Z0-9_\-]{20,}"

# Check for RPC URLs with embedded keys
git diff --cached | grep -E "https?://[^/]*(ankr|alchemy|infura|drpc|quicknode)[^/]*/[a-zA-Z0-9_\-]{20,}"

# Scan all markdown files for exposed keys (replace with your known keys)
grep -r "YOUR_KNOWN_KEY_PATTERN" --include="*.md" .
grep -r "ANOTHER_KNOWN_KEY_PATTERN" --include="*.md" .
```

### 📊 REGULAR SECURITY AUDITS

Run these commands weekly:

```bash
# Full repository scan
git log --all -p | grep -E "(api[_-]?key|secret|token|password|private[_-]?key).*=.*['\"]?[a-zA-Z0-9_\-]{20,}" | head -20

# Check current files
find . -type f \( -name "*.md" -o -name "*.txt" -o -name "*.json" \) -exec grep -l "drpc.org/[^/]*/[a-zA-Z0-9_\-]{20,}" {} \;

# Verify .env is gitignored
git check-ignore .env # Should output ".env"
```

### 🚨 EMERGENCY: If You Accidentally Commit Secrets

**IMMEDIATE ACTIONS:**
1. **DO NOT PANIC** but act quickly
2. **ROTATE THE KEY IMMEDIATELY** - assume it's compromised
3. **Clean the repository:**

```bash
# Create secrets file
echo "YOUR_EXPOSED_KEY_HERE" > secrets.txt

# Clean with BFG
git clone --mirror . ../repo-bare.git
cd ../repo-bare.git
bfg --replace-text ../your-repo/secrets.txt
git reflog expire --expire=now --all && git gc --prune=now --aggressive

# Update your repo
cd ../your-repo
git remote add cleaned ../repo-bare.git
git fetch cleaned
git reset --hard cleaned/main
git push --force-with-lease origin main
```

4. **Notify team members** to re-clone
5. **Document the incident** for learning

### 🔐 Environment Variables Best Practices

**Structure your .env files:**
```bash
# .env (NEVER COMMIT)
DRPC_API_KEY=actual_key_here
ETHERSCAN_API_KEY=actual_key_here

# .env.example (SAFE TO COMMIT)
DRPC_API_KEY=YOUR_DRPC_API_KEY_HERE
ETHERSCAN_API_KEY=YOUR_ETHERSCAN_API_KEY_HERE
```

**Always source .env before operations:**
```bash
source .env && forge script ...
```

### ⚠️ SPECIAL ATTENTION AREAS

1. **Deployment summaries** - Double-check RPC URLs
2. **Script files** - Ensure no hardcoded keys
3. **Test files** - Use only Anvil default keys
4. **JSON configs** - Often contain URLs with keys
5. **GitHub Actions** - Use secrets, never hardcode

## Important Instructions

### 🔴 CRITICAL: Security-First Development

**BEFORE WRITING ANY FILE (even documentation):**
1. **STOP and CHECK**: Am I about to write an actual API key, token, or secret?
2. **ALWAYS use placeholders**: Replace ALL real values with `YOUR_KEY_HERE` or environment variables
3. **DOUBLE-CHECK URLs**: Never paste RPC URLs directly from .env - always sanitize them first
4. **REVIEW before saving**: Re-read the file for any exposed secrets before saving

**When creating deployment documentation:**
- **NEVER copy-paste from terminal output** that might contain real keys
- **NEVER copy values from .env files** - always write placeholders
- **ALWAYS sanitize URLs** before adding them to any file:
  ```bash
  # From .env: https://rpc.provider.com/network/abc123realkey456
  # In docs:  https://rpc.provider.com/network/YOUR_API_KEY_HERE
  ```

**If Claude Code is about to write a secret:**
- I will REFUSE to write the actual secret
- I will REPLACE it with a placeholder automatically
- I will WARN you that a secret was detected and replaced

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
- v1.1.0: Enhanced events to emit escrow addresses for better tracking

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
4. Factory events emit escrow addresses (v1.1.0+) for easier tracking by resolvers

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

**CREATE3 Factory**: `0x7B9e9BE124C5A0E239E04fDC93b66ead4e8C669d` (shared across Base, Etherlink, and Optimism)

### Production Deployments

**Current Deployments (v1.1.0)**:
- BMN Token: `0x8287CD2aC7E227D9D927F998EB600a0683a832A1` (All chains)
- EscrowSrc: `0x77CC1A51dC5855bcF0d9f1c1FceaeE7fb855a535` (All chains)
- EscrowDst: `0x36938b7899A17362520AA741C0E0dA0c8EfE5e3b` (All chains)
- CrossChainEscrowFactory: `0x2B2d52Cf0080a01f457A4f64F41cbca500f787b1` (Base & Etherlink)
- CrossChainEscrowFactory: `0xB916C3edbFe574fFCBa688A6B92F72106479bD6c` (Optimism)

**Resolver Infrastructure**:
- Resolver Factory: `0xe767202fD26104267CFD8bD8cfBd1A44450DC343`

### Deployment History

**v1.1.0 (Current)**:
- CrossChainEscrowFactory: `0x2B2d52Cf0080a01f457A4f64F41cbca500f787b1`
- Enhancement: Factory events now emit escrow addresses for improved tracking

**v1.0.0 (Previous)**:
- CrossChainEscrowFactory: `0x75ee15F6BfDd06Aee499ed95e8D92a114659f4d1`
- Initial deployment without escrow address in events

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
4. Ensure resolver is configured to use the new factory address (v1.1.0): `0x2B2d52Cf0080a01f457A4f64F41cbca500f787b1`
5. The enhanced factory events include escrow addresses, simplifying resolver implementation

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