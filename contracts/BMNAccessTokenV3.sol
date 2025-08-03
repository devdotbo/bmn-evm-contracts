// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {ERC20} from "solmate/tokens/ERC20.sol";

/**
 * @title BMNAccessTokenV3
 * @notice Gas-optimized BMN Access Token using solmate
 * @dev Implements access control with owner-only minting and authorization system
 */
contract BMNAccessTokenV3 is ERC20 {
    /*//////////////////////////////////////////////////////////////
                               STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice Contract owner (immutable for gas optimization)
    address public immutable owner;
    
    /// @notice Mapping of authorized addresses that can receive minted tokens
    mapping(address => bool) public authorized;

    /*//////////////////////////////////////////////////////////////
                               EVENTS
    //////////////////////////////////////////////////////////////*/

    event Authorized(address indexed account);
    event Deauthorized(address indexed account);
    event TokensMinted(address indexed to, uint256 amount);
    event TokensBurned(address indexed from, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                               ERRORS
    //////////////////////////////////////////////////////////////*/

    error NotOwner();
    error InvalidOwner();
    error RecipientNotAuthorized();
    error InsufficientBalance();
    error ZeroAddress();
    error ZeroAmount();

    /*//////////////////////////////////////////////////////////////
                             MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _owner) ERC20("BMN Access Token V3", "BMN", 18) {
        if (_owner == address(0)) revert InvalidOwner();
        owner = _owner;
        authorized[_owner] = true;
        emit Authorized(_owner);
    }

    /*//////////////////////////////////////////////////////////////
                           ACCESS CONTROL
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Authorize an address to receive minted tokens
     * @param account The address to authorize
     */
    function authorize(address account) external onlyOwner {
        if (account == address(0)) revert ZeroAddress();
        authorized[account] = true;
        emit Authorized(account);
    }

    /**
     * @notice Remove authorization from an address
     * @param account The address to deauthorize
     */
    function deauthorize(address account) external onlyOwner {
        if (account == address(0)) revert ZeroAddress();
        authorized[account] = false;
        emit Deauthorized(account);
    }

    /**
     * @notice Check if multiple addresses are authorized
     * @param accounts Array of addresses to check
     * @return Array of authorization statuses
     */
    function areAuthorized(address[] calldata accounts) external view returns (bool[] memory) {
        uint256 length = accounts.length;
        bool[] memory results = new bool[](length);
        
        for (uint256 i = 0; i < length;) {
            results[i] = authorized[accounts[i]];
            unchecked { ++i; }
        }
        
        return results;
    }

    /*//////////////////////////////////////////////////////////////
                           TOKEN OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Mint tokens to an authorized address
     * @param to The recipient address (must be authorized)
     * @param amount The amount of tokens to mint
     */
    function mint(address to, uint256 amount) external onlyOwner {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (!authorized[to]) revert RecipientNotAuthorized();
        
        _mint(to, amount);
        emit TokensMinted(to, amount);
    }

    /**
     * @notice Mint initial supply of 10 million tokens to owner
     * @dev Can only be called once when total supply is 0
     */
    function mintInitialSupply() external onlyOwner {
        if (totalSupply != 0) revert("Initial supply already minted");
        
        uint256 initialSupply = 10_000_000 * 10**18; // 10 million tokens
        _mint(owner, initialSupply);
        emit TokensMinted(owner, initialSupply);
    }

    /**
     * @notice Burn tokens from caller's balance
     * @param amount The amount of tokens to burn
     */
    function burn(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();
        if (balanceOf[msg.sender] < amount) revert InsufficientBalance();
        
        _burn(msg.sender, amount);
        emit TokensBurned(msg.sender, amount);
    }

    /**
     * @notice Burn tokens from a specific address (requires approval)
     * @param from The address to burn tokens from
     * @param amount The amount of tokens to burn
     */
    function burnFrom(address from, uint256 amount) external {
        if (from == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            allowance[from][msg.sender] = allowed - amount;
        }
        
        _burn(from, amount);
        emit TokensBurned(from, amount);
    }

    /*//////////////////////////////////////////////////////////////
                           PERMIT SUPPORT
    //////////////////////////////////////////////////////////////*/

    // Solmate's ERC20 already includes permit functionality (EIP-2612)
    // No additional implementation needed

    /*//////////////////////////////////////////////////////////////
                           VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Get contract version
     * @return Version string
     */
    function version() external pure returns (string memory) {
        return "3.0.0";
    }

    /**
     * @notice Check if this is the correct BMN V3 implementation
     * @return Implementation identifier
     */
    function implementation() external pure returns (string memory) {
        return "BMN_V3_SOLMATE";
    }
}