// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Test.sol";
import "../contracts/SimplifiedEscrowFactory.sol";
import "../contracts/EscrowSrc.sol";
import "../contracts/EscrowDst.sol";
import "./mocks/MockLimitOrderProtocol.sol";
import { BMNToken } from "../contracts/BMNToken.sol";
import "../contracts/mocks/TokenMock.sol";
import { IOrderMixin } from "../dependencies/limit-order-protocol/contracts/interfaces/IOrderMixin.sol";
import { Address } from "solidity-utils/contracts/libraries/AddressLib.sol";
import { MakerTraits } from "../dependencies/limit-order-protocol/contracts/libraries/MakerTraitsLib.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { Timelocks } from "../contracts/libraries/TimelocksLib.sol";

/**
 * @title SingleChainAtomicSwapTest
 * @notice Tests the full atomic swap flow on a single chain
 */
contract SingleChainAtomicSwapTest is Test {
    SimplifiedEscrowFactory factory;
    MockLimitOrderProtocol limitOrderProtocol;
    BMNToken bmnToken;
    TokenMock otherToken; // Keep TokenMock for the other token
    EscrowSrc srcImpl;
    EscrowDst dstImpl;
    
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address resolver = makeAddr("resolver");
    address owner = makeAddr("owner");
    
    bytes32 secret = keccak256("test_secret_123");
    bytes32 hashlock = keccak256(abi.encode(secret));
    
    uint256 constant SWAP_AMOUNT = 10e18;
    uint256 constant INITIAL_BALANCE = 1000e18;
    uint32 constant RESCUE_DELAY = 7 days;
    
    event PostInteractionEscrowCreated(
        address indexed escrow,
        bytes32 indexed hashlock,
        address indexed protocol,
        address taker,
        uint256 amount
    );
    
    function setUp() public {
        // Deploy real BMN token and mock for other token
        bmnToken = new BMNToken(address(this)); // Deploy with initial supply to this contract
        otherToken = new TokenMock("Other Token", "OTHER", 18);
        
        // Deploy escrow implementations
        srcImpl = new EscrowSrc(RESCUE_DELAY, IERC20(address(0)));
        dstImpl = new EscrowDst(RESCUE_DELAY, IERC20(address(0)));
        
        // Deploy factory
        factory = new SimplifiedEscrowFactory(
            address(srcImpl),
            address(dstImpl),
            owner
        );
        
        // Deploy mock limit order protocol
        limitOrderProtocol = new MockLimitOrderProtocol();
        
        // Setup whitelist
        vm.startPrank(owner);
        factory.addResolver(resolver);
        vm.stopPrank();
        
        // Fund accounts with BMN tokens (transfer from initial supply)
        bmnToken.transfer(alice, INITIAL_BALANCE);
        bmnToken.transfer(bob, INITIAL_BALANCE);
        bmnToken.transfer(resolver, INITIAL_BALANCE);
        
        // Fund accounts with other tokens (using mint since it's a mock)
        otherToken.mint(alice, INITIAL_BALANCE);
        otherToken.mint(bob, INITIAL_BALANCE);
        otherToken.mint(resolver, INITIAL_BALANCE);
    }
    
    function testFullAtomicSwapFlow() public {
        // 1. Alice approves limit order protocol
        vm.startPrank(alice);
        bmnToken.approve(address(limitOrderProtocol), SWAP_AMOUNT);
        vm.stopPrank();
        
        // 2. Create Alice's order
        IOrderMixin.Order memory aliceOrder = IOrderMixin.Order({
            salt: 12345,
            maker: Address.wrap(uint160(alice)),
            receiver: Address.wrap(uint160(alice)),
            makerAsset: Address.wrap(uint160(address(bmnToken))),
            takerAsset: Address.wrap(uint160(address(otherToken))),
            makingAmount: SWAP_AMOUNT,
            takingAmount: SWAP_AMOUNT,
            makerTraits: MakerTraits.wrap(0)
        });
        
        // 3. Prepare extension data for escrow creation
        uint256 deposits = 0; // No safety deposits for simplicity
        uint256 timelocks = (uint256(block.timestamp + 3600) << 128) | uint256(block.timestamp + 300);
        
        bytes memory extensionData = abi.encode(
            hashlock,
            1, // Simulated destination chain (same chain for testing)
            address(otherToken),
            deposits,
            timelocks
        );
        
        // 4. Resolver fills Alice's order
        vm.startPrank(resolver);
        otherToken.approve(address(limitOrderProtocol), SWAP_AMOUNT);
        bmnToken.approve(address(factory), SWAP_AMOUNT); // Approve factory to pull tokens
        
        // Expect the PostInteractionEscrowCreated event (check all params except escrow address)
        vm.expectEmit(false, true, true, true);
        emit PostInteractionEscrowCreated(
            address(0), // We don't know the exact address yet, so skip checking first indexed param
            hashlock,
            address(limitOrderProtocol),
            resolver,
            SWAP_AMOUNT
        );
        
        // Fill the order with post-interaction
        limitOrderProtocol.fillOrderWithPostInteraction(
            aliceOrder,
            "", // signature not needed for mock
            SWAP_AMOUNT,
            0, // takerTraits
            address(factory),
            extensionData
        );
        vm.stopPrank();
        
        // 5. Verify source escrow was created
        address srcEscrow = factory.escrows(hashlock);
        assertNotEq(srcEscrow, address(0), "Source escrow should be created");
        
        // Verify escrow has the tokens
        assertEq(bmnToken.balanceOf(srcEscrow), SWAP_AMOUNT, "Escrow should have tokens");
        
        // 6. Resolver creates destination escrow (simulating other chain)
        // Resolver funds it with their own tokens
        vm.startPrank(resolver); 
        otherToken.approve(address(factory), SWAP_AMOUNT);
        
        // Create destination escrow immutables with timelocks
        // On destination chain: Resolver is maker (locks tokens), Alice is taker (withdraws with secret)
        uint256 packedTimelocks = uint256(uint32(block.timestamp)) << 224; // deployedAt
        packedTimelocks |= uint256(uint32(300)) << 128; // dstWithdrawal offset
        packedTimelocks |= uint256(uint32(600)) << 160; // dstPublicWithdrawal offset
        packedTimelocks |= uint256(uint32(3600)) << 192; // dstCancellation offset
        
        IBaseEscrow.Immutables memory dstImmutables = IBaseEscrow.Immutables({
            orderHash: keccak256(abi.encode(aliceOrder)),
            hashlock: hashlock,
            maker: Address.wrap(uint160(resolver)), // Resolver locks tokens on destination
            taker: Address.wrap(uint160(alice)), // Alice withdraws with secret
            token: Address.wrap(uint160(address(otherToken))),
            amount: SWAP_AMOUNT,
            safetyDeposit: 0,
            timelocks: Timelocks.wrap(packedTimelocks)
        });
        
        address dstEscrow = factory.createDstEscrow(dstImmutables);
        vm.stopPrank();
        
        assertNotEq(dstEscrow, address(0), "Destination escrow should be created");
        assertEq(otherToken.balanceOf(dstEscrow), SWAP_AMOUNT, "Dst escrow should have tokens");
        
        // 7. Alice withdraws from destination escrow with secret
        vm.warp(block.timestamp + 301); // Move past withdrawal timelock
        
        vm.startPrank(alice);
        EscrowDst(dstEscrow).withdraw(secret, dstImmutables);
        vm.stopPrank();
        
        // Verify Alice received tokens from destination
        assertEq(otherToken.balanceOf(alice), INITIAL_BALANCE, "Alice should have received OTHER tokens");
        
        // 8. Resolver withdraws from source escrow with revealed secret
        // Create source escrow immutables with timelocks
        uint256 srcPackedTimelocks = uint256(uint32(block.timestamp - 301)) << 224; // deployedAt (account for time warp)
        srcPackedTimelocks |= uint256(uint32(0)) << 0; // srcWithdrawal offset (already started)
        srcPackedTimelocks |= uint256(uint32(300)) << 32; // srcPublicWithdrawal offset
        srcPackedTimelocks |= uint256(uint32(3600)) << 64; // srcCancellation offset
        srcPackedTimelocks |= uint256(uint32(3900)) << 96; // srcPublicCancellation offset
        
        IBaseEscrow.Immutables memory srcImmutables = IBaseEscrow.Immutables({
            orderHash: keccak256(abi.encode(aliceOrder)),
            hashlock: hashlock,
            maker: Address.wrap(uint160(alice)),
            taker: Address.wrap(uint160(resolver)),
            token: Address.wrap(uint160(address(bmnToken))),
            amount: SWAP_AMOUNT,
            safetyDeposit: 0,
            timelocks: Timelocks.wrap(srcPackedTimelocks)
        });
        
        vm.startPrank(resolver);
        EscrowSrc(srcEscrow).withdraw(secret, srcImmutables);
        vm.stopPrank();
        
        // 9. Verify final balances
        // Alice: Started with 1000 BMN, 1000 OTHER -> Lost 10 BMN (to resolver via order), Gained 10 OTHER (from dst escrow)
        assertEq(bmnToken.balanceOf(alice), INITIAL_BALANCE - SWAP_AMOUNT, "Alice sent BMN");
        assertEq(otherToken.balanceOf(alice), INITIAL_BALANCE + SWAP_AMOUNT, "Alice received OTHER");
        // Resolver: Started with 1000 BMN, 1000 OTHER -> Gained 10 BMN (from src escrow), Lost 10 OTHER (to dst escrow)
        assertEq(bmnToken.balanceOf(resolver), INITIAL_BALANCE + SWAP_AMOUNT, "Resolver received BMN");
        assertEq(otherToken.balanceOf(resolver), INITIAL_BALANCE - SWAP_AMOUNT, "Resolver sent OTHER");
    }
    
    function testPostInteractionRevertsForNonWhitelistedResolver() public {
        // Setup order
        IOrderMixin.Order memory order = IOrderMixin.Order({
            salt: 12345,
            maker: Address.wrap(uint160(alice)),
            receiver: Address.wrap(uint160(alice)),
            makerAsset: Address.wrap(uint160(address(bmnToken))),
            takerAsset: Address.wrap(uint160(address(otherToken))),
            makingAmount: SWAP_AMOUNT,
            takingAmount: SWAP_AMOUNT,
            makerTraits: MakerTraits.wrap(0)
        });
        
        bytes memory extensionData = abi.encode(
            hashlock,
            1,
            address(otherToken),
            0,
            0
        );
        
        // Try to call postInteraction with non-whitelisted address
        vm.expectRevert("Resolver not whitelisted");
        factory.postInteraction(
            order,
            "",
            keccak256(abi.encode(order)),
            alice, // Alice is not a whitelisted resolver
            SWAP_AMOUNT,
            SWAP_AMOUNT,
            0,
            extensionData
        );
    }
    
    function testPostInteractionRevertsForDuplicateEscrow() public {
        // Setup and create first escrow
        vm.startPrank(alice);
        bmnToken.approve(address(limitOrderProtocol), SWAP_AMOUNT);
        vm.stopPrank();
        
        IOrderMixin.Order memory order = IOrderMixin.Order({
            salt: 12345,
            maker: Address.wrap(uint160(alice)),
            receiver: Address.wrap(uint160(alice)),
            makerAsset: Address.wrap(uint160(address(bmnToken))),
            takerAsset: Address.wrap(uint160(address(otherToken))),
            makingAmount: SWAP_AMOUNT,
            takingAmount: SWAP_AMOUNT,
            makerTraits: MakerTraits.wrap(0)
        });
        
        bytes memory extensionData = abi.encode(
            hashlock,
            1,
            address(otherToken),
            0,
            (uint256(block.timestamp + 3600) << 128) | uint256(block.timestamp + 300)
        );
        
        // Create first escrow
        vm.startPrank(resolver);
        otherToken.approve(address(limitOrderProtocol), SWAP_AMOUNT);
        bmnToken.approve(address(factory), SWAP_AMOUNT);
        
        limitOrderProtocol.fillOrderWithPostInteraction(
            order,
            "",
            SWAP_AMOUNT,
            0,
            address(factory),
            extensionData
        );
        vm.stopPrank();
        
        // Try to create duplicate escrow
        vm.startPrank(resolver);
        
        // Should revert with "Escrow already exists"
        vm.expectRevert("Escrow already exists");
        factory.postInteraction(
            order,
            "",
            keccak256(abi.encode(order)),
            resolver,
            SWAP_AMOUNT,
            SWAP_AMOUNT,
            0,
            extensionData
        );
        vm.stopPrank();
    }
    
    function testPostInteractionGasUsage() public {
        // Setup order
        IOrderMixin.Order memory order = IOrderMixin.Order({
            salt: 12345,
            maker: Address.wrap(uint160(alice)),
            receiver: Address.wrap(uint160(alice)),
            makerAsset: Address.wrap(uint160(address(bmnToken))),
            takerAsset: Address.wrap(uint160(address(otherToken))),
            makingAmount: SWAP_AMOUNT,
            takingAmount: SWAP_AMOUNT,
            makerTraits: MakerTraits.wrap(0)
        });
        
        bytes memory extensionData = abi.encode(
            hashlock,
            1,
            address(otherToken),
            0,
            (uint256(block.timestamp + 3600) << 128) | uint256(block.timestamp + 300)
        );
        
        // Setup tokens
        vm.startPrank(resolver);
        bmnToken.approve(address(factory), SWAP_AMOUNT);
        bmnToken.transfer(resolver, SWAP_AMOUNT); // Ensure resolver has tokens
        
        // Measure gas for postInteraction call
        uint256 gasBefore = gasleft();
        factory.postInteraction(
            order,
            "",
            keccak256(abi.encode(order)),
            resolver,
            SWAP_AMOUNT,
            SWAP_AMOUNT,
            0,
            extensionData
        );
        uint256 gasUsed = gasBefore - gasleft();
        
        vm.stopPrank();
        
        console.log("PostInteraction gas used:", gasUsed);
        assertLt(gasUsed, 250000, "Gas usage should be under 250k");
    }
}