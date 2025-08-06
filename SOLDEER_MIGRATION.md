# Soldeer Dependency Management Migration

## Overview
This document describes the migration from git submodules and lib directory to Soldeer, a modern Solidity dependency manager. This migration resolved dependency conflicts and standardized our dependency management across all Bridge-Me-Not projects.

## Migration Date
- **Date**: August 6, 2025
- **Commit**: 5a9a770 - "Migrate from git submodules to Soldeer dependency management"

## Why Soldeer?

### Problems with Git Submodules
1. **Dependency Hell**: Conflicting versions between submodules
2. **Remapping Chaos**: Complex remapping configurations mixing lib/ and dependencies/
3. **Version Conflicts**: Different projects using different dependency versions
4. **Manual Management**: No automatic dependency resolution
5. **Build Failures**: Frequent "file not found" errors due to incorrect paths

### Soldeer Benefits
1. **Centralized Registry**: Dependencies from soldeer.xyz
2. **Version Management**: Semantic versioning with lockfile
3. **Clean Structure**: All dependencies in single dependencies/ directory
4. **Automatic Remappings**: Can generate remappings automatically
5. **Consistency**: Same setup as bmn-evm-contracts-limit-order

## Migration Steps Performed

### 1. Removed Old System
```bash
# Remove all git submodules
git submodule deinit -f --all
rm -rf .git/modules/*
rm -rf lib
rm -f .gitmodules
rm -f remappings.txt
```

### 2. Initialize Soldeer
```bash
forge soldeer init
```

This created:
- Updated `foundry.toml` with Soldeer configuration
- `soldeer.lock` file for dependency tracking
- `dependencies/` directory for packages

### 3. Install Dependencies
```bash
forge soldeer install @openzeppelin-contracts~5.1.0
forge soldeer install forge-std~1.10.0
forge soldeer install limit-order-protocol~4.0.1
forge soldeer install limit-order-settlement~1.0.0
forge soldeer install solidity-utils~1.33.0
forge soldeer install murky~1.1.10
forge soldeer install zeframlou-create3-factory~567d6ec78cd0545f2fb18135dcb68298a5a1ef09 --url <github-url>
```

### 4. Configure Remappings
Added to `foundry.toml`:
```toml
remappings = [
    "forge-std/=dependencies/forge-std-1.10.0/src/",
    "openzeppelin-contracts/contracts/=dependencies/@openzeppelin-contracts-5.1.0/",
    "@openzeppelin/contracts/=dependencies/@openzeppelin-contracts-5.1.0/",
    "limit-order-protocol/=dependencies/limit-order-protocol/",
    "limit-order-settlement/=dependencies/limit-order-settlement/",
    "solidity-utils/=dependencies/solidity-utils/",
    "@1inch/solidity-utils/=dependencies/solidity-utils/",
    "murky/=dependencies/murky/src/",
    "create3-factory/=dependencies/zeframlou-create3-factory-567d6ec78cd0545f2fb18135dcb68298a5a1ef09/src/",
    "SimpleLimitOrderProtocol/=../bmn-evm-contracts-limit-order/contracts/"
]
```

### 5. Create Stub Implementations
Since limit-order-settlement package was missing extension contracts, created stubs:

**contracts/stubs/extensions/BaseExtension.sol**:
```solidity
abstract contract BaseExtension {
    function _postInteraction(
        address /*orderMaker*/,
        address /*interactionTarget*/,
        bytes calldata /*interaction*/
    ) internal virtual {
        // Default implementation - do nothing
    }
}
```

**contracts/stubs/extensions/ResolverValidationExtension.sol**:
```solidity
abstract contract ResolverValidationExtension is BaseExtension {
    function isWhitelistedResolver(address resolver) public view virtual returns (bool) {
        return resolver != address(0);
    }
    
    modifier onlyWhitelistedResolver() {
        require(isWhitelistedResolver(msg.sender), "Not a whitelisted resolver");
        _;
    }
}
```

### 6. Update Import Paths
Changed all imports from:
- `limit-order-settlement/contracts/extensions/` → `./stubs/extensions/`
- `../contracts/test/TokenMock.sol` → `solidity-utils/contracts/mocks/TokenMock.sol`

### 7. Fix Constructor Arguments
Updated EscrowSrc and EscrowDst instantiation to include required parameters:
```solidity
uint32 rescueDelay = 7 days;
new EscrowSrc(rescueDelay, IERC20(address(bmnToken)));
new EscrowDst(rescueDelay, IERC20(address(bmnToken)));
```

## Final Configuration

