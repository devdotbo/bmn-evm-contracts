// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { Clones } from "openzeppelin-contracts/contracts/proxy/Clones.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "solidity-utils/contracts/libraries/SafeERC20.sol";
import { IBaseEscrow } from "./interfaces/IBaseEscrow.sol";
import { IEscrowFactory } from "./interfaces/IEscrowFactory.sol";
import { ImmutablesLib } from "./libraries/ImmutablesLib.sol";
import { Timelocks, TimelocksLib } from "./libraries/TimelocksLib.sol";
import { Address, AddressLib } from "solidity-utils/contracts/libraries/AddressLib.sol";
import { ProxyHashLib } from "./libraries/ProxyHashLib.sol";
import { IOrderMixin } from "../dependencies/limit-order-protocol/contracts/interfaces/IOrderMixin.sol";
import { SimpleSettlement } from "../dependencies/limit-order-settlement/contracts/SimpleSettlement.sol";
import { EscrowSrc } from "./EscrowSrc.sol";
import { EscrowDst } from "./EscrowDst.sol";

/**
 * @title SimplifiedEscrowFactory
 * @notice Factory with constructor-based implementation deployment for correct FACTORY immutable capture
 * @dev Inherits from SimpleSettlement for 1inch protocol integration
 */
contract SimplifiedEscrowFactory is SimpleSettlement {
    using Clones for address;
    using SafeERC20 for IERC20;
    using ImmutablesLib for IBaseEscrow.Immutables;
    using TimelocksLib for Timelocks;
    using AddressLib for Address;
    using ProxyHashLib for address;
    
    /// @notice Escrow implementation addresses (deployed in constructor)
    address public immutable ESCROW_SRC_IMPLEMENTATION;
    address public immutable ESCROW_DST_IMPLEMENTATION;
    
    /// @notice Pre-computed proxy bytecode hashes for CREATE2 prediction
    bytes32 public immutable ESCROW_SRC_PROXY_BYTECODE_HASH;
    bytes32 public immutable ESCROW_DST_PROXY_BYTECODE_HASH;
    
    /// @notice Emergency pause state
    bool public emergencyPaused;
    
    /// @notice Whitelisted resolvers
    mapping(address => bool) public whitelistedResolvers;
    
    /// @notice Whitelisted makers (optional additional security)
    mapping(address => bool) public whitelistedMakers;
    
    /// @notice Track deployed escrows
    mapping(bytes32 => address) public escrows;
    
    /// @notice Store immutables for later retrieval (for 1inch compatibility)
    mapping(bytes32 => IBaseEscrow.Immutables) public escrowImmutables;
    
    /// @notice Resolver count for metrics
    uint256 public resolverCount;
    
    /// @notice Maker whitelist enabled flag
    bool public makerWhitelistEnabled;
    
    /// @notice Whitelist bypass flag for testing
    bool public whitelistBypassed;
    
    /// @notice Events (1inch compatible format)
    event SrcEscrowCreated(
        IBaseEscrow.Immutables srcImmutables,
        IEscrowFactory.DstImmutablesComplement dstImmutablesComplement
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
    event PostInteractionEscrowCreated(
        address indexed escrow,
        bytes32 indexed hashlock,
        address indexed protocol,
        address taker,
        uint256 amount
    );
    
    /// @notice Modifiers
    modifier whenNotPaused() {
        require(!emergencyPaused, "Protocol paused");
        _;
    }
    
    modifier onlyWhitelistedResolver() {
        require(whitelistBypassed || whitelistedResolvers[msg.sender], "Not whitelisted resolver");
        _;
    }
    
    /**
     * @notice Constructor deploys implementations directly for correct FACTORY immutable
     * @param limitOrderProtocol Address of the 1inch SimpleLimitOrderProtocol
     * @param _owner Contract owner who can manage whitelists and pause
     * @param rescueDelay Delay in seconds for rescue operations
     * @param accessToken Token for access control in escrows (use address(0) if not needed)
     * @param weth Address of WETH contract (can be address(0) if not needed)
     */
    constructor(
        address limitOrderProtocol,
        address _owner,
        uint32 rescueDelay,
        IERC20 accessToken,
        address weth
    ) SimpleSettlement(limitOrderProtocol, accessToken, weth, _owner) {
        require(_owner != address(0), "Invalid owner");
        
        // Deploy implementations directly in constructor
        // This ensures the FACTORY immutable in escrows captures our factory address
        EscrowSrc srcImpl = new EscrowSrc(rescueDelay, accessToken);
        EscrowDst dstImpl = new EscrowDst(rescueDelay, accessToken);
        
        ESCROW_SRC_IMPLEMENTATION = address(srcImpl);
        ESCROW_DST_IMPLEMENTATION = address(dstImpl);
        
        // Pre-compute proxy bytecode hashes for CREATE2 address prediction
        // These are used to calculate deterministic addresses across chains
        ESCROW_SRC_PROXY_BYTECODE_HASH = address(srcImpl).computeProxyBytecodeHash();
        ESCROW_DST_PROXY_BYTECODE_HASH = address(dstImpl).computeProxyBytecodeHash();
        
        // Default to bypassing whitelist for easier testing
        whitelistBypassed = true;
        
        // Whitelist owner as initial resolver for testing
        whitelistedResolvers[_owner] = true;
        resolverCount = 1;
        emit ResolverWhitelisted(_owner);
    }
    
    /**
     * @notice Create source escrow (standalone version for testing)
     * @param immutables Escrow parameters
     * @param dstComplement Destination chain parameters
     */
    function createSrcEscrow(
        IBaseEscrow.Immutables calldata immutables,
        IEscrowFactory.DstImmutablesComplement calldata dstComplement
    ) external whenNotPaused returns (address escrow) {
        // Validate maker if whitelist is enabled
        if (makerWhitelistEnabled) {
            require(whitelistedMakers[immutables.maker.get()], "Maker not whitelisted");
        }
        
        // Deploy escrow using CREATE2 with deterministic address
        bytes32 salt = immutables.hash();
        escrow = ESCROW_SRC_IMPLEMENTATION.cloneDeterministic(salt);
        
        // Track escrow
        escrows[salt] = escrow;
        
        // Store immutables for later retrieval
        escrowImmutables[salt] = immutables;
        
        // Transfer tokens to escrow
        IERC20(immutables.token.get()).safeTransferFrom(msg.sender, escrow, immutables.amount);
        
        // Emit complete immutables for 1inch compatibility
        emit SrcEscrowCreated(immutables, dstComplement);
    }
    
    /**
     * @notice Create destination escrow (resolver only)
     * @param immutables Escrow parameters
     */
    function createDstEscrow(
        IBaseEscrow.Immutables calldata immutables
    ) external payable whenNotPaused onlyWhitelistedResolver returns (address escrow) {
        // Deploy escrow using CREATE2 with deterministic address
        bytes32 salt = immutables.hash();
        escrow = ESCROW_DST_IMPLEMENTATION.cloneDeterministic(salt, msg.value);
        
        // Track escrow
        escrows[salt] = escrow;
        
        // Store immutables for later retrieval
        escrowImmutables[salt] = immutables;
        
        // Handle token transfer if not native
        address token = immutables.token.get();
        if (token != address(0)) {
            IERC20(token).safeTransferFrom(msg.sender, escrow, immutables.amount);
        }
        
        emit DstEscrowCreated(escrow, immutables.hashlock, immutables.taker.get());
    }
    
    /**
     * @notice Get escrow address for given parameters
     * @param immutables Escrow parameters
     * @param isSrc Whether this is a source or destination escrow
     * @return Predicted address of the escrow
     */
    function addressOfEscrow(
        IBaseEscrow.Immutables calldata immutables,
        bool isSrc
    ) external view returns (address) {
        address implementation = isSrc ? ESCROW_SRC_IMPLEMENTATION : ESCROW_DST_IMPLEMENTATION;
        return Clones.predictDeterministicAddress(implementation, immutables.hash(), address(this));
    }
    
    /**
     * @notice Called internally by SimpleSettlement after order fill
     * @dev Decodes extension data and creates source escrow
     * @param order The order that was filled
     * @param extension Extension bytes from the order
     * @param orderHash The hash of the filled order
     * @param taker Address that filled the order (resolver)
     * @param makingAmount Amount of maker asset transferred
     * @param takingAmount Amount of taker asset transferred
     * @param remainingMakingAmount Remaining amount in the order
     * @param extraData Encoded parameters for escrow creation
     */
    function _postInteraction(
        IOrderMixin.Order calldata order,
        bytes calldata extension,
        bytes32 orderHash,
        address taker,
        uint256 makingAmount,
        uint256 takingAmount,
        uint256 remainingMakingAmount,
        bytes calldata extraData
    ) internal override whenNotPaused {
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
        
        // Validate timestamps are in the future to prevent underflow
        require(srcCancellationTimestamp > block.timestamp, "srcCancellation must be future");
        require(dstWithdrawalTimestamp > block.timestamp, "dstWithdrawal must be future");
        
        // Build timelocks for source escrow using the pack() function
        // Timelocks stores offsets from deployment time, not absolute timestamps
        TimelocksLib.TimelocksStruct memory timelocksStruct = TimelocksLib.TimelocksStruct({
            srcWithdrawal: 0,  // 0 seconds offset for testing (immediate withdrawal allowed)
            srcPublicWithdrawal: 60,  // 60 seconds offset for testing
            srcCancellation: uint32(srcCancellationTimestamp - block.timestamp),
            srcPublicCancellation: uint32(srcCancellationTimestamp - block.timestamp + 60),
            dstWithdrawal: uint32(dstWithdrawalTimestamp - block.timestamp),
            dstPublicWithdrawal: uint32(dstWithdrawalTimestamp - block.timestamp + 60),
            dstCancellation: uint32(srcCancellationTimestamp - block.timestamp)  // Aligned with srcCancellation
        });
        
        // Pack the timelocks and set the deployment timestamp
        Timelocks srcTimelocks = TimelocksLib.pack(timelocksStruct);
        srcTimelocks = srcTimelocks.setDeployedAt(block.timestamp);
        
        // Build immutables for source escrow
        IBaseEscrow.Immutables memory srcImmutables = IBaseEscrow.Immutables({
            orderHash: orderHash,
            hashlock: hashlock,
            maker: Address.wrap(uint160(order.maker.get())),
            taker: Address.wrap(uint160(taker)),
            token: order.makerAsset,
            amount: makingAmount,
            safetyDeposit: srcSafetyDeposit,
            timelocks: srcTimelocks,
            parameters: ""  // Empty for BMN (no fees), 1inch compatibility
        });
        
        // Build destination immutables complement for complete event data
        // Encode fee structure with zero values for 1inch compatibility
        bytes memory dstParameters = abi.encode(
            uint256(0),  // protocolFeeAmount - we use 0
            uint256(0),  // integratorFeeAmount - we use 0
            Address.wrap(0),  // protocolFeeRecipient - not used
            Address.wrap(0)   // integratorFeeRecipient - not used
        );
        
        IEscrowFactory.DstImmutablesComplement memory dstComplement = IEscrowFactory.DstImmutablesComplement({
            maker: order.receiver.get() == address(0) ? Address.wrap(uint160(order.maker.get())) : order.receiver,
            amount: takingAmount,
            token: Address.wrap(uint160(dstToken)),
            safetyDeposit: dstSafetyDeposit,
            chainId: dstChainId,
            parameters: dstParameters  // Encoded fee structure for 1inch compatibility
        });
        
        // Create the source escrow
        address escrowAddress = _createSrcEscrowInternal(srcImmutables, dstComplement);
        
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
        IBaseEscrow.Immutables memory srcImmutables,
        IEscrowFactory.DstImmutablesComplement memory dstComplement
    ) internal returns (address escrow) {
        // Deploy escrow using CREATE2
        // Calculate hash manually for memory parameter
        bytes32 salt = keccak256(abi.encode(srcImmutables));
        escrow = ESCROW_SRC_IMPLEMENTATION.cloneDeterministic(salt);
        
        // Track escrow by hashlock for duplicate detection
        escrows[srcImmutables.hashlock] = escrow;
        
        // Store immutables for later retrieval (enables resolver to withdraw)
        escrowImmutables[salt] = srcImmutables;
        
        // Emit complete immutables for 1inch compatibility
        emit SrcEscrowCreated(srcImmutables, dstComplement);
        
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
}