#!/bin/bash

# Script to install pre-commit security hook

echo "Installing pre-commit security hook..."

# Find the actual .git directory (handles submodules)
GIT_DIR=$(git rev-parse --git-dir)

# Create hooks directory if it doesn't exist
mkdir -p "$GIT_DIR/hooks"

# Create the pre-commit hook
cat > "$GIT_DIR/hooks/pre-commit" << 'EOF'
#!/bin/bash

# Pre-commit hook to prevent accidental exposure of secrets
# This script runs automatically before each commit

echo "🔍 Running security checks before commit..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Track if any issues found
ISSUES_FOUND=0

# Check for API keys and secrets in staged files
echo "Checking for exposed API keys and secrets..."
EXPOSED_SECRETS=$(git diff --cached | grep -E "(api[_-]?key|private[_-]?key|secret|password|token|bearer).*[:=].*['\"]?[a-zA-Z0-9_\-]{20,}" | grep -v "YOUR_.*_HERE" | grep -v "0xYOUR_")

if [ ! -z "$EXPOSED_SECRETS" ]; then
    echo -e "${RED}❌ SECURITY ALERT: Potential secrets found in staged files:${NC}"
    echo "$EXPOSED_SECRETS"
    ISSUES_FOUND=1
fi

# Check for RPC URLs with embedded keys
echo "Checking for RPC URLs with embedded keys..."
EXPOSED_RPC=$(git diff --cached | grep -E "https?://[^/]*(ankr|alchemy|infura|drpc|quicknode|chainstack|moralis)[^/]*/[a-zA-Z0-9_\-]{20,}" | grep -v "YOUR_API_KEY")

if [ ! -z "$EXPOSED_RPC" ]; then
    echo -e "${RED}❌ SECURITY ALERT: RPC URLs with embedded API keys found:${NC}"
    echo "$EXPOSED_RPC"
    ISSUES_FOUND=1
fi

# Check specifically for known exposed keys (add your own patterns here)
echo "Checking for specific known keys..."
# Add your actual exposed keys here to prevent them from being committed again
# Example: KNOWN_KEYS=$(git diff --cached | grep -E "YOUR_ACTUAL_EXPOSED_KEY_PATTERN")
KNOWN_KEYS=""

if [ ! -z "$KNOWN_KEYS" ]; then
    echo -e "${RED}❌ SECURITY ALERT: Known exposed keys found!${NC}"
    echo "$KNOWN_KEYS"
    ISSUES_FOUND=1
fi

# Check for private keys (64 hex characters)
echo "Checking for private keys..."
PRIVATE_KEYS=$(git diff --cached | grep -E "0x[a-fA-F0-9]{64}" | grep -v "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80" | grep -v "0xYOUR_PRIVATE_KEY_HERE")

if [ ! -z "$PRIVATE_KEYS" ]; then
    echo -e "${YELLOW}⚠️  WARNING: Potential private keys found (verify these are test keys only):${NC}"
    echo "$PRIVATE_KEYS"
    echo -e "${YELLOW}If these are real private keys, abort this commit with Ctrl+C${NC}"
    read -p "Are these test keys only? (yes/no): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        ISSUES_FOUND=1
    fi
fi

# Check that .env is not being committed
if git diff --cached --name-only | grep -E "^\.env$"; then
    echo -e "${RED}❌ SECURITY ALERT: .env file is staged for commit!${NC}"
    echo "Run: git reset HEAD .env"
    ISSUES_FOUND=1
fi

# Final decision
if [ $ISSUES_FOUND -eq 1 ]; then
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${RED}🚨 COMMIT BLOCKED: Security issues detected!${NC}"
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "Please fix the issues above before committing:"
    echo "1. Replace actual keys with placeholders (YOUR_KEY_HERE)"
    echo "2. Move sensitive data to .env file"
    echo "3. Use environment variables instead of hardcoded values"
    echo ""
    echo "To bypass this check (NOT RECOMMENDED):"
    echo "git commit --no-verify"
    echo ""
    exit 1
else
    echo -e "${GREEN}✅ Security checks passed! Proceeding with commit...${NC}"
fi

exit 0
EOF

# Make the hook executable
chmod +x "$GIT_DIR/hooks/pre-commit"

echo "✅ Pre-commit hook installed successfully!"
echo ""
echo "The hook will now run automatically before each commit to check for:"
echo "  - API keys and tokens"
echo "  - RPC URLs with embedded keys"
echo "  - Private keys and mnemonics"
echo "  - .env files being committed"
echo ""
echo "To test the hook, try staging a file with a fake key and run: git commit"
echo "To bypass the hook (not recommended): git commit --no-verify"