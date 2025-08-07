// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "solidity-utils/contracts/libraries/SafeERC20.sol";
import { IPostInteraction } from "../../dependencies/limit-order-protocol/contracts/interfaces/IPostInteraction.sol";
import { IOrderMixin } from "../../dependencies/limit-order-protocol/contracts/interfaces/IOrderMixin.sol";
import { Address, AddressLib } from "solidity-utils/contracts/libraries/AddressLib.sol";

/**
 * @title MockLimitOrderProtocol
 * @notice Mock implementation of 1inch SimpleLimitOrderProtocol for testing
 */
contract MockLimitOrderProtocol {
    using SafeERC20 for IERC20;
    using AddressLib for Address;
    
    event OrderFilled(bytes32 orderHash, uint256 makingAmount);
    
    /**
     * @notice Simulates filling an order with post-interaction callback
     * @param order Order to fill
     * @param signature Signature (unused in mock)
     * @param makingAmount Amount to fill
     * @param takerTraits Taker traits (unused in mock)
     * @param extension Extension address to call postInteraction on
     * @param extensionData Data to pass to postInteraction
     */
    function fillOrderWithPostInteraction(
        IOrderMixin.Order memory order,
        bytes memory signature,
        uint256 makingAmount,
        uint256 takerTraits,
        address extension,
        bytes memory extensionData
    ) external {
        // Calculate order hash
        bytes32 orderHash = keccak256(abi.encode(order));
        
        // Transfer tokens from maker to taker (msg.sender)
        IERC20(order.makerAsset.get()).safeTransferFrom(
            order.maker.get(), 
            msg.sender, 
            makingAmount
        );
        
        // Transfer tokens from taker to maker
        IERC20(order.takerAsset.get()).safeTransferFrom(
            msg.sender,
            order.maker.get(),
            order.takingAmount
        );
        
        // Call postInteraction on extension
        IPostInteraction(extension).postInteraction(
            order,
            abi.encodePacked(extension),
            orderHash,
            msg.sender,
            makingAmount,
            order.takingAmount,
            0, // remainingMakingAmount
            extensionData
        );
        
        emit OrderFilled(orderHash, makingAmount);
    }
    
    /**
     * @notice Simulates a simple order fill without post-interaction
     * @param order Order to fill
     * @param makingAmount Amount to fill
     */
    function fillOrder(
        IOrderMixin.Order memory order,
        uint256 makingAmount
    ) external {
        bytes32 orderHash = keccak256(abi.encode(order));
        
        // Transfer tokens
        IERC20(order.makerAsset.get()).safeTransferFrom(
            order.maker.get(),
            msg.sender,
            makingAmount
        );
        
        IERC20(order.takerAsset.get()).safeTransferFrom(
            msg.sender,
            order.maker.get(),
            order.takingAmount
        );
        
        emit OrderFilled(orderHash, makingAmount);
    }
}