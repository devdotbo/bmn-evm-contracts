// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Address, AddressLib } from "solidity-utils/contracts/libraries/AddressLib.sol";
import { IBaseEscrow } from "./interfaces/IBaseEscrow.sol";
import { TimelocksLib, Timelocks } from "./libraries/TimelocksLib.sol";

// Interface for TestEscrowFactory
interface ITestEscrowFactory {
    struct DstImmutablesComplement {
        Address maker;
        uint256 amount;
        Address token;
        uint256 safetyDeposit;
        uint256 chainId;
    }

    event SrcEscrowCreated(IBaseEscrow.Immutables srcImmutables, DstImmutablesComplement dstImmutablesComplement);
    event DstEscrowCreated(address escrow, bytes32 hashlock, Address taker);

    function createSrcEscrowForTesting(
        IBaseEscrow.Immutables calldata immutables,
        uint256 prefundAmount
    ) external returns (address escrow);

    function createDstEscrow(
        IBaseEscrow.Immutables calldata dstImmutables,
        uint256 srcCancellationTimestamp
    ) external payable;

    function addressOfEscrowSrc(IBaseEscrow.Immutables calldata immutables) external view returns (address);
    function addressOfEscrowDst(IBaseEscrow.Immutables calldata immutables) external view returns (address);
}

/**
 * @title CrossChainResolverV2
 * @notice Hackathon version that works with TestEscrowFactory for direct escrow creation
 * @dev Uses TestEscrowFactory for source escrow creation, suitable for hackathon demo
 */
contract CrossChainResolverV2 {
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

    ITestEscrowFactory public immutable factory;
    address public immutable owner;
    
    // SwapId => SwapData
    mapping(bytes32 => SwapData) public swaps;
    
    // Escrow => SwapId (for reverse lookup)
    mapping(address => bytes32) public escrowToSwapId;

    modifier onlyOwner() {
        if (msg.sender != owner) revert OnlyOwner();
        _;
    }

    constructor(ITestEscrowFactory _factory) {
        factory = _factory;
        owner = msg.sender;
    }

    /**
     * @notice Initiates a cross-chain swap using TestEscrowFactory
     * @dev Creates source escrow on current chain
     */
    function initiateSwap(
        bytes32 hashlock,
        address taker,
        address token,
        uint256 amount,
        uint256 dstChainId,
        Timelocks timelocks
    ) external payable returns (bytes32 swapId, address srcEscrow) {
        // Generate unique swap ID
        swapId = keccak256(abi.encode(
            msg.sender,
            taker,
            hashlock,
            block.timestamp,
            block.chainid
        ));
        
        if (swaps[swapId].maker != address(0)) revert InvalidSwapId();

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

        // Transfer tokens from user to this contract
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        
        // Approve factory to spend tokens
        IERC20(token).forceApprove(address(factory), amount);

        // Create source escrow using TestEscrowFactory
        srcEscrow = factory.createSrcEscrowForTesting(srcImmutables, amount);

        // Store swap data
        swaps[swapId] = SwapData({
            srcEscrow: srcEscrow,
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

        escrowToSwapId[srcEscrow] = swapId;

        emit SwapInitiated(
            swapId,
            msg.sender,
            taker,
            block.chainid,
            dstChainId,
            amount
        );
        
        emit EscrowCreated(swapId, srcEscrow, true);
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
    ) external payable onlyOwner returns (address dstEscrow) {
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

        // Get the deployed escrow address
        dstEscrow = factory.addressOfEscrowDst(dstImmutables);
        
        swap.dstEscrow = dstEscrow;
        escrowToSwapId[dstEscrow] = swapId;
        
        emit EscrowCreated(swapId, dstEscrow, false);
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
            token: Address.wrap(uint160(address(0))), // Will be read from escrow
            amount: swap.amount,
            safetyDeposit: 0, // Will be read from escrow
            timelocks: Timelocks.wrap(0) // Will be read from escrow
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
     * @notice Gets swap details
     */
    function getSwap(bytes32 swapId) external view returns (SwapData memory) {
        return swaps[swapId];
    }

    /**
     * @notice Emergency function to approve tokens
     */
    function approve(IERC20 token, address spender) external onlyOwner {
        token.forceApprove(spender, type(uint256).max);
    }

    /**
     * @notice Emergency function to recover tokens
     */
    function recoverToken(IERC20 token, uint256 amount) external onlyOwner {
        token.safeTransfer(owner, amount);
    }
}