# Setting Up Test Environment

## Required Environment Variables

Before running the mainnet test, you need to set these environment variables:

```bash
# Private Keys (use test accounts only!)
export DEPLOYER_PRIVATE_KEY="your_deployer_private_key_here"
export ALICE_PRIVATE_KEY="your_alice_private_key_here"  
export RESOLVER_PRIVATE_KEY="your_bob_resolver_private_key_here"

# RPC URLs
export BASE_RPC_URL="https://mainnet.base.org"
export ETHERLINK_RPC_URL="https://node.mainnet.etherlink.com"

# Account addresses (for reference)
export ALICE="0x240E2588e35FB9D3D60B283B45108a49972FFFd8"
export BOB_RESOLVER="0xfdF1dDeB176BEA06c7430166e67E615bC312b7B5"
```

## Account Requirements

1. **Deployer Account**:
   - Needs ETH on both Base and Etherlink for deployment gas
   - Needs BMN tokens (at least 20) to distribute to test accounts

2. **Alice Account**: 
   - Needs small amount of ETH on both chains for gas (~0.01 ETH each)
   - Will receive test tokens from deployment

3. **Bob (Resolver) Account**:
   - Needs small amount of ETH on both chains for gas + safety deposits (~0.02 ETH each)
   - Will receive test tokens from deployment

## Running the Test

Once environment variables are set:

```bash
# Phase 1: Deploy infrastructure
./scripts/run-mainnet-test.sh deploy

# Phase 2: Execute swap
./scripts/run-mainnet-test.sh swap

# Check status anytime
./scripts/run-mainnet-test.sh check
```