### foundry.toml Structure
```toml
[profile.default]
src = 'contracts'
out = 'out'
libs = ['dependencies']  # Only dependencies, no lib
test = 'test'
optimizer_runs = 1000000
via_ir = true
evm_version = 'cancun'
solc_version = '0.8.23'
fs_permissions = [{ access = "read-write", path = "./deployments" }]
allow_paths = ["../bmn-evm-contracts-limit-order"]

[soldeer]
remappings_generate = false
remappings_regenerate = false
remappings_version = true
remappings_prefix = ""
remappings_location = "config"
recursive_deps = false

[dependencies]
zeframlou-create3-factory = "567d6ec78cd0545f2fb18135dcb68298a5a1ef09"
forge-std = "1.10.0"
"@openzeppelin-contracts" = "5.1.0"
limit-order-protocol = "4.0.1"
limit-order-settlement = "1.0.0"
solidity-utils = "1.33.0"
murky = "1.1.10"
```

### Directory Structure
```
bmn-evm-contracts/
├── dependencies/              # All Soldeer packages
│   ├── @openzeppelin-contracts-5.1.0/
│   ├── forge-std-1.10.0/
│   ├── limit-order-protocol/
│   ├── limit-order-settlement/
│   ├── solidity-utils/
│   ├── murky/
│   └── zeframlou-create3-factory-*/
├── contracts/
│   └── stubs/                # Stub implementations
│       └── extensions/
│           ├── BaseExtension.sol
│           └── ResolverValidationExtension.sol
├── foundry.toml              # With Soldeer config
├── soldeer.lock              # Dependency lock file
└── (no lib/, no .gitmodules, no remappings.txt)
```

## Common Soldeer Commands

### Install Dependencies
```bash
# Install all dependencies from soldeer.lock
forge soldeer install

# Install specific package
forge soldeer install <package>~<version>

# Install from custom URL
forge soldeer install <package>~<version> --url <url>

# Install from git
forge soldeer install <package>~<version> --git <git-url>
```

### Update Dependencies
```bash
# Update all dependencies to latest matching versions
forge soldeer update

# Update specific dependency
forge soldeer update <package>
```

### Push Package to Registry
```bash
# Login to Soldeer
forge soldeer login

# Push package
forge soldeer push <name>~<version>

# Dry run
forge soldeer push <name>~<version> --dry-run
```

## Troubleshooting

### Issue: Missing Dependencies
**Solution**: Run `forge soldeer install` to install from lockfile

### Issue: Import Path Not Found
**Solution**: Check remappings in foundry.toml match actual directory structure in dependencies/

### Issue: Version Conflicts
**Solution**: Use `forge soldeer update` to resolve to compatible versions

### Issue: Constructor Argument Mismatch
**Solution**: Check if contracts now require additional constructor parameters (like rescueDelay, accessToken)

## Benefits Achieved

1. **Clean Build**: No more "file not found" errors
2. **Consistent Dependencies**: All projects use same versions
3. **Simplified Structure**: Single dependencies/ directory
4. **Version Control**: soldeer.lock ensures reproducible builds
5. **Easy Updates**: `forge soldeer update` handles version resolution
6. **Cross-Project Compatibility**: Same setup as bmn-evm-contracts-limit-order

## Security Considerations

1. **Dependency Verification**: Soldeer provides SHA-256 hashes in lockfile
2. **Registry Trust**: Dependencies from soldeer.xyz are maintained by m4rio.eth
3. **Stub Safety**: Our stub implementations are minimal and safe
4. **No Private Keys**: Never commit .env files or private keys
5. **Audit Trail**: soldeer.lock tracks exact versions and hashes

## Future Improvements

1. **Replace Stubs**: When 1inch publishes proper limit-order-settlement package
2. **Publish BMN Packages**: Consider publishing our contracts to Soldeer registry
3. **Automated Updates**: Set up CI to check for dependency updates
4. **Security Scanning**: Integrate dependency vulnerability scanning

## Related Documentation

- [Soldeer Documentation](https://github.com/mario-eth/soldeer)
- [soldeer.xyz Registry](https://soldeer.xyz)
- [Foundry Book - Dependencies](https://book.getfoundry.sh/projects/dependencies)
- [bmn-evm-contracts-limit-order/soldeer.md](../bmn-evm-contracts-limit-order/soldeer.md)

## Migration Checklist

- [x] Remove git submodules and lib directory
- [x] Initialize Soldeer in project
- [x] Install all required dependencies
- [x] Configure remappings in foundry.toml
- [x] Create stub implementations for missing contracts
- [x] Update all import paths
- [x] Fix constructor arguments
- [x] Verify successful build
- [x] Commit changes with security checks
- [x] Document migration process

## Contact

For questions about this migration or Soldeer setup, contact the Bridge-Me-Not development team.