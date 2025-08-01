// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";

import { EscrowFactory } from "../contracts/EscrowFactory.sol";
import { IEscrowFactory } from "../contracts/interfaces/IEscrowFactory.sol";
import { IBaseEscrow } from "../contracts/interfaces/IBaseEscrow.sol";
import { CrossChainHelper } from "./CrossChainHelper.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { Address, AddressLib } from "solidity-utils/contracts/libraries/AddressLib.sol";
import { ImmutablesLib } from "../contracts/libraries/ImmutablesLib.sol";

contract EscrowFactoryTest is CrossChainHelper {
    using AddressLib for address;
    using ImmutablesLib for IBaseEscrow.Immutables;
    
    event SrcEscrowCreated(IBaseEscrow.Immutables srcImmutables, IEscrowFactory.DstImmutablesComplement dstImmutablesComplement);
    event DstEscrowCreated(address escrow, bytes32 hashlock, Address taker);

    function setUp() public {
        setupContracts();
    }

    function test_factoryDeployment() public {
        assertEq(factory.owner(), deployer);
        assertEq(address(factory.LIMIT_ORDER_PROTOCOL()), address(lop));
        assertEq(address(factory.FEE_TOKEN()), address(feeToken));
        assertEq(address(factory.ACCESS_TOKEN()), address(accessToken));
        assertEq(factory.RESCUE_DELAY_SRC(), DEFAULT_RESCUE_DELAY);
        assertEq(factory.RESCUE_DELAY_DST(), DEFAULT_RESCUE_DELAY);
    }

    function test_escrowImplementations() public {
        assertTrue(factory.ESCROW_SRC_IMPLEMENTATION() != address(0));
        assertTrue(factory.ESCROW_DST_IMPLEMENTATION() != address(0));
    }

    function test_addressOfEscrowSrc_deterministic() public {
        (bytes32 secret, bytes32 hashlock) = generateSecretAndHash();
        bytes32 orderHash = keccak256("order");
        
        IBaseEscrow.Immutables memory immutables = createSrcImmutables(
            orderHash,
            hashlock,
            alice,
            bob,
            address(tokenA),
            100 ether,
            DEFAULT_SAFETY_DEPOSIT,
            createDefaultTimelocks()
        );
        
        address expectedAddress = factory.addressOfEscrowSrc(immutables);
        
        // Same immutables should produce same address
        address sameAddress = factory.addressOfEscrowSrc(immutables);
        assertEq(expectedAddress, sameAddress);
        
        // Different immutables should produce different address
        immutables.amount = 200 ether;
        address differentAddress = factory.addressOfEscrowSrc(immutables);
        assertTrue(expectedAddress != differentAddress);
    }

    function test_addressOfEscrowDst_deterministic() public {
        (bytes32 secret, bytes32 hashlock) = generateSecretAndHash();
        bytes32 orderHash = keccak256("order");
        
        IBaseEscrow.Immutables memory immutables = createDstImmutables(
            orderHash,
            hashlock,
            alice,
            bob,
            address(tokenB),
            100 ether,
            DEFAULT_SAFETY_DEPOSIT,
            createDefaultTimelocks()
        );
        
        address expectedAddress = factory.addressOfEscrowDst(immutables);
        
        // Same immutables should produce same address
        address sameAddress = factory.addressOfEscrowDst(immutables);
        assertEq(expectedAddress, sameAddress);
        
        // Different immutables should produce different address
        immutables.amount = 200 ether;
        address differentAddress = factory.addressOfEscrowDst(immutables);
        assertTrue(expectedAddress != differentAddress);
    }

    function test_createDstEscrow_success() public {
        (bytes32 secret, bytes32 hashlock) = generateSecretAndHash();
        bytes32 orderHash = keccak256("order");
        
        IBaseEscrow.Immutables memory dstImmutables = createDstImmutables(
            orderHash,
            hashlock,
            alice,
            bob,
            address(tokenB),
            100 ether,
            DEFAULT_SAFETY_DEPOSIT,
            createDefaultTimelocks()
        );
        
        // Get expected address
        address expectedEscrow = factory.addressOfEscrowDst(dstImmutables);
        
        // Bob (resolver) approves tokens and creates escrow
        vm.startPrank(bob);
        tokenB.approve(address(factory), 100 ether);
        
        // Expect event
        vm.expectEmit(true, true, true, true);
        emit DstEscrowCreated(expectedEscrow, hashlock, alice.toAddress());
        
        // Create escrow with safety deposit
        factory.createDstEscrow{value: DEFAULT_SAFETY_DEPOSIT}(
            dstImmutables,
            block.timestamp + SRC_CANCELLATION_START
        );
        vm.stopPrank();
        
        // Verify escrow was deployed
        assertGt(expectedEscrow.code.length, 0);
        
        // Verify tokens were transferred
        assertEq(tokenB.balanceOf(expectedEscrow), 100 ether);
        
        // Verify safety deposit
        assertEq(expectedEscrow.balance, DEFAULT_SAFETY_DEPOSIT);
    }

    function test_createDstEscrow_invalidSafetyDeposit() public {
        (bytes32 secret, bytes32 hashlock) = generateSecretAndHash();
        bytes32 orderHash = keccak256("order");
        
        IBaseEscrow.Immutables memory dstImmutables = createDstImmutables(
            orderHash,
            hashlock,
            alice,
            bob,
            address(tokenB),
            100 ether,
            DEFAULT_SAFETY_DEPOSIT,
            createDefaultTimelocks()
        );
        
        vm.startPrank(bob);
        tokenB.approve(address(factory), 100 ether);
        
        // Try to create with insufficient safety deposit
        vm.expectRevert();
        factory.createDstEscrow{value: DEFAULT_SAFETY_DEPOSIT - 1}(
            dstImmutables,
            block.timestamp + SRC_CANCELLATION_START
        );
        vm.stopPrank();
    }

    function test_createDstEscrow_insufficientBalance() public {
        (bytes32 secret, bytes32 hashlock) = generateSecretAndHash();
        bytes32 orderHash = keccak256("order");
        
        IBaseEscrow.Immutables memory dstImmutables = createDstImmutables(
            orderHash,
            hashlock,
            alice,
            bob,
            address(tokenB),
            2000 ether, // More than Bob has
            DEFAULT_SAFETY_DEPOSIT,
            createDefaultTimelocks()
        );
        
        vm.startPrank(bob);
        tokenB.approve(address(factory), 2000 ether);
        
        vm.expectRevert();
        factory.createDstEscrow{value: DEFAULT_SAFETY_DEPOSIT}(
            dstImmutables,
            block.timestamp + SRC_CANCELLATION_START
        );
        vm.stopPrank();
    }

    function test_createDstEscrow_duplicateCreation() public {
        (bytes32 secret, bytes32 hashlock) = generateSecretAndHash();
        bytes32 orderHash = keccak256("order");
        
        IBaseEscrow.Immutables memory dstImmutables = createDstImmutables(
            orderHash,
            hashlock,
            alice,
            bob,
            address(tokenB),
            100 ether,
            DEFAULT_SAFETY_DEPOSIT,
            createDefaultTimelocks()
        );
        
        vm.startPrank(bob);
        tokenB.approve(address(factory), 200 ether); // Approve for two attempts
        
        // First creation should succeed
        factory.createDstEscrow{value: DEFAULT_SAFETY_DEPOSIT}(
            dstImmutables,
            block.timestamp + SRC_CANCELLATION_START
        );
        
        // Second creation should fail (escrow already exists)
        vm.expectRevert();
        factory.createDstEscrow{value: DEFAULT_SAFETY_DEPOSIT}(
            dstImmutables,
            block.timestamp + SRC_CANCELLATION_START
        );
        vm.stopPrank();
    }

    function test_createDstEscrow_invalidCreationTime() public {
        (bytes32 secret, bytes32 hashlock) = generateSecretAndHash();
        bytes32 orderHash = keccak256("order");
        
        IBaseEscrow.Immutables memory dstImmutables = createDstImmutables(
            orderHash,
            hashlock,
            alice,
            bob,
            address(tokenB),
            100 ether,
            DEFAULT_SAFETY_DEPOSIT,
            createDefaultTimelocks()
        );
        
        vm.startPrank(bob);
        tokenB.approve(address(factory), 100 ether);
        
        // Try to create after src cancellation time
        advanceTime(SRC_CANCELLATION_START + 1);
        
        vm.expectRevert(IEscrowFactory.InvalidCreationTime.selector);
        factory.createDstEscrow{value: DEFAULT_SAFETY_DEPOSIT}(
            dstImmutables,
            block.timestamp - 1 // Past cancellation time
        );
        vm.stopPrank();
    }

    function test_createDstEscrow_withAccessToken() public {
        // First set access token requirement
        vm.prank(deployer);
        factory.setAccessToken(address(accessToken));
        
        (bytes32 secret, bytes32 hashlock) = generateSecretAndHash();
        bytes32 orderHash = keccak256("order");
        
        IBaseEscrow.Immutables memory dstImmutables = createDstImmutables(
            orderHash,
            hashlock,
            alice,
            bob,
            address(tokenB),
            100 ether,
            DEFAULT_SAFETY_DEPOSIT,
            createDefaultTimelocks()
        );
        
        // Try without access token - should fail
        address charlie = address(0x1234);
        vm.deal(charlie, 10 ether);
        tokenB.mint(charlie, 100 ether);
        
        vm.startPrank(charlie);
        tokenB.approve(address(factory), 100 ether);
        
        vm.expectRevert();
        factory.createDstEscrow{value: DEFAULT_SAFETY_DEPOSIT}(
            dstImmutables,
            block.timestamp + SRC_CANCELLATION_START
        );
        vm.stopPrank();
        
        // Bob has access token - should succeed
        vm.startPrank(bob);
        tokenB.approve(address(factory), 100 ether);
        factory.createDstEscrow{value: DEFAULT_SAFETY_DEPOSIT}(
            dstImmutables,
            block.timestamp + SRC_CANCELLATION_START
        );
        vm.stopPrank();
    }

    function test_addressComputation_consistency() public {
        (bytes32 secret, bytes32 hashlock) = generateSecretAndHash();
        bytes32 orderHash = keccak256("order");
        
        // Create immutables for both chains
        IBaseEscrow.Immutables memory srcImmutables = createSrcImmutables(
            orderHash,
            hashlock,
            alice,
            bob,
            address(tokenA),
            100 ether,
            DEFAULT_SAFETY_DEPOSIT,
            createDefaultTimelocks()
        );
        
        IBaseEscrow.Immutables memory dstImmutables = createDstImmutables(
            orderHash,
            hashlock,
            alice,
            bob,
            address(tokenB),
            100 ether,
            DEFAULT_SAFETY_DEPOSIT,
            createDefaultTimelocks()
        );
        
        // Get computed addresses
        address srcEscrow = factory.addressOfEscrowSrc(srcImmutables);
        address dstEscrow = factory.addressOfEscrowDst(dstImmutables);
        
        // Addresses should be different (different immutables)
        assertTrue(srcEscrow != dstEscrow);
        
        // Deploy dst escrow and verify address matches
        vm.startPrank(bob);
        tokenB.approve(address(factory), 100 ether);
        factory.createDstEscrow{value: DEFAULT_SAFETY_DEPOSIT}(
            dstImmutables,
            block.timestamp + SRC_CANCELLATION_START
        );
        vm.stopPrank();
        
        // Verify deployed at expected address
        assertGt(dstEscrow.code.length, 0);
    }
}