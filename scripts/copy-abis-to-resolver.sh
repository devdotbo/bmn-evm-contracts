#!/bin/bash
# Copy updated ABIs to resolver and create fix instructions

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
RESOLVER_DIR="$PROJECT_ROOT/../bmn-evm-resolver"

# Check if resolver directory exists
if [ ! -d "$RESOLVER_DIR" ]; then
    echo -e "${RED}Error: Resolver directory not found at $RESOLVER_DIR${NC}"
    exit 1
fi

# Check if ABIs directory exists
if [ ! -d "$RESOLVER_DIR/abis" ]; then
    echo -e "${YELLOW}Creating abis directory in resolver...${NC}"
    mkdir -p "$RESOLVER_DIR/abis"
fi

echo -e "${GREEN}Copying updated ABIs to resolver...${NC}"

# Function to copy and report
copy_abi() {
    local contract=$1
    local source="$PROJECT_ROOT/out/${contract}.sol/${contract}.json"
    local dest="$RESOLVER_DIR/abis/${contract}.json"
    
    if [ -f "$source" ]; then
        cp "$source" "$dest"
        echo -e "  ✓ ${contract}.json copied"
    else
        echo -e "  ${RED}✗ ${contract}.json not found${NC}"
    fi
}

# Copy all required ABIs
copy_abi "EscrowFactory"
copy_abi "EscrowSrc"
copy_abi "EscrowDst"
copy_abi "TokenMock"
copy_abi "LimitOrderProtocol"
copy_abi "IERC20"

echo -e "\n${YELLOW}Creating fix instructions...${NC}"

# Create instructions file
cat > "$PROJECT_ROOT/RESOLVER_FIX_INSTRUCTIONS.md" << 'EOF'
# Resolver Fix Instructions

## Overview
The contract ABIs have been updated after fixing timelock packing issues. The resolver TypeScript code needs updates to match the new ABI signatures.

## ABI Changes
1. **Timelock Packing Fixed**: Contracts now properly pack timelock values into uint256
2. **createDstEscrow Signature Changed**: Now accepts 2 parameters instead of 3

## Required Code Changes

### 1. Fix createDstEscrow call in `src/resolver/executor.ts` (lines 139-143)

**Current (incorrect):**
```typescript
return await factory.write.createDstEscrow([
  order.immutables,
  dstImmutables,
  BigInt(this.srcChainId)
]);
```

**Fixed:**
```typescript
return await factory.write.createDstEscrow([
  dstImmutables,
  order.immutables.timelocks.srcCancellation  // Pass cancellation timestamp, not chainId
]);
```

### 2. Review computeEscrowDstAddress parameters
The computeEscrowDstAddress function may need parameter adjustments based on the new ABI.

### 3. Timelock Structure Compatibility

**Contract expects (packed uint256):**
- Bits 0-31: srcWithdrawal offset
- Bits 32-63: srcPublicWithdrawal offset  
- Bits 64-95: srcCancellation offset
- Bits 96-127: srcPublicCancellation offset
- Bits 128-159: dstWithdrawal offset
- Bits 160-191: dstPublicWithdrawal offset
- Bits 192-223: dstCancellation offset
- Bits 224-255: deployedAt timestamp

**TypeScript currently uses (unpacked):**
```typescript
interface Timelocks {
  srcWithdrawal: bigint;
  srcPublicWithdrawal: bigint;
  srcCancellation: bigint;
  srcPublicCancellation: bigint;
  dstWithdrawal: bigint;
  dstCancellation: bigint;
}
```

**Note:** Check if viem automatically handles the packing/unpacking based on the ABI. If not, you may need to add conversion functions.

## Contract Changes Summary
- Fixed bitwise operations in createTimelocks() with proper uint256 casting
- Timelocks now correctly store offset values instead of all zeros
- EscrowFactory.createDstEscrow now properly validates parameters

## Testing
After making these changes, run:
```bash
./scripts/test-flow.sh -y
```

This should resolve the "ABI encoding error when deploying destination escrow" issue.
EOF

echo -e "\n${GREEN}✅ Done!${NC}"
echo -e "  - ABIs copied to: $RESOLVER_DIR/abis/"
echo -e "  - Instructions at: $PROJECT_ROOT/RESOLVER_FIX_INSTRUCTIONS.md"
echo -e "\n${YELLOW}Next steps:${NC}"
echo -e "  1. Review RESOLVER_FIX_INSTRUCTIONS.md"
echo -e "  2. Apply the TypeScript fixes in the resolver project"
echo -e "  3. Run the test flow to verify"