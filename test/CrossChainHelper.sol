// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { Test } from "forge-std/Test.sol";
import { IOrderMixin } from "limit-order-protocol/contracts/interfaces/IOrderMixin.sol";
import { IBaseEscrow } from "../contracts/interfaces/IBaseEscrow.sol";

contract CrossChainHelper is Test {
    // Helper to build order data
    function buildOrder(
        address maker,
        address makerAsset,
        address takerAsset,
        uint256 makingAmount,
        uint256 takingAmount,
        address receiver
    ) public pure returns (IOrderMixin.Order memory) {
        // Simplified order creation
        // Add your order building logic here
    }

    // Helper to create timelocks
    function createTimelocks() public view returns (uint256) {
        // Create timelocks with current timestamp
        // Return encoded timelocks
    }
}