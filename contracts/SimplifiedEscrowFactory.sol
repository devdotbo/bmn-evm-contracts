// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { Clones } from "openzeppelin-contracts/contracts/proxy/Clones.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "solidity-utils/contracts/libraries/SafeERC20.sol";
import { IBaseEscrow } from "./interfaces/IBaseEscrow.sol";
import { ImmutablesLib } from "./libraries/ImmutablesLib.sol";
import { Timelocks, TimelocksLib } from "./libraries/TimelocksLib.sol";
import { Address, AddressLib } from "solidity-utils/contracts/libraries/AddressLib.sol";
import { IPostInteraction } from "../dependencies/limit-order-protocol/contracts/interfaces/IPostInteraction.sol";
import { IOrderMixin } from "../dependencies/limit-order-protocol/contracts/interfaces/IOrderMixin.sol";

/**
 * @title SimplifiedEscrowFactory
 * @notice Minimal factory for immediate mainnet deployment
 * @dev Stripped down version focusing on core functionality and security
 */
contract SimplifiedEscrowFactory is IPostInteraction {
    using Clones for address;
    using SafeERC20 for IERC20;
    using ImmutablesLib for IBaseEscrow.Immutables;
    using TimelocksLib for Timelocks;
    using AddressLib for Address;
    
    /// @notice Escrow implementation addresses
    address public immutable ESCROW_SRC_IMPLEMENTATION;
    address public immutable ESCROW_DST_IMPLEMENTATION;
    
    /// @notice Contract owner
    address public owner;
    
    /// @notice Emergency pause state
    bool public emergencyPaused;
    
    /// @notice Whitelisted resolvers
    mapping(address => bool) public whitelistedResolvers;
    
    /// @notice Whitelisted makers (optional additional security)
    mapping(address => bool) public whitelistedMakers;
    
    /// @notice Track deployed escrows
    mapping(bytes32 => address) public escrows;
    
    /// @notice Resolver count for metrics
    uint256 public resolverCount;
    
    /// @notice Maker whitelist enabled flag
    bool public makerWhitelistEnabled;
    
    /// @notice Whitelist bypass flag for testing
    bool public whitelistBypassed;
    
    /// @notice Events
    event SrcEscrowCreated(
        address indexed escrow,
        bytes32 indexed orderHash,
        address indexed maker,
        address taker,
        uint256 amount
    );
    
    event DstEscrowCreated(
        address indexed escrow,
        bytes32 indexed hashlock,
        address indexed taker
    );
    
    event ResolverWhitelisted(address indexed resolver);
    event ResolverRemoved(address indexed resolver);
    event MakerWhitelisted(address indexed maker);
    event MakerRemoved(address indexed maker);
    event EmergencyPause(bool paused);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event PostInteractionEscrowCreated(
        address indexed escrow,
        bytes32 indexed hashlock,
        address indexed protocol,
        address taker,
        uint256 amount
    );
    
    /// @notice Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }
    
    modifier whenNotPaused() {
        require(!emergencyPaused, "Protocol paused");
        _;
    }
    
    modifier onlyWhitelistedResolver() {
        require(whitelistBypassed || whitelistedResolvers[msg.sender], "Not whitelisted resolver");
        _;
    }
    
    /**
     * @notice Constructor
     * @param srcImpl Source escrow implementation
     * @param dstImpl Destination escrow implementation
     * @param _owner Contract owner
     */
    constructor(
        address srcImpl,
        address dstImpl,
        address _owner
    ) {
        require(srcImpl != address(0), "Invalid src implementation");
        require(dstImpl != address(0), "Invalid dst implementation");
        require(_owner != address(0), "Invalid owner");
        
        ESCROW_SRC_IMPLEMENTATION = srcImpl;
        ESCROW_DST_IMPLEMENTATION = dstImpl;
        owner = _owner;
        
        // Default to bypassing whitelist for easier testing
        whitelistBypassed = true;
        
        // Whitelist owner as initial resolver for testing
        whitelistedResolvers[_owner] = true;
        resolverCount = 1;
        emit ResolverWhitelisted(_owner);
    }
    
    /**
     * @notice Create source escrow
     * @param immutables Escrow parameters
     * @param maker Order maker address
     * @param token Token to be escrowed
     * @param amount Amount to escrow
     */
    function createSrcEscrow(
        IBaseEscrow.Immutables calldata immutables,
        address maker,
        address token,
        uint256 amount
    ) external whenNotPaused returns (address escrow) {
        // Validate maker if whitelist is enabled
        if (makerWhitelistEnabled) {
            require(whitelistedMakers[maker], "Maker not whitelisted");
        }
        
        // Deploy escrow
        bytes32 salt = immutables.hash();
        escrow = ESCROW_SRC_IMPLEMENTATION.cloneDeterministic(salt);
        
        // Track escrow
        escrows[salt] = escrow;
        
        // Transfer tokens to escrow
        IERC20(token).safeTransferFrom(msg.sender, escrow, amount);
        
        emit SrcEscrowCreated(
            escrow,
            immutables.orderHash,
            maker,
            immutables.taker.get(),
            amount
        );
    }
    
    /**
     * @notice Create destination escrow (resolver only)
     * @param immutables Escrow parameters
     */
    function createDstEscrow(
        IBaseEscrow.Immutables calldata immutables
    ) external payable whenNotPaused onlyWhitelistedResolver returns (address escrow) {
        // Deploy escrow
        bytes32 salt = immutables.hash();
        escrow = ESCROW_DST_IMPLEMENTATION.cloneDeterministic(salt, msg.value);
        
        // Track escrow
        escrows[salt] = escrow;
        
        // Handle token transfer if not native
        address token = immutables.token.get();
        if (token != address(0)) {
            IERC20(token).safeTransferFrom(msg.sender, escrow, immutables.amount);
        }
        
        emit DstEscrowCreated(escrow, immutables.hashlock, immutables.taker.get());
    }
    
    /**
     * @notice Get escrow address for given parameters
     */
    function addressOfEscrow(
        IBaseEscrow.Immutables calldata immutables,
        bool isSrc
    ) external view returns (address) {
        address implementation = isSrc ? ESCROW_SRC_IMPLEMENTATION : ESCROW_DST_IMPLEMENTATION;
        return Clones.predictDeterministicAddress(implementation, immutables.hash(), address(this));
    }
    
    /**
     * @notice Called by SimpleLimitOrderProtocol after order fill
     * @dev Decodes extension data and creates source escrow
     * @param order The order that was filled
     * @param orderHash The hash of the filled order
     * @param taker Address that filled the order (resolver)
     * @param makingAmount Amount of maker asset transferred
     * @param extraData Encoded parameters for escrow creation
     */
    function postInteraction(
        IOrderMixin.Order calldata order,
        bytes calldata /* extension */,
        bytes32 orderHash,
        address taker,
        uint256 makingAmount,
        uint256 /* takingAmount */,
        uint256 /* remainingMakingAmount */,
        bytes calldata extraData
    ) external override whenNotPaused {
        // Validate resolver
        require(whitelistBypassed || whitelistedResolvers[taker], "Resolver not whitelisted");
        
        // Decode the extraData which contains escrow parameters
        // Format: abi.encode(hashlock, dstChainId, dstToken, deposits, timelocks)
        (
            bytes32 hashlock,
            uint256 dstChainId,
            address dstToken,
            uint256 deposits,
            uint256 timelocks
        ) = abi.decode(extraData, (bytes32, uint256, address, uint256, uint256));
        
        // Prevent duplicate escrows by checking if the hashlock already has an escrow
        require(escrows[hashlock] == address(0), "Escrow already exists");
        
        // Extract safety deposits (packed as: dstDeposit << 128 | srcDeposit)
        uint256 srcSafetyDeposit = deposits & type(uint128).max;
        uint256 dstSafetyDeposit = deposits >> 128;
        
        // Extract timelocks (packed as: srcCancellation << 128 | dstWithdrawal)
        uint256 dstWithdrawalTimestamp = timelocks & type(uint128).max;
        uint256 srcCancellationTimestamp = timelocks >> 128;
        
        // Build timelocks for source escrow by packing values
        // Timelocks stores offsets from deployment time, not absolute timestamps
        uint256 packedTimelocks = uint256(uint32(block.timestamp)) << 224; // deployedAt
        packedTimelocks |= uint256(uint32(0)) << 0; // srcWithdrawal: 0 seconds offset for testing
        packedTimelocks |= uint256(uint32(60)) << 32; // srcPublicWithdrawal: 60 seconds offset for testing
        packedTimelocks |= uint256(uint32(srcCancellationTimestamp - block.timestamp)) << 64; // srcCancellation offset
        packedTimelocks |= uint256(uint32(srcCancellationTimestamp - block.timestamp + 60)) << 96; // srcPublicCancellation offset
        packedTimelocks |= uint256(uint32(dstWithdrawalTimestamp - block.timestamp)) << 128; // dstWithdrawal offset
        packedTimelocks |= uint256(uint32(dstWithdrawalTimestamp - block.timestamp + 60)) << 160; // dstPublicWithdrawal offset
        packedTimelocks |= uint256(uint32(7200)) << 192; // dstCancellation: 2 hours offset
        
        Timelocks srcTimelocks = Timelocks.wrap(packedTimelocks);
        
        // Build immutables for source escrow
        IBaseEscrow.Immutables memory srcImmutables = IBaseEscrow.Immutables({
            orderHash: orderHash,
            hashlock: hashlock,
            maker: Address.wrap(uint160(order.maker.get())),
            taker: Address.wrap(uint160(taker)),
            token: order.makerAsset,
            amount: makingAmount,
            safetyDeposit: srcSafetyDeposit,
            timelocks: srcTimelocks
        });
        
        // Create the source escrow
        address escrowAddress = _createSrcEscrowInternal(srcImmutables);
        
        // The SimpleLimitOrderProtocol has already transferred tokens from maker to taker (resolver)
        // The resolver must have approved this factory to transfer tokens to the escrow
        // We need to transfer them from taker to the escrow
        IERC20(order.makerAsset.get()).safeTransferFrom(taker, escrowAddress, makingAmount);
        
        // Emit event for tracking
        emit PostInteractionEscrowCreated(
            escrowAddress,
            hashlock,
            msg.sender,
            taker,
            makingAmount
        );
    }
    
    /**
     * @notice Internal function to create source escrow
     * @dev Extracted from createSrcEscrow for reuse
     */
    function _createSrcEscrowInternal(
        IBaseEscrow.Immutables memory srcImmutables
    ) internal returns (address escrow) {
        // Deploy escrow using CREATE2
        // Calculate hash manually for memory parameter
        bytes32 salt = keccak256(abi.encode(srcImmutables));
        escrow = ESCROW_SRC_IMPLEMENTATION.cloneDeterministic(salt);
        
        // Track escrow by hashlock for duplicate detection
        escrows[srcImmutables.hashlock] = escrow;
        
        return escrow;
    }
    
    // === Admin Functions ===
    
    /**
     * @notice Add resolver to whitelist
     */
    function addResolver(address resolver) external onlyOwner {
        require(resolver != address(0), "Invalid resolver");
        require(!whitelistedResolvers[resolver], "Already whitelisted");
        
        whitelistedResolvers[resolver] = true;
        resolverCount++;
        emit ResolverWhitelisted(resolver);
    }
    
    /**
     * @notice Remove resolver from whitelist
     */
    function removeResolver(address resolver) external onlyOwner {
        require(whitelistedResolvers[resolver], "Not whitelisted");
        
        whitelistedResolvers[resolver] = false;
        resolverCount--;
        emit ResolverRemoved(resolver);
    }

    /**
     * @notice Compatibility method for resolver checks from escrows
     */
    function isWhitelistedResolver(address resolver) external view returns (bool) {
        return whitelistedResolvers[resolver];
    }
    
    /**
     * @notice Add maker to whitelist
     */
    function addMaker(address maker) external onlyOwner {
        require(maker != address(0), "Invalid maker");
        require(!whitelistedMakers[maker], "Already whitelisted");
        
        whitelistedMakers[maker] = true;
        emit MakerWhitelisted(maker);
    }
    
    /**
     * @notice Remove maker from whitelist
     */
    function removeMaker(address maker) external onlyOwner {
        require(whitelistedMakers[maker], "Not whitelisted");
        
        whitelistedMakers[maker] = false;
        emit MakerRemoved(maker);
    }
    
    /**
     * @notice Enable/disable maker whitelist
     */
    function setMakerWhitelistEnabled(bool enabled) external onlyOwner {
        makerWhitelistEnabled = enabled;
    }
    
    /**
     * @notice Toggle whitelist bypass for testing
     * @param bypassed True to bypass whitelist checks, false to enforce them
     */
    function setWhitelistBypassed(bool bypassed) external onlyOwner {
        whitelistBypassed = bypassed;
    }
    
    /**
     * @notice Emergency pause
     */
    function pause() external onlyOwner {
        emergencyPaused = true;
        emit EmergencyPause(true);
    }
    
    /**
     * @notice Unpause
     */
    function unpause() external onlyOwner {
        emergencyPaused = false;
        emit EmergencyPause(false);
    }
    
    /**
     * @notice Transfer ownership
     */
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid owner");
        
        address previousOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(previousOwner, newOwner);
    }
}