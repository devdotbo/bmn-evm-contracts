# Soldeer Command Reference

## Installation Commands

### Initialize Soldeer
```bash
# Basic initialization
forge soldeer init

# Initialize and clean up git submodules
forge soldeer init --clean
```

### Install Dependencies
```bash
# Install all dependencies from foundry.toml or soldeer.toml
forge soldeer install

# Install specific dependency from registry
forge soldeer install @openzeppelin-contracts~5.0.2
forge soldeer install @solmate~7
forge soldeer install @solady~0.0.235

# Install from Git repository
forge soldeer install my-lib~1.0.0 --git https://github.com/user/repo.git

# Install from Git with specific tag
forge soldeer install my-lib~1.0.0 --git https://github.com/user/repo.git --tag v1.0.0

# Install from Git with specific branch
forge soldeer install my-lib~1.0.0 --git https://github.com/user/repo.git --branch main

# Install from Git with specific commit
forge soldeer install my-lib~1.0.0 --git https://github.com/user/repo.git --rev abc123def

# Force regenerate remappings after install
forge soldeer install --regenerate-remappings
```

## Update Commands

```bash
# Update all dependencies to latest versions (respecting version constraints)
forge soldeer update

# Update specific dependency
forge soldeer update @openzeppelin-contracts

# Update with remapping regeneration
forge soldeer update --regenerate-remappings

# Update including recursive dependencies
forge soldeer update --recursive-deps
```

## Uninstall Commands

```bash
# Uninstall a dependency
forge soldeer uninstall @openzeppelin-contracts

# Uninstall with remapping cleanup
forge soldeer uninstall @openzeppelin-contracts --regenerate-remappings
```

## Utility Commands

```bash
# Check Soldeer version
forge soldeer version

# List installed dependencies
forge soldeer list

# Verify dependency integrity
forge soldeer verify

# Clean dependency cache
forge soldeer clean
```

## Configuration Examples

### In foundry.toml
```toml
[dependencies]
# Version from registry
"@openzeppelin-contracts~5.0.2" = { version = "5.0.2" }

# Git dependency with tag
"@custom-lib~1.0.0" = { git = "https://github.com/user/repo.git", tag = "v1.0.0" }

# Git dependency with commit
"@custom-lib~1.0.0" = { git = "https://github.com/user/repo.git", rev = "abc123" }

# Local path dependency
"@local-lib~1.0.0" = { path = "../local-lib" }
```

### Version Constraints
```toml
# Exact version
"@package" = "1.2.3"

# Compatible with version (^)
"@package" = "^1.2.3"  # >=1.2.3 <2.0.0

# Approximately equivalent (~)
"@package" = "~1.2.3"  # >=1.2.3 <1.3.0

# Greater than or equal
"@package" = ">=1.2.3"

# Range
"@package" = ">=1.2.3 <2.0.0"
```

## Common Workflows

### Starting a New Project
```bash
# 1. Create project
forge init my-project
cd my-project

# 2. Initialize Soldeer
forge soldeer init

# 3. Add dependencies
forge soldeer install @openzeppelin-contracts~5.0.2
forge soldeer install @solmate~7

# 4. Build project
forge build
```

### Migrating from Git Submodules
```bash
# 1. Run migration script
./scripts/migrate-to-soldeer.sh

# Or manually:
# 2. Backup existing setup
cp -r lib lib.backup
cp remappings.txt remappings.txt.backup

# 3. Remove submodules
git rm -rf lib/
rm .gitmodules

# 4. Initialize Soldeer
forge soldeer init --clean

# 5. Install dependencies
forge soldeer install
```

### CI/CD Setup
```yaml
# GitHub Actions
- name: Install dependencies
  run: forge soldeer install

# GitLab CI
install_deps:
  script:
    - forge soldeer install
```

### Updating Dependencies Safely
```bash
# 1. Check current versions
forge soldeer list

# 2. Update in test environment first
forge soldeer update

# 3. Run tests
forge test

# 4. If tests pass, commit lock file
git add soldeer.lock
git commit -m "chore: update dependencies"
```

## Troubleshooting

### Dependency Not Found
```bash
# Search for exact package name
forge soldeer search openzeppelin

# Try different version
forge soldeer install @openzeppelin-contracts~5.0.1
```

### Import Errors After Migration
```bash
# Regenerate remappings
forge soldeer install --regenerate-remappings

# Check remappings
cat remappings.txt

# Verify dependency installation
ls -la dependencies/
```

### Version Conflicts
```bash
# Check dependency tree
forge soldeer tree

# Force specific version
forge soldeer install @package~1.2.3 --force
```

### Clean Installation
```bash
# Remove all dependencies
rm -rf dependencies/
rm soldeer.lock

# Reinstall
forge soldeer install
```

## Best Practices

1. **Always commit `soldeer.lock`** - Ensures reproducible builds
2. **Use exact versions in production** - Avoid surprises from updates
3. **Test after updates** - Run full test suite after dependency updates
4. **Keep dependencies minimal** - Only install what you need
5. **Document Git dependencies** - Add comments explaining why Git sources are used
6. **Use version suffixes in imports** - Makes dependencies explicit in code

## Example Import Patterns

```solidity
// With version suffix (recommended)
import "@openzeppelin-contracts-5.0.2/contracts/token/ERC20/ERC20.sol";
import "@solmate-7/tokens/ERC20.sol";
import "@solady-0.0.235/utils/CREATE3.sol";

// Without version suffix (if remappings_version = false)
import "@openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
```