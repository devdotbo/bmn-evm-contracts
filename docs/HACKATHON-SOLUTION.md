# Cross-Chain Factory Consistency: Hackathon Solution (Etherlink Compatible)

## Executive Summary

Since **Etherlink doesn't support CREATE3**, we'll use the same CREATE2 approach that successfully deployed BMN token at identical addresses on both chains.

## The Problem (What We Hit)

Our atomic swap failed because:
- Base DST Implementation: `0xbea2db672cdef137c894ac94460e677ed2e65d01`
- Etherlink DST Implementation: `0xd3024ab549875e3b6d9e7bec49b41f3ca358f339`

Different implementation addresses → Different bytecode hash → Different CREATE2 addresses → `InvalidImmutables` error

## How BMN Token Solved It

BMN successfully deployed at `0x8287CD2aC7E227D9D927F998EB600a0683a832A1` on both chains using:
- **CREATE2 Factory**: `0x4e59b44847b379578588920cA78FbF26c0B4956C` (available on both Base and Etherlink)
- **Salt**: `keccak256("BMNToken-v1.0.0")`
- **Result**: Identical addresses on all chains!

## Fast Hackathon Solutions (Ranked by Speed)

### Option 1: Quick Hardcode Hack (15 minutes) ⚡
```solidity
// In EscrowFactory.sol, add:
mapping(uint256 => address) public CHAIN_IMPLEMENTATIONS;

constructor() {
    // Hardcode known implementation addresses
    CHAIN_IMPLEMENTATIONS[8453] = 0xbea2db672cdef137c894ac94460e677ed2e65d01; // Base
    CHAIN_IMPLEMENTATIONS[42793] = 0xd3024ab549875e3b6d9e7bec49b41f3ca358f339; // Etherlink
}

function _getDstImplementation() internal view returns (address) {
    return CHAIN_IMPLEMENTATIONS[block.chainid];
}
```

### Option 2: Deploy with CREATE2 (Same as BMN Token) (1 hour) 🚀
```solidity
// script/DeployWithCreate2.s.sol
contract DeployWithCreate2 is Script {
    address constant CREATE2_FACTORY = 0x4e59b44847b379578588920cA78FbF26c0B4956C;
    
    function run() external {
        vm.startBroadcast();
        
        // Step 1: Deploy implementations using CREATE2
        bytes32 srcSalt = keccak256("BMN-EscrowSrc-V1");
        bytes32 dstSalt = keccak256("BMN-EscrowDst-V1");
        
        bytes memory srcBytecode = type(EscrowSrc).creationCode;
        bytes memory dstBytecode = type(EscrowDst).creationCode;
        
        // Deploy via CREATE2 factory
        address srcImpl = deployViaCreate2(srcSalt, srcBytecode);
        address dstImpl = deployViaCreate2(dstSalt, dstBytecode);
        
        console.log("SRC Implementation:", srcImpl);
        console.log("DST Implementation:", dstImpl);
        
        // Step 2: Deploy factory using CREATE2
        bytes32 factorySalt = keccak256("BMN-Factory-V1");
        bytes memory factoryBytecode = abi.encodePacked(
            type(TestEscrowFactory).creationCode,
            abi.encode(srcImpl, dstImpl, Constants.BMN_TOKEN, 0.00001 ether)
        );
        
        address factory = deployViaCreate2(factorySalt, factoryBytecode);
        console.log("Factory deployed at:", factory);
        
        vm.stopBroadcast();
    }
    
    function deployViaCreate2(bytes32 salt, bytes memory bytecode) internal returns (address) {
        (bool success, bytes memory result) = CREATE2_FACTORY.call(
            abi.encodePacked(salt, bytecode)
        );
        require(success, "CREATE2 deployment failed");
        return address(bytes20(result));
    }
}
```

### Option 3: Synchronized Deployment Script (2 hours) 🔧
```solidity
// script/SyncDeploy.s.sol
contract SyncDeploy is Script {
    function run() external {
        // Deploy to multiple chains in one script
        deployToChain("BASE_RPC", 8453);
        deployToChain("ETHERLINK_RPC", 42793);
    }
    
    function deployToChain(string memory rpcEnv, uint256 chainId) internal {
        vm.createSelectFork(vm.envString(rpcEnv));
        
        // Use same nonce/salt for implementations
        bytes32 salt = keccak256("BMN-IMPL-V1");
        address impl = Create2.deploy(salt, type(EscrowDst).creationCode);
        
        console.log("Chain", chainId, "implementation:", impl);
    }
}
```

## Recommended Approach for Hackathon

**Use Option 1 (Quick Hardcode) NOW to unblock testing**, then implement Option 2 (CREATE2) for the demo.

### Implementation Steps:
1. **Immediate Fix** (15 min):
   ```bash
   # Update EscrowFactory with hardcoded addresses
   # Redeploy on both chains
   # Resume testing
   ```

2. **Demo Preparation** (1 hour):
   ```bash
   # Use the same CREATE2 factory that deployed BMN token
   # Deploy implementations and factory with deterministic salts
   # Ensure identical addresses on both chains
   ```

## Key Implementation Details

### CREATE2 Factory Address
```solidity
address constant CREATE2_FACTORY = 0x4e59b44847b379578588920cA78FbF26c0B4956C;
```
This factory is confirmed to exist on both Base and Etherlink (used for BMN token).

### Deployment Order
1. Deploy `EscrowSrc` implementation with salt `keccak256("BMN-EscrowSrc-V1")`
2. Deploy `EscrowDst` implementation with salt `keccak256("BMN-EscrowDst-V1")`
3. Deploy `TestEscrowFactory` with salt `keccak256("BMN-Factory-V1")`

### Critical Success Factors
- **Same bytecode**: Ensure identical compiler settings (0.8.23, optimizer 1M runs)
- **Same constructor args**: Use exact same parameters on both chains
- **Same deployment order**: Deploy in exact same sequence

## Why This Works

1. **Proven Method**: BMN token successfully uses this approach
2. **Etherlink Compatible**: CREATE2 factory exists on Etherlink
3. **Deterministic**: Produces identical addresses when done correctly
4. **No External Dependencies**: Uses standard CREATE2 factory

## Quick Test Script
```bash
# Test CREATE2 deployment locally first
forge script script/DeployWithCreate2.s.sol --rpc-url http://localhost:8545

# If addresses match locally, deploy to mainnets
forge script script/DeployWithCreate2.s.sol --rpc-url $BASE_RPC --broadcast
forge script script/DeployWithCreate2.s.sol --rpc-url $ETHERLINK_RPC --broadcast
```

## Fallback Plan

If CREATE2 deployment has issues during hackathon:
1. Use hardcoded addresses (Option 1)
2. Document the production approach
3. Show judges you understand the problem and solution

This demonstrates:
- Problem-solving under constraints (no CREATE3 on Etherlink)
- Leveraging existing solutions (BMN token approach)
- Practical hackathon mindset (quick fixes + proper solutions)