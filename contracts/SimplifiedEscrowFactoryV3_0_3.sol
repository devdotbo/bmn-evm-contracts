// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { SimplifiedEscrowFactory } from "./SimplifiedEscrowFactory.sol";
import { EscrowSrc } from "./EscrowSrc.sol";
import { EscrowDst } from "./EscrowDst.sol";
import { IBaseEscrow } from "./interfaces/IBaseEscrow.sol";
import { Timelocks } from "./libraries/TimelocksLib.sol";
import { Address } from "solidity-utils/contracts/libraries/AddressLib.sol";
import { IOrderMixin } from "../dependencies/limit-order-protocol/contracts/interfaces/IOrderMixin.sol";
import { SafeERC20 } from "solidity-utils/contracts/libraries/SafeERC20.sol";

/**
 * @title SimplifiedEscrowFactoryV3_0_3
 * @notice v3.0.3 Factory that fixes resolver compatibility by making timelocks predictable
 * @dev Key improvements:
 *      1. Uses predictable deployedAt timestamp from order data instead of block.timestamp
 *      2. Emits comprehensive events with exact immutables for resolver verification
 *      3. Provides computeImmutables helper for off-chain calculation
 *      4. Maintains backward compatibility while fixing InvalidImmutables issue
 */
contract SimplifiedEscrowFactoryV3_0_3 is SimplifiedEscrowFactory {
    using SafeERC20 for IERC20;
    
    /// @notice Enhanced event that includes the exact immutables array
    event SrcEscrowCreatedWithImmutables(
        address indexed escrow,
        bytes32 indexed hashlock,
        bytes32 indexed orderHash,
        uint256[8] immutables  // Exact values for resolver reconstruction
    );
    
    /// @notice Timestamp tolerance for validation (5 minutes)
    uint256 private constant TIMESTAMP_TOLERANCE = 300;
    
    /**
     * @param accessToken BMN / access token used by escrows
     * @param _owner Factory owner
     * @param rescueDelay Rescue delay for escrows
     */
    constructor(IERC20 accessToken, address _owner, uint32 rescueDelay)
        SimplifiedEscrowFactory(
            address(new EscrowSrc(rescueDelay, accessToken)),
            address(new EscrowDst(rescueDelay, accessToken)),
            _owner
        )
    {}
    
    /**
     * @notice Override postInteraction to use predictable timelocks
     * @dev Key change: Uses a predictable deployedAt timestamp instead of block.timestamp
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
        
        // Enhanced decode: includes deployedAt timestamp for predictability
        // Format: abi.encode(hashlock, dstChainId, dstToken, deposits, timelocks, deployedAt)
        (
            bytes32 hashlock,
            uint256 dstChainId,
            address dstToken,
            uint256 deposits,
            uint256 timelocks,
            uint256 deployedAt  // New: predictable timestamp from order
        ) = abi.decode(extraData, (bytes32, uint256, address, uint256, uint256, uint256));
        
        // If deployedAt not provided (0), fall back to block.timestamp for backward compatibility
        if (deployedAt == 0) {
            deployedAt = block.timestamp;
        } else {
            // Validate deployedAt is within acceptable range
            require(
                deployedAt >= block.timestamp - TIMESTAMP_TOLERANCE &&
                deployedAt <= block.timestamp + TIMESTAMP_TOLERANCE,
                "Invalid deployedAt timestamp"
            );
        }
        
        // Prevent duplicate escrows
        require(escrows[hashlock] == address(0), "Escrow already exists");
        
        // Extract safety deposits
        uint256 srcSafetyDeposit = deposits & type(uint128).max;
        uint256 dstSafetyDeposit = deposits >> 128;
        
        // Extract timelocks
        uint256 dstWithdrawalTimestamp = timelocks & type(uint128).max;
        uint256 srcCancellationTimestamp = timelocks >> 128;
        
        // Validate timestamps are in the future (relative to deployedAt)
        require(srcCancellationTimestamp > deployedAt, "srcCancellation must be future");
        require(dstWithdrawalTimestamp > deployedAt, "dstWithdrawal must be future");
        
        // Build predictable timelocks using provided deployedAt
        uint256 packedTimelocks = uint256(uint32(deployedAt)) << 224; // Use predictable timestamp
        packedTimelocks |= uint256(uint32(0)) << 0; // srcWithdrawal: 0 seconds offset
        packedTimelocks |= uint256(uint32(60)) << 32; // srcPublicWithdrawal: 60 seconds offset
        packedTimelocks |= uint256(uint32(srcCancellationTimestamp - deployedAt)) << 64; // srcCancellation offset
        packedTimelocks |= uint256(uint32(srcCancellationTimestamp - deployedAt + 60)) << 96; // srcPublicCancellation offset
        packedTimelocks |= uint256(uint32(dstWithdrawalTimestamp - deployedAt)) << 128; // dstWithdrawal offset
        packedTimelocks |= uint256(uint32(dstWithdrawalTimestamp - deployedAt + 60)) << 160; // dstPublicWithdrawal offset
        
        // Align dstCancellation with srcCancellation for validation
        uint32 dstCancellationOffset = uint32(srcCancellationTimestamp - deployedAt);
        packedTimelocks |= uint256(dstCancellationOffset) << 192;
        
        Timelocks srcTimelocks = Timelocks.wrap(packedTimelocks);
        
        // Build immutables
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
        
        // Transfer tokens from taker to escrow
        IERC20(order.makerAsset.get()).safeTransferFrom(taker, escrowAddress, makingAmount);
        
        // Emit enhanced event with exact immutables for resolver verification
        emit SrcEscrowCreatedWithImmutables(
            escrowAddress,
            hashlock,
            orderHash,
            _immutablesToArray(srcImmutables)
        );
        
        // Also emit standard event for backward compatibility
        emit PostInteractionEscrowCreated(
            escrowAddress,
            hashlock,
            msg.sender,
            taker,
            makingAmount
        );
    }
    
    /**
     * @notice Helper function to compute immutables off-chain
     * @dev Resolvers can call this to verify their calculations match
     * @param orderHash The order hash
     * @param hashlock The hashlock
     * @param maker The maker address
     * @param taker The taker (resolver) address
     * @param token The token address
     * @param amount The token amount
     * @param safetyDeposit The safety deposit
     * @param deployedAt The deployment timestamp to use
     * @param srcCancellationTimestamp The source cancellation timestamp
     * @param dstWithdrawalTimestamp The destination withdrawal timestamp
     * @return The computed immutables that would be stored
     */
    function computeImmutables(
        bytes32 orderHash,
        bytes32 hashlock,
        address maker,
        address taker,
        address token,
        uint256 amount,
        uint256 safetyDeposit,
        uint256 deployedAt,
        uint256 srcCancellationTimestamp,
        uint256 dstWithdrawalTimestamp
    ) external pure returns (IBaseEscrow.Immutables memory) {
        // Build timelocks exactly as postInteraction does
        uint256 packedTimelocks = uint256(uint32(deployedAt)) << 224;
        packedTimelocks |= uint256(uint32(0)) << 0;
        packedTimelocks |= uint256(uint32(60)) << 32;
        packedTimelocks |= uint256(uint32(srcCancellationTimestamp - deployedAt)) << 64;
        packedTimelocks |= uint256(uint32(srcCancellationTimestamp - deployedAt + 60)) << 96;
        packedTimelocks |= uint256(uint32(dstWithdrawalTimestamp - deployedAt)) << 128;
        packedTimelocks |= uint256(uint32(dstWithdrawalTimestamp - deployedAt + 60)) << 160;
        packedTimelocks |= uint256(uint32(srcCancellationTimestamp - deployedAt)) << 192;
        
        return IBaseEscrow.Immutables({
            orderHash: orderHash,
            hashlock: hashlock,
            maker: Address.wrap(uint160(maker)),
            taker: Address.wrap(uint160(taker)),
            token: Address.wrap(uint160(token)),
            amount: amount,
            safetyDeposit: safetyDeposit,
            timelocks: Timelocks.wrap(packedTimelocks)
        });
    }
    
    /**
     * @dev Converts immutables struct to array for event emission
     */
    function _immutablesToArray(IBaseEscrow.Immutables memory imm) 
        private 
        pure 
        returns (uint256[8] memory arr) 
    {
        arr[0] = uint256(imm.orderHash);
        arr[1] = uint256(imm.hashlock);
        arr[2] = uint256(uint160(Address.unwrap(imm.maker)));
        arr[3] = uint256(uint160(Address.unwrap(imm.taker)));
        arr[4] = uint256(uint160(Address.unwrap(imm.token)));
        arr[5] = imm.amount;
        arr[6] = imm.safetyDeposit;
        arr[7] = uint256(Timelocks.unwrap(imm.timelocks));
    }
}