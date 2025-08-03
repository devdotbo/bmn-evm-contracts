#!/bin/bash

# Clean corrupted state file script

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Cleaning corrupted state file...${NC}"

# Source environment variables
source .env

# Run the clean state script
forge script script/CleanStateFile.s.sol \
    --rpc-url http://localhost:8545 \
    --broadcast \
    --private-key $DEPLOYER_PRIVATE_KEY \
    -vvv

echo -e "${GREEN}State file cleaned successfully!${NC}"
echo -e "${GREEN}Backup saved to: deployments/mainnet-test-state.backup.json${NC}"

# Display the cleaned state
echo -e "\n${YELLOW}Cleaned state file contents:${NC}"
cat deployments/mainnet-test-state.json | jq '.'