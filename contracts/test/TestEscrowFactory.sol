// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "../EscrowFactory.sol";
import {ImmutablesLib} from "../libraries/ImmutablesLib.sol";
import {IBaseEscrow} from "../interfaces/IBaseEscrow.sol";
import {ProxyHashLib} from "../libraries/ProxyHashLib.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Address, AddressLib} from "solidity-utils/contracts/libraries/AddressLib.sol";

/**
 * @title TestEscrowFactory
 * @notice Test-specific factory that allows direct source escrow creation for testing
 * @dev DO NOT USE IN PRODUCTION - This bypasses security checks
 */
contract TestEscrowFactory is EscrowFactory {
    using SafeERC20 for IERC20;
    using ImmutablesLib for IBaseEscrow.Immutables;
    using AddressLib for Address;

    constructor(
        address limitOrderProtocol,
        IERC20 feeToken,
        IERC20 accessToken,
        address owner,
        uint32 rescueDelaySrc,
        uint32 rescueDelayDst
    ) EscrowFactory(
        limitOrderProtocol,
        feeToken,
        accessToken,
        owner,
        rescueDelaySrc,
        rescueDelayDst
    ) {}

    /**
     * @notice Create source escrow directly for testing purposes
     * @dev This bypasses the limit order protocol flow
     * @param immutables The escrow immutables
     * @param prefundAmount Amount to prefund the escrow with
     * @return escrow The deployed escrow address
     */
    function createSrcEscrowForTesting(
        IBaseEscrow.Immutables calldata immutables,
        uint256 prefundAmount
    ) external returns (address escrow) {
        // Deploy the escrow using CREATE2
        bytes32 salt = immutables.hashMem();
        escrow = Clones.cloneDeterministic(ESCROW_SRC_IMPLEMENTATION, salt);
        
        // If prefunding is requested, transfer tokens to the escrow
        if (prefundAmount > 0) {
            IERC20(address(uint160(Address.unwrap(immutables.token)))).safeTransferFrom(msg.sender, escrow, prefundAmount);
        }
        
        // Emit the event as if it was created normally
        // Need to create the complement data for the event
        DstImmutablesComplement memory complement = DstImmutablesComplement({
            maker: immutables.maker,
            amount: immutables.amount, // In testing, we use 1:1 ratio
            token: immutables.token, // Same token for simplicity
            safetyDeposit: immutables.safetyDeposit,
            chainId: block.chainid
        });
        emit SrcEscrowCreated(immutables, complement);
        
        return escrow;
    }

    /**
     * @notice Deploy source escrow and transfer tokens from factory balance
     * @dev Used when factory already holds the tokens (simulating limit order protocol)
     * @param immutables The escrow immutables
     * @return escrow The deployed escrow address
     */
    function deploySrcEscrowWithFactoryTokens(
        IBaseEscrow.Immutables calldata immutables
    ) external returns (address escrow) {
        // Deploy the escrow using CREATE2
        bytes32 salt = immutables.hashMem();
        escrow = Clones.cloneDeterministic(ESCROW_SRC_IMPLEMENTATION, salt);
        
        // Transfer tokens from factory to escrow
        // This simulates what would happen in postInteraction
        IERC20(address(uint160(Address.unwrap(immutables.token)))).safeTransfer(escrow, immutables.amount);
        
        // Emit the event
        DstImmutablesComplement memory complement = DstImmutablesComplement({
            maker: immutables.maker,
            amount: immutables.amount,
            token: immutables.token,
            safetyDeposit: immutables.safetyDeposit,
            chainId: block.chainid
        });
        emit SrcEscrowCreated(immutables, complement);
        
        return escrow;
    }

    /**
     * @notice Get the deterministic address for a source escrow
     * @param immutables The escrow immutables
     * @return The computed escrow address
     */
    function computeSrcEscrowAddress(
        IBaseEscrow.Immutables calldata immutables
    ) external view returns (address) {
        bytes32 salt = immutables.hashMem();
        return Clones.predictDeterministicAddress(
            ESCROW_SRC_IMPLEMENTATION,
            salt,
            address(this)
        );
    }
}