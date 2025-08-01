#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Check if mprocs is available
if ! command -v mprocs &> /dev/null && ! npm list mprocs &> /dev/null; then
    echo -e "${RED}Error: mprocs not found!${NC}"
    echo "Please install with: npm install"
    exit 1
fi

# Function to check if port is in use
check_port() {
    lsof -i :$1 > /dev/null 2>&1
    return $?
}

# Check if chains are already running
if check_port 8545; then
    echo -e "${RED}Error: Port 8545 is already in use. Is Chain A already running?${NC}"
    echo -e "Run ${BLUE}./scripts/cleanup.sh${NC} to stop existing chains"
    exit 1
fi

if check_port 8546; then
    echo -e "${RED}Error: Port 8546 is already in use. Is Chain B already running?${NC}"
    echo -e "Run ${BLUE}./scripts/cleanup.sh${NC} to stop existing chains"
    exit 1
fi

# Create deployments directory if it doesn't exist
mkdir -p deployments

echo -e "${BLUE}Bridge-Me-Not Multi-Chain Setup${NC}"
echo "================================"
echo -e "${GREEN}Starting mprocs with dual chain setup...${NC}"
echo ""
echo -e "${YELLOW}Quick Guide:${NC}"
echo "  • Chains will start automatically"
echo "  • Use ↑/↓ or j/k to navigate processes"
echo "  • Press 's' to start a stopped process"
echo "  • Press 'x' to stop a process"
echo "  • Press 'r' to restart a process"
echo "  • Press 'C-a' to toggle focus"
echo "  • Press 'q' to quit all processes"
echo ""
echo -e "${BLUE}After chains are running:${NC}"
echo "  1. Select 'deploy-both' and press 's' to deploy contracts"
echo "  2. Select 'fund-accounts' and press 's' to fund test accounts"
echo "  3. Select 'watch-status' and press 's' for continuous monitoring"
echo ""
echo -e "${GREEN}Press Enter to start...${NC}"
read

# Launch mprocs
npm run mprocs