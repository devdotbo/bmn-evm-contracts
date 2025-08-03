# Contract Verification Commands

## Base Mainnet Verification

### 1. EscrowSrc Implementation
```bash
forge verify-contract \
    0xcCF2DEd118EC06185DC99E1a42a078754ae9c84c \
    contracts/EscrowSrc.sol:EscrowSrc \
    --chain-id 8453 \
    --watch \
    --constructor-args $(cast abi-encode "constructor(uint32,address)" 604800 0x8287CD2aC7E227D9D927F998EB600a0683a832A1) \
    --etherscan-api-key $ETHERSCAN_API_KEY
```

### 2. EscrowDst Implementation
```bash
forge verify-contract \
    0xb5A9FBEB81830006A9C03aBB33d02574346C5A9a \
    contracts/EscrowDst.sol:EscrowDst \
    --chain-id 8453 \
    --watch \
    --constructor-args $(cast abi-encode "constructor(uint32,address)" 604800 0x8287CD2aC7E227D9D927F998EB600a0683a832A1) \
    --etherscan-api-key $ETHERSCAN_API_KEY
```

### 3. CrossChainEscrowFactory
```bash
forge verify-contract \
    0xc72ed1E8a0649e51Cd046a0FfccC8f8c0bf385Fa \
    contracts/CrossChainEscrowFactory.sol:CrossChainEscrowFactory \
    --chain-id 8453 \
    --watch \
    --constructor-args $(cast abi-encode "constructor(address,address,address,address,address,address)" 0x0000000000000000000000000000000000000000 0x8287CD2aC7E227D9D927F998EB600a0683a832A1 0x8287CD2aC7E227D9D927F998EB600a0683a832A1 0x5f29827e25dc174a6A51C99e6811Bbd7581285b0 0xcCF2DEd118EC06185DC99E1a42a078754ae9c84c 0xb5A9FBEB81830006A9C03aBB33d02574346C5A9a) \
    --etherscan-api-key $ETHERSCAN_API_KEY
```

## Etherlink Mainnet Verification (Blockscout)

Note: Etherlink uses Blockscout, which may require manual verification through their web interface.

### Manual Verification Steps:
1. Go to https://explorer.etherlink.com/
2. Navigate to each contract address:
   - EscrowSrc: `0xcCF2DEd118EC06185DC99E1a42a078754ae9c84c`
   - EscrowDst: `0xb5A9FBEB81830006A9C03aBB33d02574346C5A9a`
   - CrossChainEscrowFactory: `0xc72ed1E8a0649e51Cd046a0FfccC8f8c0bf385Fa`
3. Click "Verify & Publish"
4. Select:
   - Compiler: v0.8.23
   - Optimization: Yes
   - Runs: 1000000
   - EVM Version: Shanghai
5. Paste the source code and constructor arguments

### Constructor Arguments (ABI-encoded):
- **EscrowSrc & EscrowDst**: `0x0000000000000000000000000000000000000000000000000000000000093a800000000000000000000000008287cd2ac7e227d9d927f998eb600a0683a832a1`
- **CrossChainEscrowFactory**: `0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000008287cd2ac7e227d9d927f998eb600a0683a832a10000000000000000000000008287cd2ac7e227d9d927f998eb600a0683a832a10000000000000000000000005f29827e25dc174a6a51c99e6811bbd7581285b0000000000000000000000000ccf2ded118ec06185dc99e1a42a078754ae9c84c000000000000000000000000b5a9fbeb81830006a9c03abb33d02574346c5a9a`

## Direct Links

### Base (Basescan):
- [EscrowSrc](https://basescan.org/address/0xcCF2DEd118EC06185DC99E1a42a078754ae9c84c#code)
- [EscrowDst](https://basescan.org/address/0xb5A9FBEB81830006A9C03aBB33d02574346C5A9a#code)
- [CrossChainEscrowFactory](https://basescan.org/address/0xc72ed1E8a0649e51Cd046a0FfccC8f8c0bf385Fa#code)

### Etherlink (Blockscout):
- [EscrowSrc](https://explorer.etherlink.com/address/0xcCF2DEd118EC06185DC99E1a42a078754ae9c84c/contracts#address-tabs)
- [EscrowDst](https://explorer.etherlink.com/address/0xb5A9FBEB81830006A9C03aBB33d02574346C5A9a/contracts#address-tabs)
- [CrossChainEscrowFactory](https://explorer.etherlink.com/address/0xc72ed1E8a0649e51Cd046a0FfccC8f8c0bf385Fa/contracts#address-tabs)