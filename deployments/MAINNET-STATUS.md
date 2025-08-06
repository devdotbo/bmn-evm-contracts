# BMN Protocol Mainnet Deployment Status

## [SUCCESS] Escrow Implementations Deployed

### Base Mainnet (Chain ID: 8453)
- **EscrowSrc**: `0x06688B1f62Afa1373A255bA7627072DC01aB8125` [DEPLOYED]
- **EscrowDst**: `0x5bEE2B5f8652eB2567b35A6AcdaC6F048A02c9dE` [DEPLOYED]
- **Deployer**: `0x5f29827e25dc174a6A51C99e6811Bbd7581285b0`
- **BMN Token**: `0x8287CD2aC7E227D9D927F998EB600a0683a832A1`
- **Status**: LIVE ON MAINNET

### Optimism Mainnet (Chain ID: 10)
- **EscrowSrc**: `0x06688B1f62Afa1373A255bA7627072DC01aB8125` [DEPLOYED]
- **EscrowDst**: `0x5bEE2B5f8652eB2567b35A6AcdaC6F048A02c9dE` [DEPLOYED]
- **Deployer**: `0x5f29827e25dc174a6A51C99e6811Bbd7581285b0`
- **BMN Token**: `0x8287CD2aC7E227D9D927F998EB600a0683a832A1`
- **Status**: LIVE ON MAINNET

## Factory Deployment Issue

The factory contracts (CrossChainEscrowFactory, SimplifiedCrossChainEscrowFactory) are failing to deploy due to bytecode validation in their constructors. The constructors verify that the implementation bytecode matches expected values, which is failing.

### Potential Factory Addresses (Not Yet Deployed)
- **CrossChainEscrowFactory**: `0xC12F21a3CbAA2FADD8F76c9addEF4a6D8D02BeF0`
- **SimplifiedFactory**: `0xbD76CB7e2eA55945784Dead88EeA53b639C5F4A6`

## Next Steps

The core escrow implementations are successfully deployed on both Base and Optimism mainnets with deterministic addresses via CREATE3. These can be used directly or through a simplified factory contract without bytecode validation.

### Direct Usage
The EscrowSrc and EscrowDst contracts can be used directly by creating minimal proxy clones pointing to these implementations.

### Transaction Hashes
- Base deployment: See `/broadcast/DeployStep1Implementations.s.sol/8453/run-latest.json`
- Optimism deployment: See `/broadcast/DeployStep1Implementations.s.sol/10/run-latest.json`

## Verification Commands

To verify deployment status:
```bash
forge script script/CheckMainnetDeployment.s.sol --rpc-url https://mainnet.base.org
forge script script/CheckMainnetDeployment.s.sol --rpc-url https://mainnet.optimism.io
```