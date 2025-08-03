# BMN Protocol Mainnet Deployment

## Deployment Date: August 3, 2025

## Deployment Summary

Successfully deployed BMN Protocol contracts with **IDENTICAL ADDRESSES** on both chains using CREATE2!

### Contract Addresses (Same on Both Chains)

| Contract | Address | Purpose |
|----------|---------|---------|
| **EscrowSrc Implementation** | `0xcCF2DEd118EC06185DC99E1a42a078754ae9c84c` | Source chain escrow logic |
| **EscrowDst Implementation** | `0xb5A9FBEB81830006A9C03aBB33d02574346C5A9a` | Destination chain escrow logic |
| **CrossChainEscrowFactory** | `0xc72ed1E8a0649e51Cd046a0FfccC8f8c0bf385Fa` | Factory for creating escrows |

### Chain Details

#### Base Mainnet (Chain ID: 8453)
- RPC: https://lb.drpc.org/base/
- Block Explorer: https://basescan.org/
- Gas Used: ~3.93M gas
- Cost: ~0.0000048 ETH

#### Etherlink Mainnet (Chain ID: 42793)
- RPC: https://rpc.ankr.com/etherlink_mainnet/
- Block Explorer: https://explorer.etherlink.com/
- Gas Used: ~77.7M gas
- Cost: ~0.155 XTZ

### Deployment Method

Used CREATE2 deterministic deployment with:
- CREATE2 Factory: `0x4e59b44847b379578588920cA78FbF26c0B4956C`
- Same salts on both chains
- Same constructor arguments
- Result: Identical addresses!

### Configuration

- **Rescue Delay**: 7 days (604800 seconds)
- **Access Token**: BMN Token (`0x8287CD2aC7E227D9D927F998EB600a0683a832A1`)
- **Fee Token**: BMN Token (same as above)
- **Safety Deposit**: 0.00001 ETH

### Key Innovation

Created `CrossChainEscrowFactory` that accepts pre-deployed implementation addresses, solving the cross-chain consistency issue discovered during testing.

### Next Steps

1. Run cross-chain atomic swap test with new contracts
2. Update resolver to use new factory address
3. Test with BMN tokens on both chains

### Transaction Hashes

Check deployment transactions in:
- Base: `/broadcast/DeployBMNProtocol.s.sol/8453/run-latest.json`
- Etherlink: `/broadcast/DeployBMNProtocol.s.sol/42793/run-latest.json`