// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Test.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { Clones } from "openzeppelin-contracts/contracts/proxy/Clones.sol";
import { Address, AddressLib } from "solidity-utils/contracts/libraries/AddressLib.sol";

import { SimplifiedEscrowFactoryV4 } from "../contracts/SimplifiedEscrowFactoryV4.sol";
import { EscrowSrc } from "../contracts/EscrowSrc.sol";
import { EscrowDst } from "../contracts/EscrowDst.sol";
import { IBaseEscrow } from "../contracts/interfaces/IBaseEscrow.sol";
import { IEscrowFactory } from "../contracts/interfaces/IEscrowFactory.sol";
import { ImmutablesLib } from "../contracts/libraries/ImmutablesLib.sol";
import { Timelocks, TimelocksLib } from "../contracts/libraries/TimelocksLib.sol";
import { TokenMock } from "../contracts/mocks/TokenMock.sol";
import { MockLimitOrderProtocol } from "./mocks/MockLimitOrderProtocol.sol";
import { IOrderMixin } from "../dependencies/limit-order-protocol/contracts/interfaces/IOrderMixin.sol";
import { MakerTraits } from "../dependencies/limit-order-protocol/contracts/libraries/MakerTraitsLib.sol";

/**
 * @title SimplifiedEscrowFactoryV4Test
 * @notice Comprehensive unit tests for SimplifiedEscrowFactoryV4
 * @dev Tests all V4.0 fixes including constructor deployment, timelock packing, and 1inch integration
 */
