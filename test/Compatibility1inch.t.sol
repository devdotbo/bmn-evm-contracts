// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Test.sol";
import "../contracts/SimplifiedEscrowFactory.sol";
import "../contracts/interfaces/IBaseEscrow.sol";
import "../contracts/interfaces/IEscrowFactory.sol";
import "../contracts/libraries/ImmutablesLib.sol";
import "../contracts/libraries/TimelocksLib.sol";
import "../test/mocks/MockLimitOrderProtocol.sol";
import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import { Address, AddressLib } from "solidity-utils/contracts/libraries/AddressLib.sol";

contract MockToken is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        _mint(msg.sender, 1000000 * 10**18);
    }
    
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract MockEscrowSrc {
    address public immutable FACTORY;
    uint256 public immutable RESCUE_DELAY;
    
    constructor(address factory, uint256 rescueDelay) {
        FACTORY = factory;
        RESCUE_DELAY = rescueDelay;
    }
}

contract MockEscrowDst {
    address public immutable FACTORY;
    uint256 public immutable RESCUE_DELAY;
    
    constructor(address factory, uint256 rescueDelay) {
        FACTORY = factory;
        RESCUE_DELAY = rescueDelay;
    }
}

contract Compatibility1inchTest is Test {
    using ImmutablesLib for IBaseEscrow.Immutables;
    using TimelocksLib for Timelocks;
    using AddressLib for Address;
    
    SimplifiedEscrowFactory factory;
    MockToken tokenA;
    MockToken tokenB;
    MockLimitOrderProtocol limitOrderProtocol;
    
    address constant ALICE = address(0x1);
    address constant BOB = address(0x2);
    address constant OWNER = address(0x3);
    
    function setUp() public {
        // Deploy mock tokens
        tokenA = new MockToken("Token A", "TKA");
        tokenB = new MockToken("Token B", "TKB");
        
        // Deploy mock escrow implementations
        MockEscrowSrc srcImpl = new MockEscrowSrc(address(this), 7 days);
        MockEscrowDst dstImpl = new MockEscrowDst(address(this), 7 days);
        
        // Deploy factory
        factory = new SimplifiedEscrowFactory(
            address(srcImpl),
            address(dstImpl),
            OWNER
        );
        
        // Deploy mock limit order protocol
        limitOrderProtocol = new MockLimitOrderProtocol();
        
        // Setup tokens
        tokenA.transfer(ALICE, 1000 * 10**18);
        tokenB.transfer(BOB, 1000 * 10**18);
        
        // Approve factory
        vm.prank(ALICE);
        tokenA.approve(address(factory), type(uint256).max);
        vm.prank(BOB);
        tokenB.approve(address(factory), type(uint256).max);
    }
    
    // Test 1: ImmutablesLib handles dynamic bytes field correctly
    function testImmutablesLibWithParameters() public {
        // Create immutables with empty parameters
        IBaseEscrow.Immutables memory immutables1 = IBaseEscrow.Immutables({
            orderHash: bytes32(uint256(1)),
            hashlock: keccak256(abi.encode("secret")),
            maker: Address.wrap(uint160(ALICE)),
            taker: Address.wrap(uint160(BOB)),
            token: Address.wrap(uint160(address(tokenA))),
            amount: 100 * 10**18,
            safetyDeposit: 1 * 10**18,
            timelocks: Timelocks.wrap(uint256(0x0102030405060708)),
            parameters: ""
        });
        
        // Create immutables with non-empty parameters
        IBaseEscrow.Immutables memory immutables2 = IBaseEscrow.Immutables({
            orderHash: bytes32(uint256(1)),
            hashlock: keccak256(abi.encode("secret")),
            maker: Address.wrap(uint160(ALICE)),
            taker: Address.wrap(uint160(BOB)),
            token: Address.wrap(uint160(address(tokenA))),
            amount: 100 * 10**18,
            safetyDeposit: 1 * 10**18,
            timelocks: Timelocks.wrap(uint256(0x0102030405060708)),
            parameters: abi.encode("fee_data")
        });
        
        // Test that different parameters produce different hashes
        bytes32 hash1 = ImmutablesLib.hashMem(immutables1);
        bytes32 hash2 = ImmutablesLib.hashMem(immutables2);
        assertNotEq(hash1, hash2, "Different parameters should produce different hashes");
        
        // Test that same immutables produce same hash
        bytes32 hash1Again = ImmutablesLib.hashMem(immutables1);
        assertEq(hash1, hash1Again, "Same immutables should produce same hash");
    }
    
    // Test 2: Event emissions include complete immutables
    function testEventEmissionsWithCompleteImmutables() public {
        vm.startPrank(ALICE);
        
        // Prepare immutables
        IBaseEscrow.Immutables memory srcImmutables = IBaseEscrow.Immutables({
            orderHash: bytes32(uint256(1)),
            hashlock: keccak256(abi.encode("secret")),
            maker: Address.wrap(uint160(ALICE)),
            taker: Address.wrap(uint160(BOB)),
            token: Address.wrap(uint160(address(tokenA))),
            amount: 100 * 10**18,
            safetyDeposit: 1 * 10**18,
            timelocks: Timelocks.wrap(uint256(0x0102030405060708)),
            parameters: ""
        });
        
        IEscrowFactory.DstImmutablesComplement memory dstComplement = IEscrowFactory.DstImmutablesComplement({
            maker: Address.wrap(uint160(ALICE)),
            amount: 50 * 10**18,
            token: Address.wrap(uint160(address(tokenB))),
            safetyDeposit: 0.5 * 10**18,
            chainId: 42161, // Arbitrum
            parameters: ""
        });
        
        // Start recording events
        vm.recordLogs();
        
        // Create source escrow
        factory.createSrcEscrow(srcImmutables, dstComplement);
        
        // Get recorded events
        Vm.Log[] memory logs = vm.getRecordedLogs();
        
        // Find SrcEscrowCreated event
        bool foundEvent = false;
        for (uint i = 0; i < logs.length; i++) {
            // Event signature for SrcEscrowCreated - no indexed parameters, so only topic[0]
            if (logs[i].topics.length == 1 && logs[i].emitter == address(factory)) {
                foundEvent = true;
                
                // Decode event data
                (IBaseEscrow.Immutables memory emittedSrcImmutables, IEscrowFactory.DstImmutablesComplement memory emittedDstComplement) = 
                    abi.decode(logs[i].data, (IBaseEscrow.Immutables, IEscrowFactory.DstImmutablesComplement));
                
                // Verify srcImmutables match
                assertEq(emittedSrcImmutables.orderHash, srcImmutables.orderHash, "orderHash mismatch");
                assertEq(emittedSrcImmutables.hashlock, srcImmutables.hashlock, "hashlock mismatch");
                assertEq(emittedSrcImmutables.maker.get(), srcImmutables.maker.get(), "maker mismatch");
                assertEq(emittedSrcImmutables.taker.get(), srcImmutables.taker.get(), "taker mismatch");
                assertEq(emittedSrcImmutables.token.get(), srcImmutables.token.get(), "token mismatch");
                assertEq(emittedSrcImmutables.amount, srcImmutables.amount, "amount mismatch");
                assertEq(emittedSrcImmutables.safetyDeposit, srcImmutables.safetyDeposit, "safetyDeposit mismatch");
                assertEq(Timelocks.unwrap(emittedSrcImmutables.timelocks), Timelocks.unwrap(srcImmutables.timelocks), "timelocks mismatch");
                assertEq(emittedSrcImmutables.parameters, srcImmutables.parameters, "parameters mismatch");
                
                // Verify dstComplement matches
                assertEq(emittedDstComplement.maker.get(), dstComplement.maker.get(), "dst maker mismatch");
                assertEq(emittedDstComplement.amount, dstComplement.amount, "dst amount mismatch");
                assertEq(emittedDstComplement.token.get(), dstComplement.token.get(), "dst token mismatch");
                assertEq(emittedDstComplement.safetyDeposit, dstComplement.safetyDeposit, "dst safetyDeposit mismatch");
                assertEq(emittedDstComplement.chainId, dstComplement.chainId, "dst chainId mismatch");
                assertEq(emittedDstComplement.parameters, dstComplement.parameters, "dst parameters mismatch");
                
                break;
            }
        }
        
        assertTrue(foundEvent, "SrcEscrowCreated event not found");
        
        vm.stopPrank();
    }
    
    // Test 3: Immutables storage and retrieval
    function testImmutablesStorageAndRetrieval() public {
        vm.startPrank(ALICE);
        
        // Prepare immutables
        IBaseEscrow.Immutables memory srcImmutables = IBaseEscrow.Immutables({
            orderHash: bytes32(uint256(1)),
            hashlock: keccak256(abi.encode("secret")),
            maker: Address.wrap(uint160(ALICE)),
            taker: Address.wrap(uint160(BOB)),
            token: Address.wrap(uint160(address(tokenA))),
            amount: 100 * 10**18,
            safetyDeposit: 1 * 10**18,
            timelocks: Timelocks.wrap(uint256(0x0102030405060708)),
            parameters: ""
        });
        
        IEscrowFactory.DstImmutablesComplement memory dstComplement = IEscrowFactory.DstImmutablesComplement({
            maker: Address.wrap(uint160(ALICE)),
            amount: 50 * 10**18,
            token: Address.wrap(uint160(address(tokenB))),
            safetyDeposit: 0.5 * 10**18,
            chainId: 42161,
            parameters: ""
        });
        
        // Create source escrow
        factory.createSrcEscrow(srcImmutables, dstComplement);
        
        // Calculate salt
        bytes32 salt = ImmutablesLib.hashMem(srcImmutables);
        
        // Retrieve stored immutables
        (
            bytes32 storedOrderHash,
            bytes32 storedHashlock,
            Address storedMaker,
            Address storedTaker,
            Address storedToken,
            uint256 storedAmount,
            uint256 storedSafetyDeposit,
            Timelocks storedTimelocks,
            bytes memory storedParameters
        ) = factory.escrowImmutables(salt);
        
        // Verify all fields match
        assertEq(storedOrderHash, srcImmutables.orderHash, "Stored orderHash mismatch");
        assertEq(storedHashlock, srcImmutables.hashlock, "Stored hashlock mismatch");
        assertEq(storedMaker.get(), srcImmutables.maker.get(), "Stored maker mismatch");
        assertEq(storedTaker.get(), srcImmutables.taker.get(), "Stored taker mismatch");
        assertEq(storedToken.get(), srcImmutables.token.get(), "Stored token mismatch");
        assertEq(storedAmount, srcImmutables.amount, "Stored amount mismatch");
        assertEq(storedSafetyDeposit, srcImmutables.safetyDeposit, "Stored safetyDeposit mismatch");
        assertEq(Timelocks.unwrap(storedTimelocks), Timelocks.unwrap(srcImmutables.timelocks), "Stored timelocks mismatch");
        assertEq(storedParameters, srcImmutables.parameters, "Stored parameters mismatch");
        
        vm.stopPrank();
    }
    
    // Test 4: Deterministic addresses with parameters field
    function testDeterministicAddressesWithParameters() public {
        // Create two identical immutables except for parameters field
        IBaseEscrow.Immutables memory immutables1 = IBaseEscrow.Immutables({
            orderHash: bytes32(uint256(1)),
            hashlock: keccak256(abi.encode("secret")),
            maker: Address.wrap(uint160(ALICE)),
            taker: Address.wrap(uint160(BOB)),
            token: Address.wrap(uint160(address(tokenA))),
            amount: 100 * 10**18,
            safetyDeposit: 1 * 10**18,
            timelocks: Timelocks.wrap(uint256(0x0102030405060708)),
            parameters: ""
        });
        
        IBaseEscrow.Immutables memory immutables2 = IBaseEscrow.Immutables({
            orderHash: bytes32(uint256(1)),
            hashlock: keccak256(abi.encode("secret")),
            maker: Address.wrap(uint160(ALICE)),
            taker: Address.wrap(uint160(BOB)),
            token: Address.wrap(uint160(address(tokenA))),
            amount: 100 * 10**18,
            safetyDeposit: 1 * 10**18,
            timelocks: Timelocks.wrap(uint256(0x0102030405060708)),
            parameters: abi.encode("different")
        });
        
        // Get predicted addresses
        address addr1 = factory.addressOfEscrow(immutables1, true);
        address addr2 = factory.addressOfEscrow(immutables2, true);
        
        // Addresses should be different due to different parameters
        assertNotEq(addr1, addr2, "Different parameters should produce different addresses");
        
        // Test that same immutables produce same address
        address addr1Again = factory.addressOfEscrow(immutables1, true);
        assertEq(addr1, addr1Again, "Same immutables should produce same address");
        
        // Deploy and verify address matches prediction
        vm.startPrank(ALICE);
        
        IEscrowFactory.DstImmutablesComplement memory dstComplement = IEscrowFactory.DstImmutablesComplement({
            maker: Address.wrap(uint160(ALICE)),
            amount: 50 * 10**18,
            token: Address.wrap(uint160(address(tokenB))),
            safetyDeposit: 0.5 * 10**18,
            chainId: 42161,
            parameters: ""
        });
        
        address deployedEscrow = factory.createSrcEscrow(immutables1, dstComplement);
        assertEq(deployedEscrow, addr1, "Deployed address should match prediction");
        
        vm.stopPrank();
    }
    
    // Test 5: PostInteraction with 1inch compatibility
    function testPostInteractionWithCompleteImmutables() public {
        // Setup resolver
        vm.prank(BOB);
        tokenA.approve(address(factory), type(uint256).max);
        
        // Create order
        IOrderMixin.Order memory order;
        order.maker = Address.wrap(uint160(ALICE));
        order.receiver = Address.wrap(uint160(ALICE));
        order.makerAsset = Address.wrap(uint160(address(tokenA)));
        order.takerAsset = Address.wrap(uint160(address(tokenB)));
        order.makingAmount = 100 * 10**18;
        order.takingAmount = 50 * 10**18;
        
        bytes32 orderHash = keccak256(abi.encode(order));
        bytes32 hashlock = keccak256(abi.encode("secret"));
        
        // Prepare extraData
        bytes memory extraData = abi.encode(
            hashlock,
            42161, // dstChainId
            address(tokenB), // dstToken
            uint256(1 * 10**18) << 128 | uint256(0.5 * 10**18), // deposits
            uint256(block.timestamp + 7200) << 128 | uint256(block.timestamp + 3600) // timelocks
        );
        
        // Transfer tokens to resolver (simulating limit order fill)
        vm.prank(ALICE);
        tokenA.transfer(BOB, 100 * 10**18);
        
        // Start recording events
        vm.recordLogs();
        
        // Call postInteraction from limit order protocol
        vm.prank(address(limitOrderProtocol));
        factory.postInteraction(
            order,
            "",
            orderHash,
            BOB,
            100 * 10**18,
            50 * 10**18,
            0,
            extraData
        );
        
        // Get recorded events
        Vm.Log[] memory logs = vm.getRecordedLogs();
        
        // Find and verify SrcEscrowCreated event
        bool foundEvent = false;
        for (uint i = 0; i < logs.length; i++) {
            // Event signature for SrcEscrowCreated - no indexed parameters, so only topic[0]
            if (logs[i].topics.length == 1 && logs[i].emitter == address(factory)) {
                foundEvent = true;
                
                // Decode event data
                (IBaseEscrow.Immutables memory emittedSrcImmutables, IEscrowFactory.DstImmutablesComplement memory emittedDstComplement) = 
                    abi.decode(logs[i].data, (IBaseEscrow.Immutables, IEscrowFactory.DstImmutablesComplement));
                
                // Verify parameters field is included and empty
                assertEq(emittedSrcImmutables.parameters, "", "src parameters should be empty");
                assertEq(emittedDstComplement.parameters, "", "dst parameters should be empty");
                
                // Verify other fields
                assertEq(emittedSrcImmutables.orderHash, orderHash, "orderHash mismatch");
                assertEq(emittedSrcImmutables.hashlock, hashlock, "hashlock mismatch");
                assertEq(emittedSrcImmutables.maker.get(), ALICE, "maker mismatch");
                assertEq(emittedSrcImmutables.taker.get(), BOB, "taker mismatch");
                assertEq(emittedSrcImmutables.amount, 100 * 10**18, "amount mismatch");
                
                break;
            }
        }
        
        assertTrue(foundEvent, "SrcEscrowCreated event not found");
        
        // Verify immutables are stored
        bytes32 salt = keccak256(abi.encode(
            orderHash,
            hashlock,
            Address.wrap(uint160(ALICE)),
            Address.wrap(uint160(BOB)),
            Address.wrap(uint160(address(tokenA))),
            uint256(100 * 10**18),
            uint256(0.5 * 10**18),
            logs[0].data, // This would need proper extraction of timelocks
            ""
        ));
        
        // Check that escrow was created with hashlock key
        address escrowAddress = factory.escrows(hashlock);
        assertTrue(escrowAddress != address(0), "Escrow should be created");
    }
}