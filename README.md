# Bridge-Me-Not

A trustless cross-chain atomic swap protocol that eliminates traditional bridge risks by using hash timelock contracts (HTLC) and deterministic escrow addresses.

## 🌉 No Bridge, No Problem

Bridge-Me-Not implements atomic swaps without requiring users to trust a bridge or intermediary. Using simplified contracts from 1inch's cross-chain-swap infrastructure, it enables secure token exchanges across EVM chains.

## ✨ Key Features

- **Truly Atomic**: Either both parties receive their tokens, or the swap is cancelled
- **No Bridge Risk**: No wrapped tokens, no bridge custody, no bridge fees
- **Deterministic Addresses**: Escrow addresses are computed before deployment
- **Timelock Protection**: Built-in safeguards with customizable time windows
- **Merkle Proof Support**: Efficient batch operations for multiple swaps
- **Emergency Recovery**: Rescue functions for stuck funds after timeout

## 🏗️ Architecture Overview

```
Chain A (Source)                        Chain B (Destination)
┌─────────────┐                        ┌─────────────┐
│   User A    │                        │   User B    │
└──────┬──────┘                        └──────┬──────┘
       │ 1. Lock tokens                        │ 2. Lock tokens
       ▼                                       ▼
┌─────────────┐                        ┌─────────────┐
│  EscrowSrc  │◄──────────────────────►│  EscrowDst  │
└─────────────┘   3. Reveal secret     └─────────────┘
       │                                       │
       │ 4. Withdraw with secret              │
       ▼                                       ▼
┌─────────────┐                        ┌─────────────┐
│   User B    │                        │   User A    │
└─────────────┘                        └─────────────┘
```

## 🚀 Quick Start

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- Node.js 16+ (for resolver scripts)
- Git

### Installation

```bash
# Clone the repository
git clone <your-repo-url>
cd bridge-me-not/bmn-evm-contracts

# Install dependencies
forge install

# Build contracts
forge build
```

### Run Local Test Environment

```bash
# Start two local chains
./scripts/multi-chain-setup.sh

# In another terminal, run the resolver
node scripts/resolver.js
```

## 📁 Project Structure

```
bmn-evm-contracts/
├── contracts/
│   ├── EscrowFactory.sol      # Deploys escrows with deterministic addresses
│   ├── EscrowSrc.sol          # Source chain escrow (locks user tokens)
│   ├── EscrowDst.sol          # Destination chain escrow (locks resolver tokens)
│   ├── BaseEscrow.sol         # Shared escrow functionality
│   ├── interfaces/            # Contract interfaces
│   ├── libraries/             # Timelock and proxy libraries
│   └── mocks/                 # Test contracts
├── script/
│   └── LocalDeploy.s.sol      # Local deployment script
├── scripts/
│   ├── multi-chain-setup.sh   # Starts dual Anvil chains
│   └── resolver.js            # Example resolver implementation
└── test/
    └── CrossChainHelper.sol   # Test utilities
```

## 🔧 How It Works

### 1. Order Creation
User A creates a swap order specifying:
- Source token and amount
- Destination token and amount
- Timelock parameters
- Secret hash (hashlock)

### 2. Source Chain Lock
User A locks tokens in `EscrowSrc` with:
- Hashlock for atomic execution
- Timelock for cancellation window
- Deterministic destination address

### 3. Destination Chain Execution
Resolver (User B) deploys `EscrowDst` and locks tokens:
- Matches the order parameters
- Uses same hashlock
- Provides safety deposit

### 4. Secret Reveal
When resolver reveals the secret:
- User A can claim on destination chain
- Resolver can claim on source chain
- Both happen atomically

### 5. Cancellation Window
If swap doesn't complete:
- After timelock, users can cancel
- Funds return to original owners
- Safety deposits are refunded

## 🛠️ Development

### Build
```bash
forge build
```

### Test
```bash
forge test
```

### Deploy
```bash
# Set your private key
export PRIVATE_KEY=0x...

# Deploy to local chain
forge script script/LocalDeploy.s.sol --rpc-url http://localhost:8545 --broadcast
```

### Key Configuration

The protocol uses several time windows:
- **Withdrawal Period**: Time to complete the swap
- **Public Withdrawal**: Anyone can trigger withdrawal
- **Cancellation Period**: Time to cancel if swap fails
- **Rescue Delay**: Emergency fund recovery

## 🎯 Hackathon Usage

### Quick Modifications

1. **Adjust Timelocks** (for faster demos):
```solidity
// In deployment, use shorter windows
uint32 rescueDelay = 300; // 5 minutes instead of days
```

2. **Add Custom Tokens**:
```solidity
// Deploy your own tokens in LocalDeploy.s.sol
TokenMock gameToken = new TokenMock("Game Token", "GAME");
```

3. **Modify Resolver Logic**:
- Edit `scripts/resolver.js` for custom matching
- Add profit calculations
- Implement batch operations

### Testing Strategy

1. Deploy on two local chains
2. Use test accounts with pre-funded tokens
3. Execute swaps with short timelocks
4. Demonstrate cancellation flows

## 🔐 Security Considerations

- Contracts are simplified from 1inch's audited codebase
- Always verify hashlock before revealing secrets
- Monitor timelock windows carefully
- Use safety deposits to prevent griefing

## 📄 License

MIT License - see LICENSE file

## 🙏 Credits

- Based on [1inch cross-chain-swap](https://github.com/1inch/cross-chain-swap) contracts
- Simplified for hackathon usage
- Security contact: security@1inch.io (for original contracts)

## 🚧 Disclaimer

This is a hackathon project using simplified contracts. For production use, please refer to the full 1inch implementation and conduct proper audits.

---

Built for trustless cross-chain swaps 🔄