contract SimplifiedEscrowFactoryV4Test is Test {
    using AddressLib for Address;
    using ImmutablesLib for IBaseEscrow.Immutables;
    using TimelocksLib for Timelocks;
    using Clones for address;
    
    // Constants
    uint32 constant RESCUE_DELAY = 7 days;
    uint256 constant INITIAL_BALANCE = 10000 ether;
    uint256 constant SWAP_AMOUNT = 100 ether;
    uint256 constant SAFETY_DEPOSIT = 1 ether;
    
    // Test accounts
    address deployer = address(0x1);
    address maker = address(0x2);
    address resolver = address(0x3);
    address unauthorizedUser = address(0x4);
    
    // Contracts
    SimplifiedEscrowFactoryV4 factory;
    MockLimitOrderProtocol limitOrderProtocol;
    TokenMock tokenA;
    TokenMock tokenB;
    IERC20 accessToken;
    
    // Test data
    bytes32 hashlock;
    bytes32 secret;
    
    event SrcEscrowCreated(
        IBaseEscrow.Immutables srcImmutables,
        IEscrowFactory.DstImmutablesComplement dstImmutablesComplement
    );
    
    event PostInteractionEscrowCreated(
        address indexed escrow,
        bytes32 indexed hashlock,
        address indexed protocol,
        address taker,
        uint256 amount
    );
    
    function setUp() public {
        // Setup test accounts
        vm.deal(deployer, 100 ether);
        vm.deal(maker, 100 ether);
        vm.deal(resolver, 100 ether);
        vm.deal(unauthorizedUser, 100 ether);
        
        // Deploy tokens
        tokenA = new TokenMock("Token A", "TKA", 18);
        tokenB = new TokenMock("Token B", "TKB", 18);
        accessToken = IERC20(address(0)); // No access token for simplicity
        
        // Deploy mock limit order protocol
        limitOrderProtocol = new MockLimitOrderProtocol();
        
        // Deploy factory with constructor-based implementation deployment
        vm.prank(deployer);
        factory = new SimplifiedEscrowFactoryV4(
            address(limitOrderProtocol),
            deployer,
            RESCUE_DELAY,
            accessToken,
            address(0) // No WETH for simplicity
        );
        
        // Setup hashlock and secret
        secret = keccak256("test_secret");
        hashlock = keccak256(abi.encode(secret));
        
        // Fund test accounts
        tokenA.mint(maker, INITIAL_BALANCE);
        tokenA.mint(resolver, INITIAL_BALANCE);
        tokenB.mint(maker, INITIAL_BALANCE);
        tokenB.mint(resolver, INITIAL_BALANCE);
        
        // Setup approvals
        vm.prank(maker);
        tokenA.approve(address(factory), type(uint256).max);
        vm.prank(maker);
        tokenA.approve(address(limitOrderProtocol), type(uint256).max);
        
        vm.prank(resolver);
        tokenA.approve(address(factory), type(uint256).max);
        vm.prank(resolver);
        tokenB.approve(address(factory), type(uint256).max);
        vm.prank(resolver);
        tokenB.approve(address(limitOrderProtocol), type(uint256).max);
    }
    
    /**
     * @notice Test that factory deployment correctly sets implementation addresses
     * @dev Verifies that implementations are deployed in constructor and stored correctly
     */
    function testFactoryDeployment() public view {
        // Check that implementation addresses are set
        address srcImpl = factory.ESCROW_SRC_IMPLEMENTATION();
        address dstImpl = factory.ESCROW_DST_IMPLEMENTATION();
        
        assertNotEq(srcImpl, address(0), "Source implementation should be deployed");
        assertNotEq(dstImpl, address(0), "Destination implementation should be deployed");
        
        // Check that bytecode hashes are computed
        bytes32 srcHash = factory.ESCROW_SRC_PROXY_BYTECODE_HASH();
        bytes32 dstHash = factory.ESCROW_DST_PROXY_BYTECODE_HASH();
        
        assertNotEq(srcHash, bytes32(0), "Source proxy bytecode hash should be computed");
        assertNotEq(dstHash, bytes32(0), "Destination proxy bytecode hash should be computed");
        
        // Verify the implementations have code
        assertGt(srcImpl.code.length, 0, "Source implementation should have code");
        assertGt(dstImpl.code.length, 0, "Destination implementation should have code");
    }
    
    /**
     * @notice Test that FACTORY immutable in escrows points to SimplifiedEscrowFactoryV4
     * @dev This is the key V4.0 fix - FACTORY should be our factory, not CREATE3 proxy
     */
    function testFactoryImmutableInEscrows() public {
        // Create immutables for source escrow
        Timelocks timelocks = _createTestTimelocks();
        IBaseEscrow.Immutables memory immutables = IBaseEscrow.Immutables({
            orderHash: keccak256("test_order"),
            hashlock: hashlock,
            maker: Address.wrap(uint160(maker)),
            taker: Address.wrap(uint160(resolver)),
            token: Address.wrap(uint160(address(tokenA))),
            amount: SWAP_AMOUNT,
            safetyDeposit: SAFETY_DEPOSIT,
            timelocks: timelocks,
            parameters: ""
        });
        
        // Create destination complement
        IEscrowFactory.DstImmutablesComplement memory dstComplement = _createDstComplement();
        
        // Deploy source escrow
        vm.prank(maker);
        address srcEscrow = factory.createSrcEscrow(immutables, dstComplement);
        
        // Verify the FACTORY immutable in the deployed escrow
        EscrowSrc escrowContract = EscrowSrc(payable(srcEscrow));
        address escrowFactory = address(escrowContract.FACTORY());
        
        assertEq(escrowFactory, address(factory), "FACTORY immutable should point to SimplifiedEscrowFactoryV4");
        assertNotEq(escrowFactory, address(0), "FACTORY should not be zero address");
        
        // Also test destination escrow
        vm.prank(resolver);
        address dstEscrow = factory.createDstEscrow{value: SAFETY_DEPOSIT}(immutables);
        
        EscrowDst dstEscrowContract = EscrowDst(payable(dstEscrow));
        address dstEscrowFactory = address(dstEscrowContract.FACTORY());
        
        assertEq(dstEscrowFactory, address(factory), "Destination escrow FACTORY should also point to SimplifiedEscrowFactoryV4");
    }
    
    /**
     * @notice Test that only limitOrderProtocol can call postInteraction
     * @dev Verifies access control on the internal _postInteraction method
     */
    function testOnlyLimitOrderProtocolCanCall() public {
        // Build order
        IOrderMixin.Order memory order = _createTestOrder();
        
        // Encode extra data for postInteraction
        bytes memory extraData = abi.encode(
            hashlock,
            block.chainid + 1, // Different chain ID for destination
            address(tokenB),
            (uint256(SAFETY_DEPOSIT) << 128) | SAFETY_DEPOSIT, // Packed deposits
            (uint256(block.timestamp + 2 hours) << 128) | (block.timestamp + 1 hours) // Packed timelocks
        );
        
        // The postInteraction method is internal and can only be called through the limitOrderProtocol
        // Try to call it from an unauthorized contract (would fail if we could call it directly)
        // Since postInteraction is internal, we test that it works when called through the protocol
        
        // Execute through the legitimate protocol
        vm.prank(resolver);
        limitOrderProtocol.fillOrderWithPostInteraction(
            order,
            "", // signature
            SWAP_AMOUNT,
            0, // takerTraits
            address(factory),
            extraData
        );
        
        // Verify escrow was created (proves postInteraction was called)
        address escrowAddress = factory.escrows(hashlock);
        assertNotEq(escrowAddress, address(0), "Escrow should be created through limitOrderProtocol");
        
        // Now try to call postInteraction directly (can't because it's public inherited method that checks caller)
        vm.prank(unauthorizedUser);
        vm.expectRevert(abi.encodeWithSignature("OnlyLimitOrderProtocol()"));
        factory.postInteraction(order, "", keccak256("test"), unauthorizedUser, 0, 0, 0, extraData);
    }
    
    /**
     * @notice Test end-to-end escrow creation via _postInteraction
     * @dev Verifies the complete flow from order fill to escrow deployment
     */
    function testEscrowCreation() public {
        // Build order
        IOrderMixin.Order memory order = _createTestOrder();
        
        // Encode extra data with proper parameters
        bytes memory extraData = abi.encode(
            hashlock,
            block.chainid + 1,
            address(tokenB),
            (uint256(SAFETY_DEPOSIT) << 128) | SAFETY_DEPOSIT,
            (uint256(block.timestamp + 2 hours) << 128) | (block.timestamp + 1 hours)
        );
        
        // We won't check the exact address in the event since it's deterministic but complex to predict
        // Just verify the escrow gets created correctly
        
        // Execute order with postInteraction
        vm.prank(resolver);
        limitOrderProtocol.fillOrderWithPostInteraction(
            order,
            "",
            SWAP_AMOUNT,
            0,
            address(factory),
            extraData
        );
        
        // Verify escrow was created
        address escrowAddress = factory.escrows(hashlock);
        assertNotEq(escrowAddress, address(0), "Escrow should be created");
        
        // Verify escrow received tokens
        uint256 escrowBalance = tokenA.balanceOf(escrowAddress);
        assertEq(escrowBalance, SWAP_AMOUNT, "Escrow should have received tokens");
        
        // Verify escrow was created and has correct balance
        // Note: escrowImmutables returns a struct but we can't directly retrieve it in tests
        // The important part is that the escrow was created and received tokens
    }
    
    /**
     * @notice Test that timelocks are packed correctly using the new pack() function
     * @dev Verifies the V4.0 fix for proper timelock packing
     */
    function testTimelockPacking() public {
        // Create timelocks struct
        TimelocksLib.TimelocksStruct memory timelocksStruct = TimelocksLib.TimelocksStruct({
            srcWithdrawal: 0,
            srcPublicWithdrawal: 60,
            srcCancellation: 3600,
            srcPublicCancellation: 3660,
            dstWithdrawal: 1800,
            dstPublicWithdrawal: 1860,
            dstCancellation: 3600
        });
        
        // Pack using the new pack() function
        Timelocks packed = TimelocksLib.pack(timelocksStruct);
        
        // Set deployment timestamp
        uint256 deployedAt = block.timestamp;
        packed = packed.setDeployedAt(deployedAt);
        
        // Verify packing is correct using the get() function
        assertEq(TimelocksLib.get(packed, TimelocksLib.Stage.SrcWithdrawal), deployedAt, "srcWithdrawal should start at deployment");
        assertEq(TimelocksLib.get(packed, TimelocksLib.Stage.SrcPublicWithdrawal), deployedAt + 60, "srcPublicWithdrawal should be offset");
        assertEq(TimelocksLib.get(packed, TimelocksLib.Stage.SrcCancellation), deployedAt + 3600, "srcCancellation should be offset");
        assertEq(TimelocksLib.get(packed, TimelocksLib.Stage.SrcPublicCancellation), deployedAt + 3660, "srcPublicCancellation should be offset");
        assertEq(TimelocksLib.get(packed, TimelocksLib.Stage.DstWithdrawal), deployedAt + 1800, "dstWithdrawal should be offset");
        assertEq(TimelocksLib.get(packed, TimelocksLib.Stage.DstPublicWithdrawal), deployedAt + 1860, "dstPublicWithdrawal should be offset");
        assertEq(TimelocksLib.get(packed, TimelocksLib.Stage.DstCancellation), deployedAt + 3600, "dstCancellation should be offset");
        
        // Test that the pack function is used in postInteraction flow
        IOrderMixin.Order memory order = _createTestOrder();
        
        bytes memory extraData = abi.encode(
            hashlock,
            block.chainid + 1,
            address(tokenB),
            (uint256(SAFETY_DEPOSIT) << 128) | SAFETY_DEPOSIT,
            (uint256(block.timestamp + 2 hours) << 128) | (block.timestamp + 1 hours)
        );
        
        vm.prank(resolver);
        limitOrderProtocol.fillOrderWithPostInteraction(
            order,
            "",
            SWAP_AMOUNT,
            0,
            address(factory),
            extraData
        );
        
        // The escrow should be created with properly packed timelocks
        address escrowAddress = factory.escrows(hashlock);
        assertNotEq(escrowAddress, address(0), "Escrow should be created with packed timelocks");
    }
    
    /**
     * @notice Test that parameters are properly encoded for 1inch compatibility
     * @dev Verifies empty parameters for source, fee structure for destination
     */
    function testParametersEncoding() public {
        // Test source escrow creation with empty parameters
        Timelocks timelocks = _createTestTimelocks();
        IBaseEscrow.Immutables memory srcImmutables = IBaseEscrow.Immutables({
            orderHash: keccak256("test_order"),
            hashlock: hashlock,
            maker: Address.wrap(uint160(maker)),
            taker: Address.wrap(uint160(resolver)),
            token: Address.wrap(uint160(address(tokenA))),
            amount: SWAP_AMOUNT,
            safetyDeposit: SAFETY_DEPOSIT,
            timelocks: timelocks,
            parameters: "" // Empty for source (BMN compatibility)
        });
        
        // Test destination complement with encoded fee structure
        bytes memory dstParameters = abi.encode(
            uint256(0), // protocolFeeAmount
            uint256(0), // integratorFeeAmount
            Address.wrap(0), // protocolFeeRecipient
            Address.wrap(0)  // integratorFeeRecipient
        );
        
        IEscrowFactory.DstImmutablesComplement memory dstComplement = IEscrowFactory.DstImmutablesComplement({
            maker: Address.wrap(uint160(maker)),
            amount: SWAP_AMOUNT,
            token: Address.wrap(uint160(address(tokenB))),
            safetyDeposit: SAFETY_DEPOSIT,
            chainId: block.chainid + 1,
            parameters: dstParameters
        });
        
        // Verify parameters are encoded correctly
        assertEq(srcImmutables.parameters.length, 0, "Source parameters should be empty");
        assertEq(dstComplement.parameters.length, 128, "Destination parameters should be encoded fee structure");
        
        // Decode and verify destination parameters
        (
            uint256 protocolFee,
            uint256 integratorFee,
            Address protocolRecipient,
            Address integratorRecipient
        ) = abi.decode(dstComplement.parameters, (uint256, uint256, Address, Address));
        
        assertEq(protocolFee, 0, "Protocol fee should be zero");
        assertEq(integratorFee, 0, "Integrator fee should be zero");
        assertEq(protocolRecipient.get(), address(0), "Protocol recipient should be zero");
        assertEq(integratorRecipient.get(), address(0), "Integrator recipient should be zero");
        
        // Test in actual escrow creation
        vm.prank(maker);
        address srcEscrow = factory.createSrcEscrow(srcImmutables, dstComplement);
        assertNotEq(srcEscrow, address(0), "Escrow should be created with proper parameters");
    }
    
    /**
     * @notice Test duplicate escrow prevention
     * @dev Verifies that the same hashlock cannot create multiple escrows
     */
    function testDuplicateEscrowPrevention() public {
        IOrderMixin.Order memory order = _createTestOrder();
        
        bytes memory extraData = abi.encode(
            hashlock,
            block.chainid + 1,
            address(tokenB),
            (uint256(SAFETY_DEPOSIT) << 128) | SAFETY_DEPOSIT,
            (uint256(block.timestamp + 2 hours) << 128) | (block.timestamp + 1 hours)
        );
        
        // First creation should succeed
        vm.prank(resolver);
        limitOrderProtocol.fillOrderWithPostInteraction(
            order,
            "",
            SWAP_AMOUNT,
            0,
            address(factory),
            extraData
        );
        
        // Mint more tokens for second attempt
        tokenA.mint(maker, SWAP_AMOUNT);
        vm.prank(maker);
        tokenA.approve(address(limitOrderProtocol), SWAP_AMOUNT);
        
        tokenA.mint(resolver, SWAP_AMOUNT);
        vm.prank(resolver);
        tokenA.approve(address(factory), SWAP_AMOUNT);
        
        // Second creation with same hashlock should fail
        vm.prank(resolver);
        vm.expectRevert("Escrow already exists");
        limitOrderProtocol.fillOrderWithPostInteraction(
            order,
            "",
            SWAP_AMOUNT,
            0,
            address(factory),
            extraData
        );
    }
    
    /**
     * @notice Test resolver whitelist functionality
     * @dev Verifies that only whitelisted resolvers can create destination escrows
     */
    function testResolverWhitelist() public {
        // Disable whitelist bypass
        vm.prank(deployer);
        factory.setWhitelistBypassed(false);
        
        // Unauthorized user should fail
        Timelocks timelocks = _createTestTimelocks();
        IBaseEscrow.Immutables memory immutables = IBaseEscrow.Immutables({
            orderHash: keccak256("test_order"),
            hashlock: hashlock,
            maker: Address.wrap(uint160(maker)),
            taker: Address.wrap(uint160(unauthorizedUser)),
            token: Address.wrap(uint160(address(tokenA))),
            amount: SWAP_AMOUNT,
            safetyDeposit: SAFETY_DEPOSIT,
            timelocks: timelocks,
            parameters: ""
        });
        
        vm.prank(unauthorizedUser);
        vm.expectRevert("Not whitelisted resolver");
        factory.createDstEscrow{value: SAFETY_DEPOSIT}(immutables);
        
        // Add to whitelist
        vm.prank(deployer);
        factory.addResolver(unauthorizedUser);
        
        // Now should succeed
        vm.prank(unauthorizedUser);
        tokenA.approve(address(factory), SWAP_AMOUNT);
        tokenA.mint(unauthorizedUser, SWAP_AMOUNT);
        
        vm.prank(unauthorizedUser);
        address escrow = factory.createDstEscrow{value: SAFETY_DEPOSIT}(immutables);
        assertNotEq(escrow, address(0), "Whitelisted resolver should create escrow");
    }
    
    /**
     * @notice Test emergency pause functionality
     * @dev Verifies that paused factory cannot create escrows
     */
    function testEmergencyPause() public {
        // Pause the factory
        vm.prank(deployer);
        factory.pause();
        
        assertTrue(factory.emergencyPaused(), "Factory should be paused");
        
        // Try to create escrow (should fail)
        Timelocks timelocks = _createTestTimelocks();
        IBaseEscrow.Immutables memory immutables = IBaseEscrow.Immutables({
            orderHash: keccak256("test_order"),
            hashlock: hashlock,
            maker: Address.wrap(uint160(maker)),
            taker: Address.wrap(uint160(resolver)),
            token: Address.wrap(uint160(address(tokenA))),
            amount: SWAP_AMOUNT,
            safetyDeposit: SAFETY_DEPOSIT,
            timelocks: timelocks,
            parameters: ""
        });
        
        IEscrowFactory.DstImmutablesComplement memory dstComplement = _createDstComplement();
        
        vm.prank(maker);
        vm.expectRevert("Protocol paused");
        factory.createSrcEscrow(immutables, dstComplement);
        
        // Unpause
        vm.prank(deployer);
        factory.unpause();
        
        assertFalse(factory.emergencyPaused(), "Factory should be unpaused");
        
        // Now should succeed
        vm.prank(maker);
        address escrow = factory.createSrcEscrow(immutables, dstComplement);
        assertNotEq(escrow, address(0), "Should create escrow when unpaused");
    }
    
    /**
     * @notice Test deterministic address calculation
     * @dev Verifies that escrow addresses can be predicted before deployment
     */
    function testDeterministicAddresses() public {
        Timelocks timelocks = _createTestTimelocks();
        IBaseEscrow.Immutables memory immutables = IBaseEscrow.Immutables({
            orderHash: keccak256("test_order"),
            hashlock: hashlock,
            maker: Address.wrap(uint160(maker)),
            taker: Address.wrap(uint160(resolver)),
            token: Address.wrap(uint160(address(tokenA))),
            amount: SWAP_AMOUNT,
            safetyDeposit: SAFETY_DEPOSIT,
            timelocks: timelocks,
            parameters: ""
        });
        
        // Predict address
        address predicted = factory.addressOfEscrow(immutables, true);
        
        // Deploy escrow
        IEscrowFactory.DstImmutablesComplement memory dstComplement = _createDstComplement();
        vm.prank(maker);
        address actual = factory.createSrcEscrow(immutables, dstComplement);
        
        // Verify prediction was correct
        assertEq(actual, predicted, "Predicted address should match actual");
    }
    
    // Helper functions
    
    function _createTestTimelocks() internal view returns (Timelocks) {
        TimelocksLib.TimelocksStruct memory timelocksStruct = TimelocksLib.TimelocksStruct({
            srcWithdrawal: 0,
            srcPublicWithdrawal: 60,
            srcCancellation: 3600,
            srcPublicCancellation: 3660,
            dstWithdrawal: 1800,
            dstPublicWithdrawal: 1860,
            dstCancellation: 3600
        });
        
        Timelocks packed = TimelocksLib.pack(timelocksStruct);
        return packed.setDeployedAt(block.timestamp);
    }
    
    function _createTestOrder() internal view returns (IOrderMixin.Order memory) {
        return IOrderMixin.Order({
            salt: uint256(keccak256("test_salt")),
            maker: Address.wrap(uint160(maker)),
            receiver: Address.wrap(0),
            makerAsset: Address.wrap(uint160(address(tokenA))),
            takerAsset: Address.wrap(uint160(address(tokenB))),
            makingAmount: SWAP_AMOUNT,
            takingAmount: SWAP_AMOUNT,
            makerTraits: MakerTraits.wrap(0)
        });
    }
    
    function _createDstComplement() internal view returns (IEscrowFactory.DstImmutablesComplement memory) {
        bytes memory dstParameters = abi.encode(
            uint256(0),
            uint256(0),
            Address.wrap(0),
            Address.wrap(0)
        );
        
        return IEscrowFactory.DstImmutablesComplement({
            maker: Address.wrap(uint160(maker)),
            amount: SWAP_AMOUNT,
            token: Address.wrap(uint160(address(tokenB))),
            safetyDeposit: SAFETY_DEPOSIT,
            chainId: block.chainid + 1,
            parameters: dstParameters
        });
    }
}