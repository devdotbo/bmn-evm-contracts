// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "./BaseExtension.sol";

/**
 * @title ResolverValidationExtension
 * @notice Functional implementation for resolver whitelisting and validation
 * @dev Manages resolver whitelist with admin controls and performance tracking
 */
abstract contract ResolverValidationExtension is BaseExtension {
    // Events for resolver management
    event ResolverAdded(address indexed resolver, address indexed addedBy);
    event ResolverRemoved(address indexed resolver, address indexed removedBy);
    event ResolverSuspended(address indexed resolver, uint256 until, string reason);
    event ResolverReactivated(address indexed resolver);
    event AdminAdded(address indexed admin);
    event AdminRemoved(address indexed admin);
    
    // Resolver information structure
    struct ResolverInfo {
        bool isWhitelisted;
        bool isActive;
        uint256 addedAt;
        uint256 suspendedUntil;
        uint256 totalTransactions;
        uint256 failedTransactions;
        address addedBy;
    }
    
    // State variables
    mapping(address => ResolverInfo) public resolvers;
    mapping(address => bool) public admins;
    address[] public resolverList;
    
    // Constants
    uint256 private constant MAX_RESOLVERS = 100;
    uint256 private constant MIN_RESOLVER_STAKE = 0.01 ether; // Minimum stake for resolvers
    uint256 private constant MAX_FAILURE_RATE = 10; // Max 10% failure rate
    
    // Owner address (set in constructor of derived contract)
    address internal _owner;
    
    /**
     * @notice Initialize the extension with the contract owner
     * @dev Should be called in the constructor of the derived contract
     */
    function _initializeResolverExtension() internal {
        _owner = msg.sender;
        admins[msg.sender] = true;
        emit AdminAdded(msg.sender);
    }
    
    /**
     * @notice Add a new resolver to the whitelist
     * @param resolver Address to add as resolver
     */
    function addResolver(address resolver) external onlyAdmin {
        require(resolver != address(0), "ResolverValidation: Zero address");
        require(!resolvers[resolver].isWhitelisted, "ResolverValidation: Already whitelisted");
        require(resolverList.length < MAX_RESOLVERS, "ResolverValidation: Max resolvers reached");
        
        // Check resolver has minimum stake (balance)
        require(
            resolver.balance >= MIN_RESOLVER_STAKE,
            "ResolverValidation: Insufficient stake"
        );
        
        resolvers[resolver] = ResolverInfo({
            isWhitelisted: true,
            isActive: true,
            addedAt: block.timestamp,
            suspendedUntil: 0,
            totalTransactions: 0,
            failedTransactions: 0,
            addedBy: msg.sender
        });
        
        resolverList.push(resolver);
        emit ResolverAdded(resolver, msg.sender);
    }
    
    /**
     * @notice Remove a resolver from the whitelist
     * @param resolver Address to remove
     */
    function removeResolver(address resolver) external onlyAdmin {
        require(resolvers[resolver].isWhitelisted, "ResolverValidation: Not whitelisted");
        
        resolvers[resolver].isWhitelisted = false;
        resolvers[resolver].isActive = false;
        
        // Remove from resolver list
        for (uint i = 0; i < resolverList.length; i++) {
            if (resolverList[i] == resolver) {
                resolverList[i] = resolverList[resolverList.length - 1];
                resolverList.pop();
                break;
            }
        }
        
        emit ResolverRemoved(resolver, msg.sender);
    }
    
    /**
     * @notice Suspend a resolver temporarily
     * @param resolver Address to suspend
     * @param duration Suspension duration in seconds
     * @param reason Reason for suspension
     */
    function suspendResolver(
        address resolver,
        uint256 duration,
        string calldata reason
    ) external onlyAdmin {
        require(resolvers[resolver].isWhitelisted, "ResolverValidation: Not whitelisted");
        require(duration > 0 && duration <= 30 days, "ResolverValidation: Invalid duration");
        
        resolvers[resolver].isActive = false;
        resolvers[resolver].suspendedUntil = block.timestamp + duration;
        
        emit ResolverSuspended(resolver, resolvers[resolver].suspendedUntil, reason);
    }
    
    /**
     * @notice Reactivate a suspended resolver
     * @param resolver Address to reactivate
     */
    function reactivateResolver(address resolver) external onlyAdmin {
        require(resolvers[resolver].isWhitelisted, "ResolverValidation: Not whitelisted");
        require(!resolvers[resolver].isActive, "ResolverValidation: Already active");
        
        resolvers[resolver].isActive = true;
        resolvers[resolver].suspendedUntil = 0;
        
        emit ResolverReactivated(resolver);
    }
    
    /**
     * @notice Check if address is a whitelisted and active resolver
     * @param resolver Address to check
     * @return bool True if resolver is valid
     */
    function isWhitelistedResolver(address resolver) public view virtual returns (bool) {
        if (!resolvers[resolver].isWhitelisted) return false;
        if (!resolvers[resolver].isActive) return false;
        
        // Check if suspension period has passed
        if (resolvers[resolver].suspendedUntil > 0) {
            if (block.timestamp < resolvers[resolver].suspendedUntil) {
                return false;
            }
        }
        
        // Check failure rate
        if (resolvers[resolver].totalTransactions > 100) {
            uint256 failureRate = (resolvers[resolver].failedTransactions * 100) / 
                                  resolvers[resolver].totalTransactions;
            if (failureRate > MAX_FAILURE_RATE) {
                return false;
            }
        }
        
        // Check resolver still has minimum stake
        if (resolver.balance < MIN_RESOLVER_STAKE) {
            return false;
        }
        
        return true;
    }
    
    /**
     * @notice Record a resolver transaction (success or failure)
     * @param resolver Address of the resolver
     * @param success Whether the transaction was successful
     */
    function _recordResolverTransaction(address resolver, bool success) internal {
        if (!resolvers[resolver].isWhitelisted) return;
        
        resolvers[resolver].totalTransactions++;
        if (!success) {
            resolvers[resolver].failedTransactions++;
            
            // Auto-suspend if failure rate exceeds threshold
            if (resolvers[resolver].totalTransactions > 10) {
                uint256 failureRate = (resolvers[resolver].failedTransactions * 100) / 
                                      resolvers[resolver].totalTransactions;
                if (failureRate > MAX_FAILURE_RATE * 2) { // Double threshold for auto-suspend
                    resolvers[resolver].isActive = false;
                    resolvers[resolver].suspendedUntil = block.timestamp + 1 hours;
                    emit ResolverSuspended(resolver, resolvers[resolver].suspendedUntil, "Auto: High failure rate");
                }
            }
        }
    }
    
    /**
     * @notice Get list of all active resolvers
     * @return address[] Array of active resolver addresses
     */
    function getActiveResolvers() external view returns (address[] memory) {
        uint256 activeCount = 0;
        for (uint i = 0; i < resolverList.length; i++) {
            if (isWhitelistedResolver(resolverList[i])) {
                activeCount++;
            }
        }
        
        address[] memory activeResolvers = new address[](activeCount);
        uint256 index = 0;
        for (uint i = 0; i < resolverList.length; i++) {
            if (isWhitelistedResolver(resolverList[i])) {
                activeResolvers[index++] = resolverList[i];
            }
        }
        
        return activeResolvers;
    }
    
    /**
     * @notice Add an admin
     * @param admin Address to add as admin
     */
    function addAdmin(address admin) external onlyOwner {
        require(admin != address(0), "ResolverValidation: Zero address");
        require(!admins[admin], "ResolverValidation: Already admin");
        
        admins[admin] = true;
        emit AdminAdded(admin);
    }
    
    /**
     * @notice Remove an admin
     * @param admin Address to remove as admin
     */
    function removeAdmin(address admin) external onlyOwner {
        require(admins[admin], "ResolverValidation: Not an admin");
        require(admin != _owner, "ResolverValidation: Cannot remove owner");
        
        admins[admin] = false;
        emit AdminRemoved(admin);
    }
    
    /**
     * @notice Modifier to check if caller is whitelisted resolver
     */
    modifier onlyWhitelistedResolver() {
        require(isWhitelistedResolver(msg.sender), "ResolverValidation: Not a whitelisted resolver");
        _;
    }
    
    /**
     * @notice Modifier to check if caller is admin
     */
    modifier onlyAdmin() {
        require(admins[msg.sender], "ResolverValidation: Not an admin");
        _;
    }
    
    /**
     * @notice Modifier to check if caller is owner
     */
    modifier onlyOwner() {
        require(msg.sender == _owner, "ResolverValidation: Not owner");
        _;
    }
    
    /**
     * @notice Override _validateInteraction to add resolver-specific checks
     */
    function _validateInteraction(
        address orderMaker,
        address interactionTarget,
        bytes calldata interaction
    ) internal virtual override {
        // Additional validation: interaction target should not be a resolver
        // unless it's a self-interaction
        if (resolvers[interactionTarget].isWhitelisted && interactionTarget != orderMaker) {
            revert("ResolverValidation: Cannot interact with resolver contracts");
        }
        
        // Call parent validation
        super._validateInteraction(orderMaker, interactionTarget, interaction);
    }
}