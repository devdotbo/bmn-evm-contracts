# Mainnet Cross-Chain Atomic Swap Test Plan

## Overview
Test cross-chain atomic swaps between Base (chainId: 8453) and Etherlink (chainId: 42793) with minimal safety deposits (0.00001 ETH ≈ $0.03-0.04).

## Prerequisites
1. **Environment Variables Required:**
   - `DEPLOYER_PRIVATE_KEY` - BMN deployer key with BMN tokens
   - `ALICE_PRIVATE_KEY` - Test user Alice
   - `RESOLVER_PRIVATE_KEY` - Test resolver Bob
   - `BASE_RPC_URL` - Base mainnet RPC
   - `ETHERLINK_RPC_URL` - Etherlink mainnet RPC

2. **Account Balances Needed:**
   - Deployer: ETH on both chains for deployment, BMN tokens for distribution
   - Alice: Small ETH on both chains for gas
   - Bob: Small ETH on both chains for gas + safety deposits

## Phase 1: Deploy Test Infrastructure

### Step 1.1: Deploy on Base
```bash
ACTION=deploy-base forge script script/PrepareMainnetTest.s.sol --rpc-url $BASE_RPC_URL --broadcast -vvv
```
This deploys:
- TKA token on Base
- TestEscrowFactory on Base
- Mints 100 TKA to Alice and Bob

### Step 1.2: Deploy on Etherlink
```bash
ACTION=deploy-etherlink forge script script/PrepareMainnetTest.s.sol --rpc-url $ETHERLINK_RPC_URL --broadcast -vvv
```
This deploys:
- TKB token on Etherlink
- TestEscrowFactory on Etherlink
- Mints 100 TKB to Alice and Bob

### Step 1.3: Fund Accounts on Base
```bash
ACTION=fund-accounts forge script script/PrepareMainnetTest.s.sol --rpc-url $BASE_RPC_URL --broadcast -vvv
```
This sends:
- 0.01 ETH to Alice and Bob for gas
- 10 BMN to Alice and Bob for access control

### Step 1.4: Fund Accounts on Etherlink
```bash
ACTION=fund-accounts forge script script/PrepareMainnetTest.s.sol --rpc-url $ETHERLINK_RPC_URL --broadcast -vvv
```
Same as above for Etherlink chain.

### Step 1.5: Verify Setup on Both Chains
```bash
# Check Base
ACTION=check-setup forge script script/PrepareMainnetTest.s.sol --rpc-url $BASE_RPC_URL

# Check Etherlink
ACTION=check-setup forge script script/PrepareMainnetTest.s.sol --rpc-url $ETHERLINK_RPC_URL
```

## Phase 2: Execute Cross-Chain Swap

### Step 2.1: Create Order (Base)
```bash
ACTION=create-order forge script script/LiveTestMainnet.s.sol --rpc-url $BASE_RPC_URL --broadcast -vvv
```
- Alice generates secret and hashlock
- Saves to state file

### Step 2.2: Create Source Escrow (Base)
```bash
ACTION=create-src-escrow forge script script/LiveTestMainnet.s.sol --rpc-url $BASE_RPC_URL --broadcast -vvv
```
- Alice locks 10 TKA in source escrow
- Safety deposit: 0.00001 ETH (paid by factory)

### Step 2.3: Create Destination Escrow (Etherlink)
```bash
ACTION=create-dst-escrow forge script script/LiveTestMainnet.s.sol --rpc-url $ETHERLINK_RPC_URL --broadcast -vvv
```
- Bob locks 10 TKB in destination escrow
- Bob provides safety deposit: 0.00001 ETH

### Step 2.4: Withdraw from Destination (Etherlink)
```bash
ACTION=withdraw-dst forge script script/LiveTestMainnet.s.sol --rpc-url $ETHERLINK_RPC_URL --broadcast -vvv
```
- Alice reveals secret and withdraws 10 TKB
- Secret becomes public on-chain

### Step 2.5: Withdraw from Source (Base)
```bash
ACTION=withdraw-src forge script script/LiveTestMainnet.s.sol --rpc-url $BASE_RPC_URL --broadcast -vvv
```
- Bob uses revealed secret to withdraw 10 TKA
- Completes the atomic swap

### Step 2.6: Verify Final Balances
```bash
ACTION=check-balances forge script script/LiveTestMainnet.s.sol --rpc-url $BASE_RPC_URL
```

## Expected Results

### Initial Balances:
- Alice: 100 TKA (Base), 100 TKB (Etherlink)
- Bob: 100 TKA (Base), 100 TKB (Etherlink)

### Final Balances:
- Alice: 90 TKA (Base), 110 TKB (Etherlink)
- Bob: 110 TKA (Base), 90 TKB (Etherlink)

### Gas Costs:
- Alice: ~0.001 ETH on each chain
- Bob: ~0.001 ETH + 0.00001 ETH (safety deposit) on each chain

## Safety Features
1. **Timelocks:**
   - 5 min: Public withdrawal starts
   - 15 min: Cancellation allowed
   - 20 min: Public cancellation

2. **Safety Deposits:**
   - Amount: 0.00001 ETH (~$0.03-0.04)
   - Returned on successful swap
   - Prevents griefing attacks

3. **Access Control:**
   - BMN token required for participation
   - Both Alice and Bob need BMN tokens

## Troubleshooting

### Common Issues:
1. **Insufficient ETH:** Fund accounts with more ETH
2. **Missing BMN tokens:** Run fund-accounts step
3. **Wrong chain:** Verify chainId before each step
4. **Timelock expired:** Must complete within 15 minutes

### Debug Commands:
```bash
# Check deployment files
ls -la deployments/

# View state file
cat deployments/mainnet-test-state.json

# Check specific balances
cast call <TOKEN> "balanceOf(address)" <ADDRESS> --rpc-url <RPC>
```

## Cost Summary
- Total ETH needed: ~0.025 ETH per chain
- Safety deposits: 0.00001 ETH (returned)
- Token amounts: 10 TKA <-> 10 TKB swap
- BMN required: 10 BMN per account (not consumed)