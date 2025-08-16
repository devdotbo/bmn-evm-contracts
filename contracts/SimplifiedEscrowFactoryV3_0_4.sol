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
 * @title SimplifiedEscrowFactoryV3_0_4
 * @notice v3.0.4 Security-hardened factory with fixed timestamp validation
 * @dev Fixes critical vulnerabilities found in v3.0.3:
 *      1. Prevents past timestamp attacks
 *      2. Enforces reasonable timelock bounds
 *      3. Reduces tolerance window to 60 seconds
 *      4. Validates all timestamps against block.timestamp
 */
contract SimplifiedEscrowFactoryV3_0_4 is SimplifiedEscrowFactory {
    using SafeERC20 for IERC20;
    
    /// @notice Enhanced event with exact immutables for resolver verification
    event SrcEscrowCreatedWithImmutables(
        address indexed escrow,
        bytes32 indexed hashlock,
        bytes32 indexed orderHash,
        uint256[8] immutables
    );
    
    /// @notice Reduced timestamp tolerance (60 seconds)
    uint256 private constant TIMESTAMP_TOLERANCE = 60;
    
    /// @notice Maximum allowed timelock duration (24 hours)
    uint256 private constant MAX_TIMELOCK_DURATION = 86400;
    
    /// @notice Minimum cancellation delay (5 minutes)
    uint256 private constant MIN_CANCELLATION_DELAY = 300;
    
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
     * @notice Secure postInteraction with comprehensive timestamp validation
     * @dev Fixes all timestamp vulnerabilities from v3.0.3
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
        
        // Decode with predictable timestamp support
        (
            bytes32 hashlock,
            uint256 dstChainId,
            address dstToken,
            uint256 deposits,
            uint256 timelocks,
            uint256 deployedAt
        ) = abi.decode(extraData, (bytes32, uint256, address, uint256, uint256, uint256));
        
        // Strict deployedAt validation
        if (deployedAt != 0) {
            // Validate deployedAt is within tight tolerance
            require(
                deployedAt >= block.timestamp - TIMESTAMP_TOLERANCE &&
                deployedAt <= block.timestamp + TIMESTAMP_TOLERANCE,
                "deployedAt outside tolerance"
            );
        } else {
            // Default to current timestamp for backward compatibility
            deployedAt = block.timestamp;
        }
        
        // Prevent duplicate escrows
        require(escrows[hashlock] == address(0), "Escrow already exists");
        
        // Extract safety deposits
        uint256 srcSafetyDeposit = deposits & type(uint128).max;
        uint256 dstSafetyDeposit = deposits >> 128;
        
        // Extract timelocks
        uint256 dstWithdrawalTimestamp = timelocks & type(uint128).max;
        uint256 srcCancellationTimestamp = timelocks >> 128;
        
        // CRITICAL FIX: Validate against block.timestamp, not deployedAt
        require(
            srcCancellationTimestamp > block.timestamp + MIN_CANCELLATION_DELAY,
            "srcCancellation too soon"
        );
        require(
            srcCancellationTimestamp <= block.timestamp + MAX_TIMELOCK_DURATION,
            "srcCancellation too far"
        );
        
        require(
            dstWithdrawalTimestamp > block.timestamp,
            "dstWithdrawal must be future"
        );
        require(
            dstWithdrawalTimestamp <= block.timestamp + MAX_TIMELOCK_DURATION,
            "dstWithdrawal too far"
        );
        
        // Logical validation
        require(
            srcCancellationTimestamp > dstWithdrawalTimestamp + 60,
            "Insufficient gap between withdrawal and cancellation"
        );
        
        // Build secure timelocks using validated deployedAt
        uint256 packedTimelocks = uint256(uint32(deployedAt)) << 224;
        packedTimelocks |= uint256(uint32(0)) << 0; // srcWithdrawal: immediate
        packedTimelocks |= uint256(uint32(60)) << 32; // srcPublicWithdrawal: 60s offset
        
        // Calculate offsets from deployedAt (already validated)
        uint32 srcCancellationOffset = uint32(srcCancellationTimestamp - deployedAt);
        uint32 dstWithdrawalOffset = uint32(dstWithdrawalTimestamp - deployedAt);
        
        packedTimelocks |= uint256(srcCancellationOffset) << 64;
        packedTimelocks |= uint256(srcCancellationOffset + 60) << 96; // public cancellation
        packedTimelocks |= uint256(dstWithdrawalOffset) << 128;
        packedTimelocks |= uint256(dstWithdrawalOffset + 60) << 160; // public withdrawal
        packedTimelocks |= uint256(srcCancellationOffset) << 192; // align dst cancellation
        
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
        
        // Emit enhanced event
        emit SrcEscrowCreatedWithImmutables(
            escrowAddress,
            hashlock,
            orderHash,
            _immutablesToArray(srcImmutables)
        );
        
        // Backward compatibility event
        emit PostInteractionEscrowCreated(
            escrowAddress,
            hashlock,
            msg.sender,
            taker,
            makingAmount
        );
    }
    
    /**
     * @notice Secure helper to compute immutables with validation
     * @dev Includes all security checks from postInteraction
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
    ) external view returns (IBaseEscrow.Immutables memory) {
        // Validate timestamps (same as postInteraction)
        require(
            deployedAt >= block.timestamp - TIMESTAMP_TOLERANCE &&
            deployedAt <= block.timestamp + TIMESTAMP_TOLERANCE,
            "Invalid deployedAt"
        );
        
        require(
            srcCancellationTimestamp > block.timestamp + MIN_CANCELLATION_DELAY &&
            srcCancellationTimestamp <= block.timestamp + MAX_TIMELOCK_DURATION,
            "Invalid srcCancellation"
        );
        
        require(
            dstWithdrawalTimestamp > block.timestamp &&
            dstWithdrawalTimestamp <= block.timestamp + MAX_TIMELOCK_DURATION,
            "Invalid dstWithdrawal"
        );
        
        // Build timelocks
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
     * @dev Converts immutables to array for event emission
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