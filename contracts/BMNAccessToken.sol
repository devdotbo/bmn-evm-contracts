// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title BMNAccessToken
 * @notice Access control token for Bridge-Me-Not public functions
 * @dev Deployed with CREATE2 to ensure same address on all chains
 */
contract BMNAccessToken is ERC20, Ownable {
    /// @notice Mapping of addresses authorized to receive tokens
    mapping(address => bool) public authorized;
    
    /// @notice Emitted when an address is authorized
    event Authorized(address indexed account);
    
    /// @notice Emitted when an address is deauthorized
    event Deauthorized(address indexed account);
    
    /// @notice Emitted when tokens are minted to an authorized address
    event TokensMinted(address indexed to, uint256 amount);
    
    constructor() ERC20("BMN Access Token", "BMN") Ownable(msg.sender) {
        // Authorize deployer by default
        authorized[msg.sender] = true;
    }
    
    /**
     * @notice Authorize an address to receive tokens
     * @param account The address to authorize
     */
    function authorize(address account) external onlyOwner {
        authorized[account] = true;
        emit Authorized(account);
    }
    
    /**
     * @notice Deauthorize an address
     * @param account The address to deauthorize
     */
    function deauthorize(address account) external onlyOwner {
        authorized[account] = false;
        emit Deauthorized(account);
    }
    
    /**
     * @notice Mint tokens to an authorized address
     * @param to The address to mint to
     * @param amount The amount to mint
     */
    function mint(address to, uint256 amount) external onlyOwner {
        require(authorized[to], "BMNAccessToken: recipient not authorized");
        _mint(to, amount);
        emit TokensMinted(to, amount);
    }
    
    /**
     * @notice Burn tokens from the caller
     * @param amount The amount to burn
     */
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }
    
    /**
     * @notice Override decimals to use 18, the ERC-20 default
     * @return Always returns 18
     */
    function decimals() public pure override returns (uint8) {
        return 18;
    }
}