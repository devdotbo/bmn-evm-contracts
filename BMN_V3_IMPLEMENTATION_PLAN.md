# BMN V3 Token Implementation Plan

## Executive Summary

This plan outlines the creation of BMN Access Token V3 using:
- **Solmate**: Gas-optimized ERC20 implementation (10-30% cheaper transfers)
- **Soldeer**: Modern dependency management replacing git submodules
- **CREATE3**: True cross-chain deterministic deployment

## Architecture Overview

```
┌─────────────────────┐
│  CREATE3 Factory    │ (Same address on all chains)
└──────────┬──────────┘
           │ Deploys
           ▼
┌─────────────────────┐
│  BMNAccessTokenV3   │ (Solmate-based, deterministic address)
│  - 18 decimals      │
│  - Owner + Auth     │
│  - Mint/Burn        │
│  - Permit support   │
└─────────────────────┘
```

## Phase 1: Setup Soldeer Dependencies

### 1.1 Initialize Soldeer
```bash
# Initialize soldeer in project
forge soldeer init

# Install dependencies
forge soldeer install solmate@6.2.0
forge soldeer install solady@0.0.236  # For CREATE3
```

### 1.2 Update Configuration
```toml
# foundry.toml
[profile.default]
dependencies_install_strategy = "soldeer"
remappings_location = "config"
soldeer_regenerate_remappings = true

[soldeer]
remappings_generate = true
remappings_version = true
remappings_prefix = ""
remappings = [
    "solmate=dependencies/solmate-6.2.0/",
    "solady=dependencies/solady-0.0.236/"
]
```

## Phase 2: Implement BMN Token V3

### 2.1 Token Contract
```solidity
// contracts/BMNAccessTokenV3.sol
// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {ERC20} from "solmate/tokens/ERC20.sol";

contract BMNAccessTokenV3 is ERC20 {
    address public immutable owner;
    mapping(address => bool) public authorized;
    
    event Authorized(address indexed account);
    event Deauthorized(address indexed account);
    event TokensMinted(address indexed to, uint256 amount);
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }
    
    constructor(address _owner) ERC20("BMN Access Token V3", "BMN", 18) {
        require(_owner != address(0), "Invalid owner");
        owner = _owner;
        authorized[_owner] = true;
        emit Authorized(_owner);
    }
    
    function authorize(address account) external onlyOwner {
        authorized[account] = true;
        emit Authorized(account);
    }
    
    function deauthorize(address account) external onlyOwner {
        authorized[account] = false;
        emit Deauthorized(account);
    }
    
    function mint(address to, uint256 amount) external onlyOwner {
        require(authorized[to], "Recipient not authorized");
        _mint(to, amount);
        emit TokensMinted(to, amount);
    }
    
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }
}
```

### 2.2 Key Benefits
- **Gas Savings**: 10-30% cheaper transfers vs OpenZeppelin
- **Built-in Permit**: EIP-2612 gasless approvals
- **Optimized Storage**: Immutable owner for cheaper reads
- **Minimal Bytecode**: Lower deployment costs

## Phase 3: CREATE3 Deployment Infrastructure

### 3.1 Deploy CREATE3 Factory
```solidity
// contracts/Create3Factory.sol
pragma solidity 0.8.23;

import {CREATE3} from "solady/utils/CREATE3.sol";

contract Create3Factory {
    mapping(address => bool) public authorized;
    mapping(bytes32 => address) public deployments;
    
    function deploy(bytes32 salt, bytes calldata bytecode) 
        external 
        returns (address deployed) 
    {
        require(authorized[msg.sender], "Not authorized");
        deployed = CREATE3.deploy(salt, bytecode, 0);
        deployments[salt] = deployed;
    }
    
    function getAddress(bytes32 salt) external view returns (address) {
        return CREATE3.getDeployed(salt);
    }
}
```

### 3.2 Deployment Scripts
```solidity
// script/DeployBMNV3.s.sol
contract DeployBMNV3 is Script {
    bytes32 constant FACTORY_SALT = keccak256("CREATE3_FACTORY_V1");
    bytes32 constant TOKEN_SALT = keccak256("BMN_V3_2025_01_03");
    
    function run() external {
        // Deploy factory first (if not exists)
        // Deploy token via CREATE3
        // Verify on both chains
    }
}
```

## Phase 4: Migration Plan

### 4.1 Pre-deployment
1. Backup current setup
2. Run soldeer migration script
3. Test on local anvil chains
4. Calculate deployment addresses

### 4.2 Deployment Sequence
```bash
# 1. Deploy CREATE3 Factory
forge script script/DeployCreate3Factory.s.sol --broadcast

# 2. Deploy BMN V3 Token
forge script script/DeployBMNV3.s.sol --broadcast

# 3. Verify deployments
forge script script/VerifyBMNV3.s.sol
```

### 4.3 Post-deployment
1. Update escrow contracts with new token address
2. Authorize resolvers on new token
3. Mint initial supply
4. Run E2E tests

## Phase 5: Testing Strategy

### 5.1 Unit Tests
```solidity
// test/BMNAccessTokenV3.t.sol
contract BMNAccessTokenV3Test is Test {
    function testGasOptimization() public {
        // Compare gas vs V2
    }
    
    function testCREATE3Determinism() public {
        // Verify same address on forks
    }
}
```

### 5.2 Integration Tests
- Cross-chain deployment verification
- Escrow integration
- Resolver authorization flows

## Implementation Timeline

### Day 1: Setup & Development
- [ ] Setup Soldeer dependencies
- [ ] Implement BMNAccessTokenV3
- [ ] Create CREATE3 factory
- [ ] Write deployment scripts

### Day 2: Testing & Deployment
- [ ] Run comprehensive tests
- [ ] Deploy to testnets
- [ ] Deploy to mainnets
- [ ] Verify contracts

### Day 3: Integration
- [ ] Update all references
- [ ] Run E2E tests
- [ ] Monitor gas savings

## Risk Mitigation

### Technical Risks
1. **CREATE3 Complexity**: Mitigated by using audited Solady implementation
2. **Solmate Differences**: Extensive testing of all token functions
3. **Migration Errors**: Phased rollout with testnet validation

### Operational Risks
1. **Address Changes**: Document all new addresses clearly
2. **Dependency Issues**: Lock versions in soldeer.lock
3. **Gas Spikes**: Deploy during low-activity periods

## Success Metrics

1. **Gas Reduction**: Target 20%+ savings on transfers
2. **Deployment Success**: Same address on both chains
3. **Zero Migration Issues**: No funds locked or lost
4. **E2E Test Pass**: All cross-chain swaps work

## Conclusion

This plan provides a clear path to implement a gas-optimized, deterministically deployed BMN token that solves the current implementation issues while providing significant improvements in gas efficiency and deployment reliability.