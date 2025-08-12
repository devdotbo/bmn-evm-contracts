# BMN Contracts v2.3.0 – Resolver & Indexer Integration Notes

> Read this fully before deploying/updating your services. This version introduces EIP-712 resolver-signed actions.

## Summary

- Deployed new factory (v2.3.0) deterministically via CREATE3 on both Base and Optimism.
- Escrow contracts now support resolver-signed public actions using EIP-712.
- Token-gated public methods remain for backward compatibility but resolvers should migrate to EIP-712.

## Chain Data

- Factory v2.3 address (Base and Optimism): `0xdebE6F4bC7BaAD2266603Ba7AfEB3BB6dDA9FE0A`
- Base deployment block height: see `deployments/v2.3.0-mainnet-8453.env`
- Optimism deployment block height: see `deployments/v2.3.0-mainnet-10.env`
- BMN token: `0x8287CD2aC7E227D9D927F998EB600a0683a832A1`

Files:
- `deployments/v2.3.0-mainnet-8453.env`
- `deployments/v2.3.0-mainnet-10.env`

Both env files contain the factory address and chain id for your config ingestion.

## What Changed

- Escrow contracts gained signed variants of public actions:
  - `EscrowSrc.publicWithdrawSigned(bytes32 secret, Immutables immutables, bytes resolverSignature)`
  - `EscrowSrc.publicCancelSigned(Immutables immutables, bytes resolverSignature)`
  - `EscrowDst.publicWithdrawSigned(bytes32 secret, Immutables immutables, bytes resolverSignature)`
  - `EscrowDst.publicCancelSigned(Immutables immutables, bytes resolverSignature)`
- Signer must be a whitelisted resolver in the factory. The factory exposes `isWhitelistedResolver(address)` for that check.
- EIP-712 domain added in `BaseEscrow` using Solady-style helper.
- Domain:
  - name: `BMN-Escrow`
  - version: `2.3`
  - chainId: runtime `block.chainid`
  - verifyingContract: escrow clone address (not the factory)
- Struct hashed for signed calls:
  - Type: `PublicAction(bytes32 orderHash,address caller,string action)`
  - Typehash: `0xd6ae97ebc6a7fcc26983b667d1787f39e1b4383b40a13b0c604f9aa744952bb3`
  - Digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash))
  - `caller` is the msg.sender that will submit the tx (resolver process); `action` is one of:
    - `SRC_PUBLIC_WITHDRAW`
    - `SRC_PUBLIC_CANCEL`
    - `DST_PUBLIC_WITHDRAW`
    - `DST_PUBLIC_CANCEL`

Important: Each escrow clone has its own verifyingContract (the clone address), so the domain separator differs per escrow. Resolvers must build the domain with the target escrow address.

## Resolver Action Plan

1. Update config to include v2.3 factory address for both chains.
   - Load from:
     - `deployments/v2.3.0-mainnet-8453.env`
     - `deployments/v2.3.0-mainnet-10.env`
2. When executing a public action on an escrow clone:
   - Compute the domain separator using:
     - name="BMN-Escrow", version="2.3", chainId=current chain, verifyingContract=escrowCloneAddress
   - Build struct hash: `PublicAction(orderHash, caller, action)`
   - Sign with resolver key (eth_signTypedData_v4 preferred).
   - Prepare calldata with `resolverSignature` (65 bytes r||s||v) and call the corresponding `public*Signed` function.
3. Ensure the resolver address is whitelisted in the factory once per chain.
4. Continue supporting token-gated public calls in fallback mode only. Prefer signed calls.

## Indexer Action Plan

- Factory address changed (v2.3). Update your address list.
- Track events from new factory (and escrows it creates). The factory deploys implementations in its constructor so `FACTORY` inside escrows points to the correct address.
- No event schema changes in escrows vs v2.2, but new signed methods affect who calls public actions:
  - You should not assume the caller holds BMN tokens; instead, the caller is a whitelisted resolver with a valid EIP-712 signature.
- For verification/debug, you can recompute the digest as above.

## Artifacts & ABIs to Copy

Copy these ABIs into the resolver and indexer projects:
- `out/SimplifiedEscrowFactoryV2_3.sol/SimplifiedEscrowFactoryV2_3.json`
- `out/EscrowSrc.sol/EscrowSrc.json`
- `out/EscrowDst.sol/EscrowDst.json`
- `out/BaseEscrow.sol/BaseEscrow.json` (for reference of helper views if needed)

Note: Builds are in `out/` after `forge build`.

## Backward Compatibility

- Legacy token-gated public methods remain available.
- EIP-712 signed methods are additive.
- The factory also exposes `isWhitelistedResolver(address)` for compatibility checks used by escrows.

## Example Pseudocode (Resolver)

```ts
// Build domain
const domain = {
  name: "BMN-Escrow",
  version: "2.3",
  chainId,
  verifyingContract: escrowCloneAddress,
};

// Types
const types = {
  PublicAction: [
    { name: "orderHash", type: "bytes32" },
    { name: "caller", type: "address" },
    { name: "action", type: "string" },
  ],
};

// Message
const message = {
  orderHash,
  caller: resolverAddress,
  action: "SRC_PUBLIC_WITHDRAW", // or other action
};

// Signature (EIP-712)
const signature = await wallet._signTypedData(domain, types, message);

// On-chain call
await escrowSrc.publicWithdrawSigned(secret, immutables, signature);
```

## Verification Links

- Base explorer: use the factory address from `deployments/v2.3.0-mainnet-8453.env`
- Optimism explorer: use the factory address from `deployments/v2.3.0-mainnet-10.env`

Contracts are verified; the explorer pages display constructor args.

## Contact & Support

- Contracts repo: this repository
- Raise issues or PRs with integration questions

---

Document version: v2.3.0 – August 12, 2025

