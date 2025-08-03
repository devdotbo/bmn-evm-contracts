// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "solidity-utils/contracts/libraries/SafeERC20.sol";
import { Address, AddressLib } from "solidity-utils/contracts/libraries/AddressLib.sol";
import { IEscrowFactory } from "./interfaces/IEscrowFactory.sol";
import { IBaseEscrow } from "./interfaces/IBaseEscrow.sol";
import { TimelocksLib, Timelocks } from "./libraries/TimelocksLib.sol";

/**
 * @title CrossChainResolver
 * @notice 1inch-style resolver for cross-chain atomic swaps
 * @dev Pre-deployed on both chains, manages escrows without address prediction
 */
contract CrossChainResolver {
    using SafeERC20 for IERC20;
    using AddressLib for Address;
    using TimelocksLib for Timelocks;

    error OnlyOwner();
    error InvalidSwapId();
    error SwapNotFound();
    error AlreadyWithdrawn();
    error InvalidSecret();

    struct SwapData {
        address srcEscrow;
        address dstEscrow;
        bytes32 hashlock;
        uint256 srcChainId;
        uint256 dstChainId;
        uint256 amount;
        address maker;
        address taker;
        bool srcWithdrawn;
        bool dstWithdrawn;
    }

    event SwapInitiated(
        bytes32 indexed swapId,
        address indexed maker,
        address indexed taker,
        uint256 srcChainId,
        uint256 dstChainId,
        uint256 amount
    );

    event EscrowCreated(
        bytes32 indexed swapId,
        address escrow,
        bool isSource
    );

    event SwapCompleted(
        bytes32 indexed swapId,
        bytes32 secret
    );

    IEscrowFactory public immutable factory;
    address public immutable owner;
    
    // SwapId => SwapData
    mapping(bytes32 => SwapData) public swaps;
    
    // Escrow => SwapId (for reverse lookup)
    mapping(address => bytes32) public escrowToSwapId;

    modifier onlyOwner() {
        if (msg.sender != owner) revert OnlyOwner();
        _;
    }

    constructor(IEscrowFactory _factory) {
        factory = _factory;
        owner = msg.sender;
    }

    /**
     * @notice Initiates a cross-chain swap
     * @dev Creates source escrow on current chain
     */
    function initiateSwap(
        bytes32 hashlock,
        address taker,
        address token,
        uint256 amount,
        uint256 dstChainId,
        Timelocks timelocks
    ) external returns (bytes32 swapId) {
        // Generate unique swap ID
        swapId = keccak256(abi.encode(
            msg.sender,
            taker,
            hashlock,
            block.timestamp,
            block.chainid
        ));
        
        if (swaps[swapId].maker != address(0)) revert InvalidSwapId();

        // Store swap data
        swaps[swapId] = SwapData({
            srcEscrow: address(0), // Will be set after deployment
            dstEscrow: address(0), // Will be set by destination chain
            hashlock: hashlock,
            srcChainId: block.chainid,
            dstChainId: dstChainId,
            amount: amount,
            maker: msg.sender,
            taker: taker,
            srcWithdrawn: false,
            dstWithdrawn: false
        });

        // Approve and create source escrow
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        IERC20(token).forceApprove(address(factory), amount);

        // Create immutables for source escrow
        IBaseEscrow.Immutables memory srcImmutables = IBaseEscrow.Immutables({
            orderHash: swapId, // Use swapId as orderHash for tracking
            hashlock: hashlock,
            maker: Address.wrap(uint160(msg.sender)),
            taker: Address.wrap(uint160(taker)),
            token: Address.wrap(uint160(token)),
            amount: amount,
            safetyDeposit: msg.value,
            timelocks: timelocks
        });

        // Deploy source escrow (factory will emit event with actual address)
        // We'll capture the address from the event
        factory.createSrcEscrow{value: msg.value}(srcImmutables, amount);

        emit SwapInitiated(
            swapId,
            msg.sender,
            taker,
            block.chainid,
            dstChainId,
            amount
        );
    }

    /**
     * @notice Creates destination escrow (called by resolver on destination chain)
     */
    function createDestinationEscrow(
        bytes32 swapId,
        address maker,
        address taker,
        address token,
        uint256 amount,
        bytes32 hashlock,
        Timelocks timelocks,
        uint256 srcTimestamp
    ) external payable onlyOwner {
        SwapData storage swap = swaps[swapId];
        
        // Initialize if new
        if (swap.maker == address(0)) {
            swap.hashlock = hashlock;
            swap.amount = amount;
            swap.maker = maker;
            swap.taker = taker;
        }

        // Create immutables for destination escrow
        IBaseEscrow.Immutables memory dstImmutables = IBaseEscrow.Immutables({
            orderHash: swapId,
            hashlock: hashlock,
            maker: Address.wrap(uint160(taker)), // Swapped on destination
            taker: Address.wrap(uint160(maker)), // Swapped on destination
            token: Address.wrap(uint160(token)),
            amount: amount,
            safetyDeposit: msg.value,
            timelocks: timelocks
        });

        // Calculate cancellation timestamp
        uint256 srcCancellationTimestamp = srcTimestamp + 
            uint256(uint32(Timelocks.unwrap(timelocks) >> 64));

        // Transfer tokens and approve
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        IERC20(token).forceApprove(address(factory), amount);

        // Deploy destination escrow
        factory.createDstEscrow{value: msg.value}(
            dstImmutables,
            srcCancellationTimestamp
        );
    }

    /**
     * @notice Registers escrow addresses (called after deployment)
     */
    function registerEscrow(
        bytes32 swapId,
        address escrow,
        bool isSource
    ) external onlyOwner {
        SwapData storage swap = swaps[swapId];
        if (swap.maker == address(0)) revert SwapNotFound();

        if (isSource) {
            swap.srcEscrow = escrow;
        } else {
            swap.dstEscrow = escrow;
        }

        escrowToSwapId[escrow] = swapId;
        emit EscrowCreated(swapId, escrow, isSource);
    }

    /**
     * @notice Withdraws from escrows using the secret
     */
    function withdraw(
        bytes32 swapId,
        bytes32 secret,
        bool isSource
    ) external {
        SwapData storage swap = swaps[swapId];
        if (swap.maker == address(0)) revert SwapNotFound();
        
        // Verify secret
        if (keccak256(abi.encodePacked(secret)) != swap.hashlock) {
            revert InvalidSecret();
        }

        address escrow = isSource ? swap.srcEscrow : swap.dstEscrow;
        if (escrow == address(0)) revert SwapNotFound();

        if (isSource && swap.srcWithdrawn) revert AlreadyWithdrawn();
        if (!isSource && swap.dstWithdrawn) revert AlreadyWithdrawn();

        // Build immutables for withdrawal
        IBaseEscrow.Immutables memory immutables = IBaseEscrow.Immutables({
            orderHash: swapId,
            hashlock: swap.hashlock,
            maker: isSource 
                ? Address.wrap(uint160(swap.maker))
                : Address.wrap(uint160(swap.taker)),
            taker: isSource
                ? Address.wrap(uint160(swap.taker))
                : Address.wrap(uint160(swap.maker)),
            token: Address.wrap(uint160(address(0))), // Will be set by caller
            amount: swap.amount,
            safetyDeposit: 0, // Will be set by caller
            timelocks: Timelocks.wrap(0) // Will be set by caller
        });

        // Perform withdrawal
        IBaseEscrow(escrow).withdraw(secret, immutables);

        if (isSource) {
            swap.srcWithdrawn = true;
        } else {
            swap.dstWithdrawn = true;
        }

        emit SwapCompleted(swapId, secret);
    }

    /**
     * @notice Emergency function to approve tokens
     */
    function approve(IERC20 token, address spender) external onlyOwner {
        token.forceApprove(spender, type(uint256).max);
    }
}