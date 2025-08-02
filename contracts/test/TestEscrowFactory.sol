// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "../EscrowFactory.sol";
import {ImmutablesLib} from "../libraries/ImmutablesLib.sol";
import {ProxyHashLib} from "../libraries/ProxyHashLib.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title TestEscrowFactory
 * @notice Test-specific factory that allows direct source escrow creation for testing
 * @dev DO NOT USE IN PRODUCTION - This bypasses security checks
 */
contract TestEscrowFactory is EscrowFactory {
    using SafeERC20 for IERC20;
    using ImmutablesLib for ImmutablesLib.Immutables;

    constructor(
        address limitOrderProtocol,
        address dai,
        address accessToken,
        address feeToken,
        address owner,
        address weth,
        address permit2,
        address daiWethOracle
    ) EscrowFactory(
        limitOrderProtocol,
        dai,
        accessToken,
        feeToken,
        owner,
        weth,
        permit2,
        daiWethOracle
    ) {}

    /**
     * @notice Create source escrow directly for testing purposes
     * @dev This bypasses the limit order protocol flow
     * @param immutables The escrow immutables
     * @param prefundAmount Amount to prefund the escrow with
     * @return escrow The deployed escrow address
     */
    function createSrcEscrowForTesting(
        ImmutablesLib.Immutables calldata immutables,
        uint256 prefundAmount
    ) external returns (address escrow) {
        // Deploy the escrow using CREATE2
        bytes32 salt = immutables.hashMem();
        escrow = Clones.cloneDeterministic(ESCROW_SRC_IMPLEMENTATION, salt);
        
        // If prefunding is requested, transfer tokens to the escrow
        if (prefundAmount > 0) {
            IERC20(immutables.token).safeTransferFrom(msg.sender, escrow, prefundAmount);
        }
        
        // Emit the event as if it was created normally
        emit SrcEscrowCreated(escrow, immutables.taker, immutables);
        
        return escrow;
    }

    /**
     * @notice Deploy source escrow and transfer tokens from factory balance
     * @dev Used when factory already holds the tokens (simulating limit order protocol)
     * @param immutables The escrow immutables
     * @return escrow The deployed escrow address
     */
    function deploySrcEscrowWithFactoryTokens(
        ImmutablesLib.Immutables calldata immutables
    ) external returns (address escrow) {
        // Deploy the escrow using CREATE2
        bytes32 salt = immutables.hashMem();
        escrow = Clones.cloneDeterministic(ESCROW_SRC_IMPLEMENTATION, salt);
        
        // Transfer tokens from factory to escrow
        // This simulates what would happen in postInteraction
        IERC20(immutables.token).safeTransfer(escrow, immutables.amount);
        
        // Emit the event
        emit SrcEscrowCreated(escrow, immutables.taker, immutables);
        
        return escrow;
    }

    /**
     * @notice Get the deterministic address for a source escrow
     * @param immutables The escrow immutables
     * @return The computed escrow address
     */
    function computeSrcEscrowAddress(
        ImmutablesLib.Immutables calldata immutables
    ) external view returns (address) {
        bytes32 salt = immutables.hashMem();
        return Clones.predictDeterministicAddress(
            ESCROW_SRC_IMPLEMENTATION,
            salt,
            address(this)
        );
    }
}