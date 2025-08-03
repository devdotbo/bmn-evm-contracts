# Base CREATE3 Factory Verification Report

## Summary

Verification of CREATE3 factory addresses on Base mainnet chain.

## Findings

### 1. Contract at 0x93FEC2C00BfE902F733B57c5a6CeeD7CD1384AE1

- **Status**: Contract EXISTS on Base mainnet
- **Bytecode Size**: 1,595 bytes
- **Contract Type**: CREATE3 Factory
- **Functions Identified**:
  - `getDeployed(address,bytes32)` - selector: 0x50f1c464
  - `deploy(bytes32,bytes)` - selector: 0xcdcb760a
- **Solidity Version**: 0.8.17 (from bytecode metadata)

### 2. Contract at 0x9fBB3DF7C40Da2e5A0dE984fFE2CCB7C47cd0ABf

- **Status**: Contract EXISTS on Base mainnet
- **Bytecode Size**: 1,595 bytes
- **Contract Type**: CREATE3 Factory (identical to above)
- **Note**: This appears to be a different deployment of the same CREATE3 factory implementation
- **Solidity Version**: 0.8.24 (from bytecode metadata)

### 3. Alternative CREATE3 Factory at 0xba5Ed099633D3B313e4D5F7bdc1305d3c28ba5Ed

- **Status**: Contract EXISTS on Base mainnet
- **Bytecode Size**: 11,838 bytes
- **Contract Type**: Likely Agora's CREATE3 factory (much larger implementation)
- **Note**: This is a different, more complex CREATE3 implementation

## Bytecode Comparison

The contracts at `0x93FEC2C00BfE902F733B57c5a6CeeD7CD1384AE1` and `0x9fBB3DF7C40Da2e5A0dE984fFE2CCB7C47cd0ABf` have:
- Identical bytecode size (1,595 bytes)
- Same function selectors
- Nearly identical bytecode (only difference is in metadata hash at the end)
- Different compiler versions (0.8.17 vs 0.8.24)

## Conclusion

1. **The CREATE3 factory at 0x93FEC2C00BfE902F733B57c5a6CeeD7CD1384AE1 DOES exist on Base mainnet**
2. There are at least 3 CREATE3 factory implementations deployed on Base:
   - Two minimal implementations at the addresses checked (same code, different deployments)
   - One larger implementation at 0xba5Ed099633D3B313e4D5F7bdc1305d3c28ba5Ed (Agora's factory)

## Recommendations

1. **For consistency**: Use 0x93FEC2C00BfE902F733B57c5a6CeeD7CD1384AE1 as it matches the address referenced in the project
2. **For newer compiler**: Use 0x9fBB3DF7C40Da2e5A0dE984fFE2CCB7C47cd0ABf if you prefer Solidity 0.8.24
3. **For advanced features**: Consider 0xba5Ed099633D3B313e4D5F7bdc1305d3c28ba5Ed if you need additional functionality

The user's comment about "different create3" on Base is partially correct - while the same addresses exist, there are indeed multiple CREATE3 implementations available on Base, with the Agora factory being significantly different from the minimal implementations.