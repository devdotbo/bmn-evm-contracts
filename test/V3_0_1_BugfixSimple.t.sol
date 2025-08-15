// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Test.sol";
import "../contracts/SimplifiedEscrowFactory.sol";
import "../contracts/EscrowSrc.sol";
import "../contracts/EscrowDst.sol";
import "../contracts/libraries/TimelocksLib.sol";
import "../contracts/libraries/ImmutablesLib.sol";
import "../contracts/interfaces/IEscrowFactory.sol";
import "../contracts/mocks/TokenMock.sol";
import {IOrderMixin} from "../dependencies/limit-order-protocol/contracts/interfaces/IOrderMixin.sol";
import {Address, AddressLib} from "@1inch/solidity-utils/contracts/libraries/AddressLib.sol";
import {MakerTraits} from "../dependencies/limit-order-protocol/contracts/libraries/MakerTraitsLib.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract V3_0_1_BugfixSimpleTest is Test {
    using AddressLib for Address;
    using TimelocksLib for Timelocks;
    using ImmutablesLib for IBaseEscrow.Immutables;

    SimplifiedEscrowFactory public factory;
    TokenMock public tokenA;
    TokenMock public tokenB;
    
    address public alice = address(0x1);
    address public bob = address(0x2);
    address public resolver = address(0x3);
    
    uint256 constant AMOUNT = 100 ether;
    uint256 constant SAFETY_DEPOSIT = 1 ether;
    
    event SrcEscrowCreated(
        address indexed escrow,
        bytes32 indexed orderHash,
        address indexed maker,
        address taker,
        uint256 amount
    );
    
    event DstEscrowCreated(
        address indexed escrow,
        bytes32 indexed orderHash,
        address indexed maker,
        address taker,
        uint256 amount
    );
    
    function setUp() public {
        // Deploy mock tokens
        tokenA = new TokenMock("Token A", "TKA", 18);
        tokenB = new TokenMock("Token B", "TKB", 18);
        
        // Deploy escrow implementations with standard params
        uint32 rescueDelay = 86400; // 1 day
        IERC20 accessToken = IERC20(address(0)); // No access token for testing
        EscrowSrc srcImpl = new EscrowSrc(rescueDelay, accessToken);
        EscrowDst dstImpl = new EscrowDst(rescueDelay, accessToken);
        
        // Deploy factory
        factory = new SimplifiedEscrowFactory(
            address(srcImpl),
            address(dstImpl),
            address(this)
        );
        
        // Setup accounts
        tokenA.mint(alice, 1000 ether);
        tokenA.mint(resolver, 1000 ether);
        tokenB.mint(bob, 1000 ether);
        tokenB.mint(resolver, 1000 ether);
        
        // Whitelist resolver
        factory.addResolver(resolver);
        
        // Give resolver approval to factory for transfers
        vm.prank(resolver);
        tokenA.approve(address(factory), type(uint256).max);
        vm.prank(resolver);
        tokenB.approve(address(factory), type(uint256).max);
    }
    
    function test_BugfixValidation_ShortCancellation() public {
        // Test that the fix allows creation with short cancellation times
        // Previously would fail with InvalidCreationTime
        
        bytes32 hashlock = keccak256("secret");
        bytes32 orderHash = keccak256("order");
        
        // Use a short cancellation time (2 minutes) which would fail with hardcoded 7200s
        uint32 srcCancellationTimestamp = uint32(block.timestamp + 120);
        uint32 dstWithdrawalTimestamp = uint32(block.timestamp + 60);
        
        // Build the order
        IOrderMixin.Order memory order = IOrderMixin.Order({
            salt: uint256(0),
            maker: Address.wrap(uint160(alice)),
            receiver: Address.wrap(uint160(resolver)),
            makerAsset: Address.wrap(uint160(address(tokenA))),
            takerAsset: Address.wrap(uint160(address(tokenB))),
            makingAmount: AMOUNT,
            takingAmount: AMOUNT,
            makerTraits: MakerTraits.wrap(0)
        });
        
        // Prepare extra data for postInteraction
        bytes memory extraData = abi.encode(
            hashlock,
            1, // dstChainId
            Address.wrap(uint160(address(tokenB))), // dstToken
            (SAFETY_DEPOSIT << 128) | SAFETY_DEPOSIT, // deposits packed
            srcCancellationTimestamp,
            dstWithdrawalTimestamp
        );
        
        // Transfer tokens to resolver to simulate limit order fill
        vm.prank(alice);
        tokenA.transfer(resolver, AMOUNT);
        
        // This should NOT revert with InvalidCreationTime after the fix
        vm.prank(address(0x1234)); // Mock limit order protocol
        vm.expectEmit(false, true, true, true);
        emit SrcEscrowCreated(address(0), orderHash, alice, resolver, AMOUNT);
        
        factory.postInteraction(
            order,
            "",
            orderHash,
            resolver,
            AMOUNT,
            AMOUNT,
            0,
            extraData
        );
        
        // If we get here, the fix worked!
    }
    
    function test_BugfixValidation_VariousCancellationTimes() public {
        // Test multiple cancellation times that would fail before the fix
        uint32[4] memory cancellationDelays = [
            uint32(120),  // 2 minutes - would fail
            uint32(300),  // 5 minutes - would fail  
            uint32(600),  // 10 minutes - would fail
            uint32(1800)  // 30 minutes - would fail
        ];
        
        for (uint i = 0; i < cancellationDelays.length; i++) {
            _testCancellationTime(cancellationDelays[i], i);
        }
    }
    
    function test_DstEscrowCreation_WithFix() public {
        // Test that destination escrow can be created with the fix
        bytes32 secret = bytes32("secret");
        bytes32 hashlock = keccak256(abi.encode(secret));
        bytes32 orderHash = keccak256("order");
        
        uint32 srcCancellationTimestamp = uint32(block.timestamp + 600); // 10 minutes
        uint32 dstWithdrawalTimestamp = uint32(block.timestamp + 300); // 5 minutes
        
        // Build immutables for destination escrow
        uint256 packedTimelocks = uint256(uint32(block.timestamp)) << 224;
        packedTimelocks |= uint256(uint32(0)) << 0; // srcWithdrawal: instant
        packedTimelocks |= uint256(uint32(60)) << 32; // srcPublicWithdrawal: 60s
        packedTimelocks |= uint256(uint32(srcCancellationTimestamp - block.timestamp)) << 64;
        packedTimelocks |= uint256(uint32(srcCancellationTimestamp - block.timestamp + 60)) << 96;
        packedTimelocks |= uint256(uint32(dstWithdrawalTimestamp - block.timestamp)) << 128;
        packedTimelocks |= uint256(uint32(dstWithdrawalTimestamp - block.timestamp + 60)) << 160;
        // With the fix: dstCancellation = srcCancellation offset
        packedTimelocks |= uint256(uint32(srcCancellationTimestamp - block.timestamp)) << 192;
        
        IBaseEscrow.Immutables memory dstImmutables = IBaseEscrow.Immutables({
            orderHash: orderHash,
            hashlock: hashlock,
            maker: Address.wrap(uint160(resolver)), // taker becomes maker for dst
            taker: Address.wrap(uint160(bob)), // maker becomes taker for dst
            token: Address.wrap(uint160(address(tokenB))),
            amount: AMOUNT,
            safetyDeposit: SAFETY_DEPOSIT,
            timelocks: Timelocks.wrap(packedTimelocks)
        });
        
        // This should NOT revert with InvalidCreationTime after the fix
        vm.prank(resolver);
        vm.expectEmit(false, true, true, true);
        emit DstEscrowCreated(address(0), orderHash, resolver, bob, AMOUNT);
        
        factory.createDstEscrow(dstImmutables);
        
        // If we get here, the fix worked!
    }
    
    function _testCancellationTime(uint32 delay, uint256 salt) internal {
        bytes32 hashlock = keccak256(abi.encode("secret", salt));
        bytes32 orderHash = keccak256(abi.encode("order", salt));
        
        uint32 srcCancellationTimestamp = uint32(block.timestamp + delay);
        uint32 dstWithdrawalTimestamp = uint32(block.timestamp + 60);
        
        IOrderMixin.Order memory order = IOrderMixin.Order({
            salt: salt,
            maker: Address.wrap(uint160(alice)),
            receiver: Address.wrap(uint160(resolver)),
            makerAsset: Address.wrap(uint160(address(tokenA))),
            takerAsset: Address.wrap(uint160(address(tokenB))),
            makingAmount: AMOUNT,
            takingAmount: AMOUNT,
            makerTraits: MakerTraits.wrap(0)
        });
        
        bytes memory extraData = abi.encode(
            hashlock,
            1,
            Address.wrap(uint160(address(tokenB))),
            (SAFETY_DEPOSIT << 128) | SAFETY_DEPOSIT,
            srcCancellationTimestamp,
            dstWithdrawalTimestamp
        );
        
        vm.prank(alice);
        tokenA.transfer(resolver, AMOUNT);
        
        vm.prank(address(0x1234));
        factory.postInteraction(
            order,
            "",
            orderHash,
            resolver,
            AMOUNT,
            AMOUNT,
            0,
            extraData
        );
        
        // Success means the validation passed with the fix
        assertTrue(true, string(abi.encodePacked("Cancellation delay ", vm.toString(delay), " should work")));
    }
}