// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { ERC20 } from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import { Ownable } from "openzeppelin-contracts/contracts/access/Ownable.sol";

/**
 * @title BMNToken
 * @notice Bridge Me Not token with fixed supply
 * @dev Local version compatible with Solidity 0.8.23
 */
contract BMNToken is ERC20, Ownable {
    uint256 public constant TOTAL_SUPPLY = 10_000_000 * 10**18;
    
    constructor(address mintTo) ERC20("Bridge Me Not", "BMN") Ownable(mintTo) {
        _mint(mintTo, TOTAL_SUPPLY);
    }
    
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }
    
    function burnFrom(address from, uint256 amount) external {
        uint256 currentAllowance = allowance(from, msg.sender);
        if (currentAllowance != type(uint256).max) {
            _spendAllowance(from, msg.sender, amount);
        }
        _burn(from, amount);
    }
}