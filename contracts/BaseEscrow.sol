// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { AddressLib, Address } from "solidity-utils/contracts/libraries/AddressLib.sol";
import { SafeERC20 } from "solidity-utils/contracts/libraries/SafeERC20.sol";

import { ImmutablesLib } from "./libraries/ImmutablesLib.sol";
import { Timelocks, TimelocksLib } from "./libraries/TimelocksLib.sol";

import { IBaseEscrow } from "./interfaces/IBaseEscrow.sol";
import { IResolverValidation } from "./interfaces/IResolverValidation.sol";
import { SoladyEIP712 } from "./utils/SoladyEIP712.sol";

/**
 * @title Base abstract Escrow contract for cross-chain atomic swap.
 * @dev {IBaseEscrow-withdraw}, {IBaseEscrow-cancel} and _validateImmutables functions must be implemented in the derived contracts.
 * @custom:security-contact security@1inch.io
 */
abstract contract BaseEscrow is IBaseEscrow, SoladyEIP712 {
    using AddressLib for Address;
    using SafeERC20 for IERC20;
    using TimelocksLib for Timelocks;
    using ImmutablesLib for Immutables;

    // Token that is used to access public withdraw or cancel functions.
    IERC20 private immutable _ACCESS_TOKEN;

    /// @notice See {IBaseEscrow-RESCUE_DELAY}.
    uint256 public immutable RESCUE_DELAY;
    /// @notice See {IBaseEscrow-FACTORY}.
    address public immutable FACTORY = msg.sender;

    constructor(uint32 rescueDelay, IERC20 accessToken) {
        RESCUE_DELAY = rescueDelay;
        _ACCESS_TOKEN = accessToken;
    }

    function _domainNameAndVersion() internal pure override returns (string memory name, string memory version) {
        name = "BMN-Escrow";
        version = "2.3";
    }

    modifier onlyTaker(Immutables calldata immutables) {
        if (msg.sender != immutables.taker.get()) revert InvalidCaller();
        _;
    }

    modifier onlyValidImmutables(Immutables calldata immutables) virtual {
        _validateImmutables(immutables);
        _;
    }

    modifier onlyValidSecret(bytes32 secret, Immutables calldata immutables) {
        if (_keccakBytes32(secret) != immutables.hashlock) revert InvalidSecret();
        _;
    }

    modifier onlyAfter(uint256 start) {
        if (block.timestamp < start) revert InvalidTime();
        _;
    }

    modifier onlyBefore(uint256 stop) {
        if (block.timestamp >= stop) revert InvalidTime();
        _;
    }

    modifier onlyAccessTokenHolder() {
        if (_ACCESS_TOKEN.balanceOf(msg.sender) == 0) revert InvalidCaller();
        _;
    }

    // ============ EIP-712 Typed Data Helpers ============
    bytes32 internal constant _PUBLIC_ACTION_TYPEHASH = keccak256(
        "PublicAction(bytes32 orderHash,address caller,string action)"
    );

    function _hashPublicAction(bytes32 orderHash, address caller, string memory action)
        public
        view
        returns (bytes32)
    {
        bytes32 structHash = keccak256(
            abi.encode(_PUBLIC_ACTION_TYPEHASH, orderHash, caller, keccak256(bytes(action)))
        );
        return _hashTypedData(structHash);
    }

    function _requireValidResolverSig(
        bytes32 orderHash,
        string memory action,
        bytes calldata signature
    ) internal view {
        // Resolve whitelist from factory
        address factory = FACTORY;
        address recovered = _recover(_hashPublicAction(orderHash, msg.sender, action), signature);
        if (!IResolverValidation(factory).isWhitelistedResolver(recovered)) revert InvalidCaller();
    }

    function _recover(bytes32 digest, bytes calldata sig) public pure returns (address signer) {
        if (sig.length != 65) return address(0);
        bytes32 r;
        bytes32 s;
        uint8 v;
        assembly {
            r := calldataload(sig.offset)
            s := calldataload(add(sig.offset, 32))
            v := byte(0, calldataload(add(sig.offset, 64)))
        }
        signer = ecrecover(digest, v, r, s);
    }

    /**
     * @notice See {IBaseEscrow-rescueFunds}.
     */
    function rescueFunds(address token, uint256 amount, Immutables calldata immutables)
        external
        onlyTaker(immutables)
        onlyValidImmutables(immutables)
        onlyAfter(immutables.timelocks.rescueStart(RESCUE_DELAY))
    {
        _uniTransfer(token, msg.sender, amount);
        emit FundsRescued(token, amount);
    }

    /**
     * @dev Transfers ERC20 or native tokens to the recipient.
     */
    function _uniTransfer(address token, address to, uint256 amount) internal {
        if (token == address(0)) {
            _ethTransfer(to, amount);
        } else {
            IERC20(token).safeTransfer(to, amount);
        }
    }

    /**
     * @dev Transfers native tokens to the recipient.
     */
    function _ethTransfer(address to, uint256 amount) internal {
        (bool success,) = to.call{ value: amount }("");
        if (!success) revert NativeTokenSendingFailure();
    }

    /**
     * @dev Should verify that the computed escrow address matches the address of this contract.
     */
    function _validateImmutables(Immutables calldata immutables) internal view virtual;

    /**
     * @dev Computes the Keccak-256 hash of the secret.
     * @param secret The secret that unlocks the escrow.
     * @return ret The computed hash.
     */
    function _keccakBytes32(bytes32 secret) private pure returns (bytes32 ret) {
        assembly ("memory-safe") {
            mstore(0, secret)
            ret := keccak256(0, 0x20)
        }
    }
}
