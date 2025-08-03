#!/bin/bash
# Migration script from git submodules to Soldeer

set -e

echo "🚀 Starting migration to Soldeer..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if we're in the right directory
if [ ! -f "foundry.toml" ]; then
    echo -e "${RED}Error: foundry.toml not found. Are you in the project root?${NC}"
    exit 1
fi

# Step 1: Backup current setup
echo -e "${BLUE}Step 1: Creating backups...${NC}"
if [ -d "lib" ]; then
    cp -r lib lib.backup.$(date +%Y%m%d_%H%M%S)
    echo "✓ Backed up lib directory"
fi

if [ -f "remappings.txt" ]; then
    cp remappings.txt remappings.txt.backup.$(date +%Y%m%d_%H%M%S)
    echo "✓ Backed up remappings.txt"
fi

if [ -f ".gitmodules" ]; then
    cp .gitmodules .gitmodules.backup.$(date +%Y%m%d_%H%M%S)
    echo "✓ Backed up .gitmodules"
fi

# Step 2: Check Soldeer availability
echo -e "\n${BLUE}Step 2: Checking Soldeer...${NC}"
if ! forge soldeer version &> /dev/null; then
    echo -e "${RED}Error: Soldeer not found. Please update Foundry: foundryup${NC}"
    exit 1
fi
echo "✓ Soldeer version: $(forge soldeer version)"

# Step 3: Remove git submodules
echo -e "\n${BLUE}Step 3: Removing git submodules...${NC}"
if [ -f ".gitmodules" ]; then
    # Parse .gitmodules to get all submodule paths
    while IFS= read -r line; do
        if [[ $line =~ path[[:space:]]*=[[:space:]]*(.*) ]]; then
            submodule_path="${BASH_REMATCH[1]}"
            echo "Removing submodule: $submodule_path"
            git rm -rf "$submodule_path" 2>/dev/null || true
            git config --remove-section "submodule.$submodule_path" 2>/dev/null || true
        fi
    done < .gitmodules
    
    git rm -f .gitmodules 2>/dev/null || true
    echo "✓ Git submodules removed"
else
    echo "✓ No git submodules found"
fi

# Step 4: Update foundry.toml
echo -e "\n${BLUE}Step 4: Updating foundry.toml...${NC}"
if [ -f "foundry.toml.soldeer" ]; then
    cp foundry.toml foundry.toml.original
    cp foundry.toml.soldeer foundry.toml
    echo "✓ Updated foundry.toml with Soldeer configuration"
else
    echo -e "${RED}Warning: foundry.toml.soldeer not found. Please update foundry.toml manually.${NC}"
fi

# Step 5: Initialize Soldeer
echo -e "\n${BLUE}Step 5: Initializing Soldeer...${NC}"
forge soldeer init --clean

# Step 6: Install dependencies
echo -e "\n${BLUE}Step 6: Installing dependencies...${NC}"
forge soldeer install

# Step 7: Update .gitignore
echo -e "\n${BLUE}Step 7: Updating .gitignore...${NC}"
if ! grep -q "dependencies/" .gitignore 2>/dev/null; then
    echo -e "\n# Soldeer dependencies\ndependencies/" >> .gitignore
    echo "✓ Added dependencies/ to .gitignore"
fi

# Step 8: Verify installation
echo -e "\n${BLUE}Step 8: Verifying installation...${NC}"
if [ -d "dependencies" ]; then
    echo "✓ Dependencies directory created"
    echo "Installed dependencies:"
    ls -la dependencies/
fi

if [ -f "soldeer.lock" ]; then
    echo "✓ soldeer.lock created"
fi

if [ -f "remappings.txt" ]; then
    echo "✓ remappings.txt updated"
    echo "Current remappings:"
    cat remappings.txt
fi

# Step 9: Test build
echo -e "\n${BLUE}Step 9: Testing build...${NC}"
if forge build; then
    echo -e "${GREEN}✓ Build successful!${NC}"
else
    echo -e "${RED}✗ Build failed. You may need to update import statements.${NC}"
fi

echo -e "\n${GREEN}🎉 Migration complete!${NC}"
echo -e "\n${BLUE}Next steps:${NC}"
echo "1. Update your Solidity imports to use the new remappings"
echo "2. Commit soldeer.lock to version control"
echo "3. Update CI/CD to use 'forge soldeer install'"
echo "4. Remove lib.backup.* directories after verifying everything works"

echo -e "\n${BLUE}Example import changes:${NC}"
echo "Old: import \"openzeppelin-contracts/contracts/token/ERC20/ERC20.sol\";"
echo "New: import \"@openzeppelin-contracts-5.0.2/contracts/token/ERC20/ERC20.sol\";"