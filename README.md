# Bridge-Me-Not

Atomic swap implementation based on simplified contracts from 1inch cross-chain-swap. This repository contains the EVM smart contracts for secure cross-chain token swaps without traditional bridges.

## Project Structure

```
bmn-evm-contracts/
├── contracts/
│   ├── BaseEscrow.sol          # Base functionality for escrow contracts
│   ├── BaseEscrowFactory.sol   # Base factory implementation
│   ├── Escrow.sol              # Main escrow contract logic
│   ├── EscrowDst.sol           # Destination chain escrow
│   ├── EscrowSrc.sol           # Source chain escrow
│   ├── EscrowFactory.sol       # Factory for deploying escrows
│   ├── EscrowFactoryContext.sol # Factory context management
│   ├── MerkleStorageInvalidator.sol # Merkle proof invalidation
│   ├── interfaces/             # Contract interfaces
│   ├── libraries/              # Supporting libraries
│   └── mocks/                  # Mock contracts for testing
├── script/                     # Deployment scripts
├── scripts/                    # Utility scripts
└── test/                       # Test files
```

## Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- Node.js (for resolver scripts)
- Git

## Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd bmn-evm-contracts
```

2. Install dependencies:
```bash
forge install foundry-rs/forge-std
forge install OpenZeppelin/openzeppelin-contracts
forge install 1inch/solidity-utils
forge install 1inch/limit-order-protocol
forge install 1inch/limit-order-settlement
forge install dmfxyz/murky
```

3. Verify installation:
```bash
forge build
```

## Quick Start

### 1. Start Multi-Chain Environment

```bash
chmod +x scripts/multi-chain-setup.sh
./scripts/multi-chain-setup.sh
```

This starts two local chains:
- Chain A (Source) on port 8545
- Chain B (Destination) on port 8546

### 2. Deploy Contracts

The multi-chain setup script automatically deploys contracts on both chains using the LocalDeploy script.

### 3. Run Resolver (Optional)

In a new terminal:
```bash
node scripts/resolver.js
```

## Architecture Overview

The Bridge-Me-Not system implements atomic swaps through a series of escrow contracts:

1. **Order Creation**: Users create orders on the source chain specifying the tokens to swap
2. **Escrow Locking**: Tokens are locked in EscrowSrc on the source chain
3. **Cross-Chain Execution**: Resolvers execute corresponding orders on the destination chain
4. **Secret Reveal**: Upon successful execution, secrets are revealed enabling claim
5. **Atomic Completion**: Both parties can claim their tokens using revealed secrets

### Key Components

- **Limit Order Protocol**: Provides the order matching infrastructure
- **Timelocks**: Ensure atomic execution within specified time windows
- **Merkle Proofs**: Enable efficient verification of cross-chain state
- **Access Control**: Token-based access control for resolver participation

## Key Contracts

### EscrowFactory
Creates and manages escrow contracts across chains. Handles deployment parameters and access control.

### EscrowSrc
Source chain escrow that:
- Locks user tokens
- Manages timelocks
- Enables refunds on timeout
- Releases tokens upon valid secret reveal

### EscrowDst
Destination chain escrow that:
- Receives resolver tokens
- Validates cross-chain proofs
- Reveals secrets upon successful execution
- Handles cancellations

### BaseEscrow
Common functionality shared between source and destination escrows including:
- Timelock management
- Secret handling
- Emergency rescue functions

## Development

### Build
```bash
forge build
```

### Test
```bash
forge test
```

### Format
```bash
forge fmt
```

### Deploy to Local Chains
```bash
PRIVATE_KEY=<your-key> forge script script/LocalDeploy.s.sol --rpc-url http://localhost:8545 --broadcast
```

## Configuration

### foundry.toml
The project uses optimized settings for cross-chain swap contracts:
- Optimizer runs: 1,000,000
- Via-IR: enabled
- Solidity version: 0.8.23

### Remappings
Import mappings are configured in `remappings.txt` for clean imports:
```solidity
import { EscrowFactory } from "contracts/EscrowFactory.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
```

## Scripts

### LocalDeploy.s.sol
Deploys the complete system including:
- Mock tokens for testing
- Limit Order Protocol
- Escrow Factory
- Initial token distribution to test accounts

### multi-chain-setup.sh
Automated script that:
- Starts two Anvil instances
- Deploys contracts on both chains
- Sets up test accounts with tokens
- Provides resolver setup

## License

See LICENSE file for details.