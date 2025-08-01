#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}Bridge-Me-Not Cleanup${NC}"
echo "====================="

# Function to check if port is in use
check_port() {
    lsof -i :$1 > /dev/null 2>&1
    return $?
}

# Kill processes on specific ports
kill_port() {
    local port=$1
    local pids=$(lsof -ti :$port 2>/dev/null)
    if [ ! -z "$pids" ]; then
        echo -e "Stopping processes on port $port..."
        kill -9 $pids 2>/dev/null
        sleep 1
        if ! check_port $port; then
            echo -e "${GREEN}Port $port cleared${NC}"
        else
            echo -e "${RED}Failed to clear port $port${NC}"
        fi
    fi
}

# Stop Chain A
echo -e "\n${BLUE}Stopping Chain A...${NC}"
if check_port 8545; then
    kill_port 8545
else
    echo -e "${YELLOW}Chain A not running${NC}"
fi

# Stop Chain B
echo -e "\n${BLUE}Stopping Chain B...${NC}"
if check_port 8546; then
    kill_port 8546
else
    echo -e "${YELLOW}Chain B not running${NC}"
fi

# Clean up logs
echo -e "\n${BLUE}Cleaning up logs...${NC}"
if [ -f "chain-a.log" ] || [ -f "chain-b.log" ]; then
    rm -f chain-a.log chain-b.log
    echo -e "${GREEN}Log files removed${NC}"
else
    echo -e "${YELLOW}No log files found${NC}"
fi

# Clean up broadcast directories (forge artifacts)
echo -e "\n${BLUE}Cleaning up broadcast artifacts...${NC}"
if [ -d "broadcast" ]; then
    rm -rf broadcast
    echo -e "${GREEN}Broadcast directory removed${NC}"
else
    echo -e "${YELLOW}No broadcast directory found${NC}"
fi

# Ask about deployment files
echo -e "\n${BLUE}Deployment files:${NC}"
if [ -f "deployments/chainA.json" ] || [ -f "deployments/chainB.json" ]; then
    echo -e "${YELLOW}Found deployment files in deployments/${NC}"
    read -p "Remove deployment files? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -f deployments/*.json
        echo -e "${GREEN}Deployment files removed${NC}"
    else
        echo -e "${BLUE}Deployment files kept${NC}"
    fi
else
    echo -e "${YELLOW}No deployment files found${NC}"
fi

# Clean cache
echo -e "\n${BLUE}Cleaning forge cache...${NC}"
if [ -d "cache" ]; then
    read -p "Clean forge cache? This will require recompilation (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        forge clean
        echo -e "${GREEN}Forge cache cleaned${NC}"
    else
        echo -e "${BLUE}Forge cache kept${NC}"
    fi
fi

echo -e "\n${GREEN}Cleanup complete!${NC}"
echo -e "\nTo start fresh, run: ${BLUE}./scripts/multi-chain-setup.sh${NC}"