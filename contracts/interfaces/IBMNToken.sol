// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title IBMNToken
 * @notice Interface for the BMN (Bridge Me Not) token deployed at 0xe666570DDa40948c6Ba9294440ffD28ab59C8325
 * @dev The BMN token is deployed using CREATE3 for deterministic cross-chain addresses
 */
interface IBMNToken is IERC20 {
    /**
     * @notice Burns a specific amount of tokens from the caller's balance
     * @param amount The amount of tokens to burn
     */
    function burn(uint256 amount) external;

    /**
     * @notice Burns a specific amount of tokens from a given address
     * @param from The address to burn tokens from
     * @param amount The amount of tokens to burn
     * @dev Requires prior approval from the token holder
     */
    function burnFrom(address from, uint256 amount) external;

    /**
     * @notice Returns the owner of the token contract
     * @return The address of the owner
     */
    function owner() external view returns (address);
}