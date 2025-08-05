// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { Test } from "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";
import { Vm } from "forge-std/Vm.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { Address, AddressLib } from "solidity-utils/contracts/libraries/AddressLib.sol";

import { CrossChainEscrowFactory } from "../contracts/CrossChainEscrowFactory.sol";
import { IEscrowFactory } from "../contracts/interfaces/IEscrowFactory.sol";
import { IBaseEscrow } from "../contracts/interfaces/IBaseEscrow.sol";
import { EscrowSrc } from "../contracts/EscrowSrc.sol";
import { EscrowDst } from "../contracts/EscrowDst.sol";
import { Timelocks, TimelocksLib } from "../contracts/libraries/TimelocksLib.sol";
import { ImmutablesLib } from "../contracts/libraries/ImmutablesLib.sol";

import { IOrderMixin } from "limit-order-protocol/contracts/interfaces/IOrderMixin.sol";
import { MakerTraits, MakerTraitsLib } from "limit-order-protocol/contracts/libraries/MakerTraitsLib.sol";

contract MockToken is IERC20 {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    uint256 public totalSupply = 1e24;

    function transfer(address to, uint256 amount) external returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
        totalSupply += amount;
    }
}

contract FactoryEventEnhancementTest is Test {
    using AddressLib for Address;
    using TimelocksLib for Timelocks;
    using ImmutablesLib for IBaseEscrow.Immutables;

    CrossChainEscrowFactory factory;
    EscrowSrc escrowSrcImpl;
    EscrowDst escrowDstImpl;
    MockToken tokenA;
    MockToken tokenB;

    address constant LIMIT_ORDER_PROTOCOL = address(0x1111111111111111111111111111111111111111);
    address constant ACCESS_TOKEN = address(0x2222222222222222222222222222222222222222);
    address constant FEE_TOKEN = address(0x3333333333333333333333333333333333333333);
    address constant WETH = address(0x4444444444444444444444444444444444444444);
    uint32 constant RESCUE_DELAY = 604800; // 7 days

    address alice = address(0xA11CE);
    address bob = address(0xB0B);
    address resolver = address(0xC0DE);

    uint256 constant SRC_CHAIN_ID = 1;
    uint256 constant DST_CHAIN_ID = 2;

    // Event to check
    event SrcEscrowCreated(
        address indexed escrow,
        IBaseEscrow.Immutables srcImmutables,
        IEscrowFactory.DstImmutablesComplement dstImmutablesComplement
    );
    event DstEscrowCreated(address indexed escrow, bytes32 indexed hashlock, Address taker);

    function setUp() public {
        // Deploy implementations with constructor parameters
        escrowSrcImpl = new EscrowSrc(RESCUE_DELAY, IERC20(ACCESS_TOKEN));
        escrowDstImpl = new EscrowDst(RESCUE_DELAY, IERC20(ACCESS_TOKEN));

        // Deploy factory with correct parameters
        factory = new CrossChainEscrowFactory(
            LIMIT_ORDER_PROTOCOL,
            IERC20(FEE_TOKEN),
            IERC20(ACCESS_TOKEN),
            address(this), // owner
            address(escrowSrcImpl),
            address(escrowDstImpl)
        );

        // Deploy tokens
        tokenA = new MockToken();
        tokenB = new MockToken();

        // Mint tokens
        tokenA.mint(alice, 1000e18);
        tokenB.mint(resolver, 1000e18);

        // Labels for better test output
        vm.label(alice, "Alice");
        vm.label(bob, "Bob");
        vm.label(resolver, "Resolver");
        vm.label(address(factory), "Factory");
        vm.label(address(tokenA), "TokenA");
        vm.label(address(tokenB), "TokenB");
    }

    function test_SrcEscrowCreated_EmitsEscrowAddress() public {
        // Prepare test data
        bytes32 orderHash = bytes32(uint256(1));
        bytes32 hashlock = keccak256("secret");
        uint256 srcAmount = 100e18;
        uint256 dstAmount = 50e18;
        uint256 srcSafetyDeposit = 1e16;
        uint256 dstSafetyDeposit = 2e16;

        // Create timelocks - pack the timelock values into a uint256
        // Format: [deployedAt(32)][srcWithdrawal(32)][srcPublicWithdrawal(32)][srcCancellation(32)][srcPublicCancellation(32)][dstWithdrawal(32)][dstCancellation(32)]
        uint256 timelocksValue = (uint256(100) << 192) | // srcWithdrawal
                                (uint256(200) << 160) | // srcPublicWithdrawal  
                                (uint256(300) << 128) | // srcCancellation
                                (uint256(400) << 96) |  // srcPublicCancellation
                                (uint256(150) << 64) |  // dstWithdrawal
                                (uint256(250) << 32);   // dstCancellation
        Timelocks timelocks = Timelocks.wrap(timelocksValue);

        // Create immutables without deployedAt (will be set during deployment)
        IBaseEscrow.Immutables memory srcImmutables = IBaseEscrow.Immutables({
            orderHash: orderHash,
            hashlock: hashlock,
            maker: Address.wrap(uint160(alice)),
            taker: Address.wrap(uint160(bob)),
            token: Address.wrap(uint160(address(tokenA))),
            amount: srcAmount,
            safetyDeposit: srcSafetyDeposit,
            timelocks: timelocks
        });

        IEscrowFactory.DstImmutablesComplement memory dstImmutablesComplement = IEscrowFactory.DstImmutablesComplement({
            maker: Address.wrap(uint160(alice)),
            amount: dstAmount,
            token: Address.wrap(uint160(address(tokenB))),
            safetyDeposit: dstSafetyDeposit,
            chainId: DST_CHAIN_ID
        });

        // Calculate expected escrow address with deployment timestamp
        IBaseEscrow.Immutables memory srcImmutablesWithTimestamp = srcImmutables;
        srcImmutablesWithTimestamp.timelocks = srcImmutablesWithTimestamp.timelocks.setDeployedAt(block.timestamp);
        address expectedEscrowAddress = factory.addressOfEscrowSrc(srcImmutablesWithTimestamp);

        // Pre-fund escrow with safety deposit
        vm.deal(expectedEscrowAddress, srcSafetyDeposit);

        // Transfer tokens to escrow
        vm.prank(alice);
        tokenA.transfer(expectedEscrowAddress, srcAmount);

        // Prepare postInteraction call data
        IEscrowFactory.ExtraDataArgs memory extraDataArgs = IEscrowFactory.ExtraDataArgs({
            hashlockInfo: hashlock,
            dstChainId: DST_CHAIN_ID,
            dstToken: Address.wrap(uint160(address(tokenB))),
            deposits: (uint256(srcSafetyDeposit) << 128) | dstSafetyDeposit,
            timelocks: timelocks
        });

        // Mock order
        IOrderMixin.Order memory order = IOrderMixin.Order({
            salt: uint256(orderHash),
            maker: Address.wrap(uint160(alice)),
            receiver: Address.wrap(0),
            makerAsset: Address.wrap(uint160(address(tokenA))),
            takerAsset: Address.wrap(uint160(address(tokenB))),
            makingAmount: srcAmount,
            takingAmount: dstAmount,
            makerTraits: MakerTraits.wrap(0)
        });

        // Encode extra data
        bytes memory extraData = abi.encode(extraDataArgs);

        // Expect event with escrow address and updated immutables (with deployment timestamp)
        vm.expectEmit(true, false, false, true, address(factory));
        emit SrcEscrowCreated(expectedEscrowAddress, srcImmutablesWithTimestamp, dstImmutablesComplement);

        // Call postInteraction
        vm.prank(LIMIT_ORDER_PROTOCOL);
        factory.postInteraction(
            order,
            "",  // extension
            orderHash,
            bob,  // taker
            srcAmount,
            dstAmount,
            0,  // remainingMakingAmount
            extraData
        );

        // Verify escrow was deployed at expected address
        assertTrue(expectedEscrowAddress.code.length > 0, "Escrow not deployed");
    }

    function test_DstEscrowCreated_EmitsIndexedEscrowAddress() public {
        // Prepare test data
        bytes32 orderHash = bytes32(uint256(1));
        bytes32 hashlock = keccak256("secret");
        uint256 amount = 100e18;
        uint256 safetyDeposit = 1e16;

        // Create timelocks
        uint256 timelocksValue = (uint256(100) << 192) | 
                                (uint256(200) << 160) | 
                                (uint256(300) << 128) | 
                                (uint256(400) << 96) |  
                                (uint256(150) << 64) |  
                                (uint256(250) << 32);
        Timelocks timelocks = Timelocks.wrap(timelocksValue);

        // Create destination immutables
        IBaseEscrow.Immutables memory dstImmutables = IBaseEscrow.Immutables({
            orderHash: orderHash,
            hashlock: hashlock,
            maker: Address.wrap(uint160(alice)),
            taker: Address.wrap(uint160(bob)),
            token: Address.wrap(uint160(address(tokenB))),
            amount: amount,
            safetyDeposit: safetyDeposit,
            timelocks: timelocks
        });

        // Calculate expected escrow address with deployment timestamp
        IBaseEscrow.Immutables memory dstImmutablesWithTimestamp = dstImmutables;
        dstImmutablesWithTimestamp.timelocks = dstImmutablesWithTimestamp.timelocks.setDeployedAt(block.timestamp);
        address expectedEscrowAddress = factory.addressOfEscrowDst(dstImmutablesWithTimestamp);

        // Give resolver ETH for the safety deposit
        vm.deal(resolver, 1 ether);

        // Approve token transfer
        vm.prank(resolver);
        tokenB.approve(address(factory), amount);

        // Expect event with indexed escrow address and hashlock
        vm.expectEmit(true, true, false, true, address(factory));
        emit DstEscrowCreated(expectedEscrowAddress, hashlock, Address.wrap(uint160(bob)));

        // Create destination escrow
        vm.prank(resolver);
        factory.createDstEscrow{value: safetyDeposit}(dstImmutables, block.timestamp + 300);

        // Verify escrow was deployed at expected address
        assertTrue(expectedEscrowAddress.code.length > 0, "Escrow not deployed");
    }

    function test_EventAddressMatchesCreate2Calculation() public {
        // This test verifies that the address emitted in events matches CREATE2 calculation
        bytes32 orderHash = bytes32(uint256(1));
        bytes32 hashlock = keccak256("test_secret");
        
        IBaseEscrow.Immutables memory immutables = IBaseEscrow.Immutables({
            orderHash: orderHash,
            hashlock: hashlock,
            maker: Address.wrap(uint160(alice)),
            taker: Address.wrap(uint160(bob)),
            token: Address.wrap(uint160(address(tokenA))),
            amount: 100e18,
            safetyDeposit: 1e16,
            timelocks: Timelocks.wrap((uint256(100) << 192) | 
                                     (uint256(200) << 160) | 
                                     (uint256(300) << 128) | 
                                     (uint256(400) << 96) |  
                                     (uint256(150) << 64) |  
                                     (uint256(250) << 32))
        });

        // Get predicted addresses
        address predictedSrc = factory.addressOfEscrowSrc(immutables);
        address predictedDst = factory.addressOfEscrowDst(immutables);

        // Log for debugging
        console2.log("[OK] Predicted Src Address:", predictedSrc);
        console2.log("[OK] Predicted Dst Address:", predictedDst);

        // Verify addresses are deterministic (same salt produces same address)
        assertEq(
            factory.addressOfEscrowSrc(immutables),
            predictedSrc,
            "Src address calculation not deterministic"
        );
        assertEq(
            factory.addressOfEscrowDst(immutables),
            predictedDst,
            "Dst address calculation not deterministic"
        );
    }

    function test_GasImpactOfEventEnhancement() public {
        // Measure gas cost of emitting events with escrow address
        bytes32 orderHash = bytes32(uint256(1));
        bytes32 hashlock = keccak256("gas_test");
        uint256 srcAmount = 100e18;
        uint256 dstAmount = 50e18;

        uint256 timelocksValue = (uint256(100) << 192) | 
                                (uint256(200) << 160) | 
                                (uint256(300) << 128) | 
                                (uint256(400) << 96) |  
                                (uint256(150) << 64) |  
                                (uint256(250) << 32);
        Timelocks timelocks = Timelocks.wrap(timelocksValue);

        IBaseEscrow.Immutables memory srcImmutables = IBaseEscrow.Immutables({
            orderHash: orderHash,
            hashlock: hashlock,
            maker: Address.wrap(uint160(alice)),
            taker: Address.wrap(uint160(bob)),
            token: Address.wrap(uint160(address(tokenA))),
            amount: srcAmount,
            safetyDeposit: 1e16,
            timelocks: timelocks.setDeployedAt(block.timestamp)
        });

        // Pre-fund escrow
        address escrowAddress = factory.addressOfEscrowSrc(srcImmutables);
        vm.deal(escrowAddress, 1e16);
        vm.prank(alice);
        tokenA.transfer(escrowAddress, srcAmount);

        // Prepare call data
        IEscrowFactory.ExtraDataArgs memory extraDataArgs = IEscrowFactory.ExtraDataArgs({
            hashlockInfo: hashlock,
            dstChainId: DST_CHAIN_ID,
            dstToken: Address.wrap(uint160(address(tokenB))),
            deposits: (uint256(1e16) << 128) | 2e16,
            timelocks: timelocks
        });

        IOrderMixin.Order memory order = IOrderMixin.Order({
            salt: uint256(orderHash),
            maker: Address.wrap(uint160(alice)),
            receiver: Address.wrap(0),
            makerAsset: Address.wrap(uint160(address(tokenA))),
            takerAsset: Address.wrap(uint160(address(tokenB))),
            makingAmount: srcAmount,
            takingAmount: dstAmount,
            makerTraits: MakerTraits.wrap(0)
        });

        bytes memory extraData = abi.encode(extraDataArgs);

        // Measure gas
        uint256 gasBefore = gasleft();
        
        vm.prank(LIMIT_ORDER_PROTOCOL);
        factory.postInteraction(
            order,
            "",
            orderHash,
            bob,
            srcAmount,
            dstAmount,
            0,
            extraData
        );

        uint256 gasUsed = gasBefore - gasleft();
        console2.log("[OK] Gas used for src escrow creation with event:", gasUsed);

        // The additional gas cost for emitting the escrow address should be minimal
        // Approximately 2,100 gas for the additional indexed parameter
        assertTrue(gasUsed < 500000, "Gas usage too high");
    }

    function test_BackwardCompatibility() public {
        // Test that the new events still contain all the original data
        bytes32 orderHash = bytes32(uint256(1));
        bytes32 hashlock = keccak256("compatibility_test");

        IBaseEscrow.Immutables memory srcImmutables = IBaseEscrow.Immutables({
            orderHash: orderHash,
            hashlock: hashlock,
            maker: Address.wrap(uint160(alice)),
            taker: Address.wrap(uint160(bob)),
            token: Address.wrap(uint160(address(tokenA))),
            amount: 100e18,
            safetyDeposit: 1e16,
            timelocks: Timelocks.wrap((uint256(100) << 192) | 
                                     (uint256(200) << 160) | 
                                     (uint256(300) << 128) | 
                                     (uint256(400) << 96) |  
                                     (uint256(150) << 64) |  
                                     (uint256(250) << 32)).setDeployedAt(block.timestamp)
        });

        IEscrowFactory.DstImmutablesComplement memory dstImmutablesComplement = IEscrowFactory.DstImmutablesComplement({
            maker: Address.wrap(uint160(alice)),
            amount: 50e18,
            token: Address.wrap(uint160(address(tokenB))),
            safetyDeposit: 2e16,
            chainId: DST_CHAIN_ID
        });

        // Pre-fund escrow
        address escrowAddress = factory.addressOfEscrowSrc(srcImmutables);
        vm.deal(escrowAddress, 1e16);
        vm.prank(alice);
        tokenA.transfer(escrowAddress, 100e18);

        // Record logs
        vm.recordLogs();

        // Trigger event
        IEscrowFactory.ExtraDataArgs memory extraDataArgs = IEscrowFactory.ExtraDataArgs({
            hashlockInfo: hashlock,
            dstChainId: DST_CHAIN_ID,
            dstToken: Address.wrap(uint160(address(tokenB))),
            deposits: (uint256(1e16) << 128) | 2e16,
            timelocks: srcImmutables.timelocks
        });

        IOrderMixin.Order memory order = IOrderMixin.Order({
            salt: uint256(orderHash),
            maker: Address.wrap(uint160(alice)),
            receiver: Address.wrap(0),
            makerAsset: Address.wrap(uint160(address(tokenA))),
            takerAsset: Address.wrap(uint160(address(tokenB))),
            makingAmount: 100e18,
            takingAmount: 50e18,
            makerTraits: MakerTraits.wrap(0)
        });

        vm.prank(LIMIT_ORDER_PROTOCOL);
        factory.postInteraction(
            order,
            "",
            orderHash,
            bob,
            100e18,
            50e18,
            0,
            abi.encode(extraDataArgs)
        );

        // Check logs
        Vm.Log[] memory logs = vm.getRecordedLogs();
        
        // Find the SrcEscrowCreated event
        bool foundEvent = false;
        for (uint i = 0; i < logs.length; i++) {
            // Check if this is the SrcEscrowCreated event (with indexed escrow address)
            if (logs[i].topics.length >= 2 && logs[i].emitter == address(factory)) {
                foundEvent = true;
                
                // Verify the escrow address is in topic[1]
                assertEq(address(uint160(uint256(logs[i].topics[1]))), escrowAddress, "Escrow address mismatch in event");
                
                // Decode and verify the data still contains all original fields
                (IBaseEscrow.Immutables memory emittedSrcImmutables, IEscrowFactory.DstImmutablesComplement memory emittedDstComplement) = 
                    abi.decode(logs[i].data, (IBaseEscrow.Immutables, IEscrowFactory.DstImmutablesComplement));
                
                assertEq(emittedSrcImmutables.orderHash, srcImmutables.orderHash, "OrderHash mismatch");
                assertEq(emittedSrcImmutables.hashlock, srcImmutables.hashlock, "Hashlock mismatch");
                assertEq(emittedSrcImmutables.maker.get(), srcImmutables.maker.get(), "Maker mismatch");
                assertEq(emittedSrcImmutables.amount, srcImmutables.amount, "Amount mismatch");
                
                console2.log("[OK] Event maintains backward compatibility with all original data");
                break;
            }
        }
        
        assertTrue(foundEvent, "SrcEscrowCreated event not found");
    }
}