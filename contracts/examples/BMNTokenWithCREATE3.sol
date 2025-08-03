// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin-contracts-5.0.2/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin-contracts-5.0.2/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin-contracts-5.0.2/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import "@openzeppelin-contracts-5.0.2/contracts/access/Ownable.sol";
import "@solady-0.0.235/utils/CREATE3.sol";

/**
 * @title BMNTokenFactory
 * @notice Factory contract for deploying BMN tokens with deterministic addresses using CREATE3
 * @dev Uses Solady's CREATE3 implementation for cross-chain address determinism
 */
contract BMNTokenFactory {
    using CREATE3 for bytes32;
    
    event TokenDeployed(address indexed token, bytes32 indexed salt, string name, string symbol);
    
    /**
     * @notice Deploy a new BMN token with a deterministic address
     * @param salt Unique salt for CREATE3 deployment
     * @param name Token name
     * @param symbol Token symbol
     * @param initialSupply Initial token supply (in wei)
     * @param owner Address that will own the deployed token
     * @return token The address of the deployed token
     */
    function deployToken(
        bytes32 salt,
        string memory name,
        string memory symbol,
        uint256 initialSupply,
        address owner
    ) external returns (address token) {
        // Encode constructor arguments
        bytes memory creationCode = abi.encodePacked(
            type(BMNToken).creationCode,
            abi.encode(name, symbol, initialSupply, owner)
        );
        
        // Deploy using CREATE3
        token = CREATE3.deploy(salt, creationCode, 0);
        
        emit TokenDeployed(token, salt, name, symbol);
    }
    
    /**
     * @notice Compute the deterministic address for a given salt
     * @param salt The salt to compute the address for
     * @return The deterministic address
     */
    function computeTokenAddress(bytes32 salt) external view returns (address) {
        return CREATE3.predictDeterministicAddress(salt);
    }
    
    /**
     * @notice Check if a token has been deployed at the computed address
     * @param salt The salt to check
     * @return deployed Whether a contract exists at the computed address
     */
    function isDeployed(bytes32 salt) external view returns (bool deployed) {
        address predicted = CREATE3.predictDeterministicAddress(salt);
        uint256 size;
        assembly {
            size := extcodesize(predicted)
        }
        deployed = size > 0;
    }
}

/**
 * @title BMNToken
 * @notice Bridge Me Not (BMN) ERC20 token with burn and pause functionality
 * @dev Deployed via BMNTokenFactory for deterministic addresses
 */
contract BMNToken is ERC20, ERC20Burnable, ERC20Pausable, Ownable {
    uint8 private constant DECIMALS = 18;
    
    /**
     * @notice Constructor for BMN token
     * @param name Token name
     * @param symbol Token symbol  
     * @param initialSupply Initial supply to mint to owner
     * @param owner Address that will own the token contract
     */
    constructor(
        string memory name,
        string memory symbol,
        uint256 initialSupply,
        address owner
    ) ERC20(name, symbol) Ownable(owner) {
        _mint(owner, initialSupply);
    }
    
    /**
     * @notice Pause token transfers
     * @dev Only callable by owner
     */
    function pause() external onlyOwner {
        _pause();
    }
    
    /**
     * @notice Unpause token transfers
     * @dev Only callable by owner
     */
    function unpause() external onlyOwner {
        _unpause();
    }
    
    /**
     * @notice Mint new tokens
     * @dev Only callable by owner
     * @param to Address to mint tokens to
     * @param amount Amount of tokens to mint
     */
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
    
    /**
     * @notice Override decimals to ensure consistency
     * @return Token decimals (always 18)
     */
    function decimals() public pure override returns (uint8) {
        return DECIMALS;
    }
    
    /**
     * @dev Override required by Solidity for multiple inheritance
     */
    function _update(
        address from,
        address to,
        uint256 value
    ) internal override(ERC20, ERC20Pausable) {
        super._update(from, to, value);
    }
}

/**
 * @title BMNTokenFactoryWithSolmate
 * @notice Alternative factory using Solmate's CREATE3 (if you prefer Solmate over Solady)
 * @dev Demonstrates how to use Solmate's CREATE3 implementation
 */
contract BMNTokenFactoryWithSolmate {
    // If using Solmate instead of Solady
    // import "@solmate-7/utils/CREATE3.sol";
    
    // Implementation would be similar but using Solmate's CREATE3 syntax
    // This is just a placeholder to show the alternative
}