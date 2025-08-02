# Bridge-Me-Not Documentation Index

## Recent Updates & Critical Issues

### 🔴 Critical: CREATE2 Address Mismatch
- **Main Analysis**: [CREATE2_ADDRESS_MISMATCH_ANALYSIS.md](./CREATE2_ADDRESS_MISMATCH_ANALYSIS.md)
- **Resolver Findings**: [../bmn-evm-resolver/CREATE2_ADDRESS_MISMATCH_FINDINGS.md](../bmn-evm-resolver/CREATE2_ADDRESS_MISMATCH_FINDINGS.md)
- **Status**: Workaround implemented, contract fix pending

### ✅ Improvements: 1-Second Block Mining & Timing
- **Timing Guide**: [TIMING_TROUBLESHOOTING.md](./TIMING_TROUBLESHOOTING.md)
- **Contract Improvements**: [../bmn-evm-resolver/CONTRACTS_IMPROVEMENTS_SUMMARY.md](../bmn-evm-resolver/CONTRACTS_IMPROVEMENTS_SUMMARY.md)
- **Status**: Fully implemented and tested

### 🔧 Resolver Integration
- **Fix Instructions**: [RESOLVER_FIX_INSTRUCTIONS.md](./RESOLVER_FIX_INSTRUCTIONS.md)
- **Test Flow Fixes**: [../bmn-evm-resolver/TEST_FLOW_FIXES.md](../bmn-evm-resolver/TEST_FLOW_FIXES.md)
- **Status**: Resolver updated with event-based address parsing

## Core Documentation

### Development Setup
- **Main Instructions**: [CLAUDE.md](./CLAUDE.md) - Essential commands and guidelines
- **README**: [README.md](./README.md) - Project overview and architecture

### Scripts & Testing
- **Live Swap Test**: `scripts/test-live-swap.sh` - Full 5-step atomic swap test
- **Deployment**: `scripts/deploy-both-chains.sh` - Deploy to both test chains
- **Check Status**: `scripts/check-deployment.sh` - Verify deployment and balances
- **Copy ABIs**: `scripts/copy-abis-to-resolver.sh` - Update resolver ABIs

### Key Contracts
- **EscrowFactory**: Main factory for deploying escrows
- **EscrowSrc**: Source chain escrow implementation
- **EscrowDst**: Destination chain escrow implementation
- **BaseEscrow**: Common escrow functionality

## Quick Links

### For Contract Developers
1. Start with [CLAUDE.md](./CLAUDE.md) for development guidelines
2. Review [CREATE2_ADDRESS_MISMATCH_ANALYSIS.md](./CREATE2_ADDRESS_MISMATCH_ANALYSIS.md) for the critical issue
3. Check [TIMING_TROUBLESHOOTING.md](./TIMING_TROUBLESHOOTING.md) for timing-related issues

### For Resolver Developers
1. Read [CONTRACTS_IMPROVEMENTS_SUMMARY.md](../bmn-evm-resolver/CONTRACTS_IMPROVEMENTS_SUMMARY.md)
2. Understand [CREATE2_ADDRESS_MISMATCH_FINDINGS.md](../bmn-evm-resolver/CREATE2_ADDRESS_MISMATCH_FINDINGS.md)
3. Follow [RESOLVER_FIX_INSTRUCTIONS.md](./RESOLVER_FIX_INSTRUCTIONS.md) if needed

### For Testing
1. Run `mprocs` to start test chains with 1-second blocks
2. Deploy with `./scripts/deploy-both-chains.sh`
3. Test with `./scripts/test-live-swap.sh`
4. Check balances with `./scripts/check-deployment.sh`

## Recent Changes (2025-08-02)

1. **Implemented 1-second block mining** on both Anvil chains
2. **Optimized timelocks** to use seconds instead of minutes
3. **Added automatic ABI copying** to deployment script
4. **Created comprehensive documentation** for CREATE2 issue
5. **Enhanced test scripts** with better logging and debugging

## Known Issues

1. **CREATE2 Address Mismatch** - Predicted vs actual destination escrow addresses differ
   - Workaround: Use event parsing to get actual addresses
   - Fix: Update to use `Clones.predictDeterministicAddress`

2. **Timestamp Drift** - Chains may have slight timestamp differences
   - Mitigation: 5-minute tolerance implemented
   - Tool: `scripts/sync-chain-times.sh` for manual sync

## Support

For issues or questions:
- Contract issues: See [CLAUDE.md](./CLAUDE.md) troubleshooting section
- Resolver issues: See resolver documentation in `../bmn-evm-resolver/`
- CREATE2 issue: See comprehensive analysis linked above