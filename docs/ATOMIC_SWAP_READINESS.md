## Atomic Swap Readiness Report (contracts v2.2.x)

### Executive summary

- **Core factory path (EscrowFactory / CrossChainEscrowFactory)**: Ready for atomic swaps with the TS resolver. postInteraction flow, events, and gas targets validated by tests.
- **SimplifiedEscrowFactory**: Not fully ready. One end-to-end test fails due to immutable/salt mismatch. A small fix plan is provided below.

### Scope

- Repositories assessed: `bmn-evm-contracts` (contracts), `bmn-evm-contracts-limit-order` (local 1inch-like LOP).
- Focus: Can current contracts support an atomic swap when driven by our TypeScript resolver?

### Build and test results

- Commands used

```bash
cd bmn-evm-contracts
forge soldeer install
forge build --sizes
forge test -vvv
```

- Summary

- **Total**: 34 tests; **Pass**: 33; **Fail**: 1
  - Passing suites:
    - `test/PostInteractionTest.sol` (3) – Validates postInteraction → source escrow creation and resolver approvals
    - `test/FactoryEventEnhancement.t.sol` (5) – Event back-compat + deterministic addresses + gas
    - `test/extensions/BMNExtensions.t.sol` (15) – Circuit breakers, MEV delay, gas tracking, resolver mgmt
    - `test/SimpleLimitOrderIntegration.t.sol` (3) – Basic order fill and integration behavior
  - Failing suite:
    - `test/SingleChainAtomicSwapTest.sol` → `testFullAtomicSwapFlow` reverts with `InvalidImmutables()` during withdraw

- Notes
  - Soldeer printed a warning resolving `murky@1.1.10`, but builds/tests still ran successfully (dependencies already present). Consider updating the lock if this recurs.
  - `bmn-evm-contracts-limit-order` builds, but one local script imports contracts via relative paths across repos and fails to compile; this does not affect core contract readiness.

### What works today (Go)

- The primary factories (`EscrowFactory`, `CrossChainEscrowFactory`) support atomic swaps with the resolver:
  - 1) LOP order fill triggers `postInteraction` on the factory, which deploys the source escrow and verifies balances
  - 2) Resolver creates destination escrow with aligned timelocks via `createDstEscrow`
  - 3) Maker withdraws on dst with secret; Resolver uses revealed secret to withdraw from src
  - Event/address determinism validated; postInteraction gas observed around ~105,535

### What needs fixing (No-Go for SimplifiedEscrowFactory)

- Symptom: `testFullAtomicSwapFlow` fails with `InvalidImmutables()` when calling withdraw on the clone.
- Root causes:
  - **Salt mismatch**: `SimplifiedEscrowFactory` deploys the src clone using `keccak256(abi.encode(srcImmutables))`, while escrow validation expects `ImmutablesLib.hash/hashMem()` semantics used elsewhere. The salts must match.
  - **FACTORY mismatch**: `EscrowSrc`/`EscrowDst` set `FACTORY = msg.sender` in constructor. If implementations aren’t deployed by the factory contract itself, `Escrow._validateImmutables()` will compare against a different factory address and revert.

### Minimal fix plan (SimplifiedEscrowFactory)

1) Align clone salt
   - Replace manual `keccak256(abi.encode(srcImmutables))` with `ImmutablesLib.hashMem(srcImmutables)` when calling `cloneDeterministic`.

2) Ensure FACTORY matches deployer
   - Deploy `EscrowSrc` and `EscrowDst` from inside the `SimplifiedEscrowFactory` constructor (so `msg.sender` in the escrow constructors equals the factory), and store their addresses in the factory’s state.

3) Re-run tests
   - Expect `testFullAtomicSwapFlow` to pass thereafter.

### Resolver integration checklist (for production factories)

- **Resolver whitelist** (if using `CrossChainEscrowFactory`): ensure the resolver address is whitelisted before it fills orders or calls `createDstEscrow`.
- **postInteraction extraData**: Encode fields matching `BaseEscrowFactory` expectations (hashlock, dstChainId, dstToken, deposits, timelocks). The tests show a working format used in PostInteraction suite.
- **Approvals**: Resolver must approve the factory to pull makerAsset into the source escrow post fill.
- **Timelocks alignment**: On dst creation, `DstCancellation` must be ≤ `srcCancellation + 300s` tolerance; otherwise `InvalidCreationTime` reverts.
- **Token flow expectations**: MakerAsset ends in src escrow; Dst escrow is funded by resolver (native value plus token transfer if ERC20).

### Validation runbook

1) Local unit/integration

```bash
cd bmn-evm-contracts
forge build --sizes
forge test -vvv --match-path test/PostInteractionTest.sol
forge test -vvv --match-path test/FactoryEventEnhancement.t.sol
forge test -vvv --match-path test/SimpleLimitOrderIntegration.t.sol
```

2) End-to-end single chain (after SimplifiedEscrowFactory fix)

```bash
forge test -vvv --match-path test/SingleChainAtomicSwapTest.sol
```

3) Dual-chain manual smoke (Anvil)

```bash
# Start two chains (example)
anvil --port 8545 --chain-id 1337 &
anvil --port 8546 --chain-id 1338 &

# Deploy factories on both chains (scripts already in repo; use placeholders for RPC/keys)
# source .env && forge script script/DeployWithCREATE3.s.sol --rpc-url $BASE_RPC_URL --broadcast

# Run resolver against both chains; monitor escrow events and balances
```

### Known issues and follow-ups

- `bmn-evm-contracts-limit-order` contains a deployment script that imports sibling repo contracts via relative paths; it fails to compile in isolation. Either:
  - Adjust remappings to reference built artifacts, or
  - Move integration scripts/tests into `bmn-evm-contracts` where contracts are present.
- Soldeer reported a version resolution hiccup for `murky@1.1.10`. If reproducible, re-pin or regenerate the lockfile.

### Next steps

- Implement the two `SimplifiedEscrowFactory` fixes and re-run the suite.
- Add a targeted test for clone salt equality (hash vs hashMem) to prevent regressions.
- Optionally, add a CI step that runs the dual-chain smoke using forked RPCs with sanitized env placeholders.

### Outcome

- With the primary factories, the contracts are **ready** for atomic swaps orchestrated by the TS resolver.
- With the simplified factory, apply the minimal fixes above to pass the last E2E test and achieve full readiness.


