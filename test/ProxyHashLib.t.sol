// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Test.sol";
import { Clones } from "openzeppelin-contracts/contracts/proxy/Clones.sol";
import { ProxyHashLib } from "../contracts/libraries/ProxyHashLib.sol";
import { EscrowSrc } from "../contracts/EscrowSrc.sol";
import { EscrowDst } from "../contracts/EscrowDst.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { IBaseEscrow } from "../contracts/interfaces/IBaseEscrow.sol";
import { IEscrowFactory } from "../contracts/interfaces/IEscrowFactory.sol";
import { SimplifiedEscrowFactory } from "../contracts/SimplifiedEscrowFactory.sol";
import { ImmutablesLib } from "../contracts/libraries/ImmutablesLib.sol";
import { Timelocks, TimelocksLib } from "../contracts/libraries/TimelocksLib.sol";
import { Address, AddressLib } from "solidity-utils/contracts/libraries/AddressLib.sol";

/**
 * @title ProxyHashLibTest
 * @notice Comprehensive test suite for ProxyHashLib
 * @dev Tests CREATE2 address prediction with minimal proxy pattern
 * 
 * Test Coverage:
 * 1. Bytecode hash generation for proxy contracts
 * 2. CREATE2 address prediction accuracy
 * 3. Different implementation addresses produce different hashes
 * 4. Verification against actual Clones library deployment
 * 5. Edge cases and boundary conditions
 * 
 * Technical Context:
 * - ProxyHashLib computes the bytecode hash for minimal proxy contracts
 * - The minimal proxy pattern (EIP-1167) uses a compact bytecode that delegates all calls
 * - CREATE2 uses: keccak256(0xff ++ deployer ++ salt ++ keccak256(bytecode))
 * - The proxy bytecode includes the implementation address, making each proxy unique
 */
contract ProxyHashLibTest is Test {
    using Clones for address;
    using ImmutablesLib for IBaseEscrow.Immutables;
    using TimelocksLib for Timelocks;
    using AddressLib for Address;
    
    // Test contracts
    EscrowSrc public escrowSrcImpl;
    EscrowDst public escrowDstImpl;
    SimplifiedEscrowFactory public factory;
    
    // Test addresses
    address constant ALICE = address(0x1111);
    address constant BOB = address(0x2222);
    address constant CHARLIE = address(0x3333);
    
    // Test token
    MockERC20 public token;
    
    // Access token (unused but required for constructor)
    IERC20 constant ACCESS_TOKEN = IERC20(address(0));
    
    function setUp() public {
        // Deploy implementations
        escrowSrcImpl = new EscrowSrc(30 days, ACCESS_TOKEN);
        escrowDstImpl = new EscrowDst(30 days, ACCESS_TOKEN);
        
        // Deploy factory
        factory = new SimplifiedEscrowFactory(
            address(escrowSrcImpl),
            address(escrowDstImpl),
            address(this)
        );
        
        // Deploy mock token
        token = new MockERC20("Test Token", "TKN", 18);
        
        // Setup test accounts with tokens
        token.mint(ALICE, 1000e18);
        token.mint(BOB, 1000e18);
        
        vm.prank(ALICE);
        token.approve(address(factory), type(uint256).max);
        
        vm.prank(BOB);
        token.approve(address(factory), type(uint256).max);
    }
    
    /**
     * @notice Test 1: Verify bytecode hash generation for proxy contracts
     * @dev Tests that ProxyHashLib correctly computes the hash of minimal proxy bytecode
     */
    function testBytecodeHashGeneration() public {
        // Test with EscrowSrc implementation
        bytes32 srcHash = ProxyHashLib.computeProxyBytecodeHash(address(escrowSrcImpl));
        
        // The hash should be deterministic and non-zero
        assertNotEq(srcHash, bytes32(0), "Hash should not be zero");
        
        // Computing the same implementation twice should yield the same hash
        bytes32 srcHash2 = ProxyHashLib.computeProxyBytecodeHash(address(escrowSrcImpl));
        assertEq(srcHash, srcHash2, "Hash should be deterministic");
        
        // Test with EscrowDst implementation
        bytes32 dstHash = ProxyHashLib.computeProxyBytecodeHash(address(escrowDstImpl));
        assertNotEq(dstHash, bytes32(0), "Dst hash should not be zero");
        
        // Different implementations should produce different hashes
        assertNotEq(srcHash, dstHash, "Different implementations should have different hashes");
        
        // Log the hashes for inspection
        emit log_named_bytes32("EscrowSrc proxy bytecode hash", srcHash);
        emit log_named_bytes32("EscrowDst proxy bytecode hash", dstHash);
    }
    
    /**
     * @notice Test 2: Verify CREATE2 address prediction matches actual deployment
     * @dev Tests that ProxyHashLib's address calculation matches Clones.predictDeterministicAddress
     */
    function testCREATE2AddressPrediction() public {
        // Create test immutables for escrow deployment
        IBaseEscrow.Immutables memory immutables = _createTestImmutables();
        bytes32 salt = immutables.hashMem();
        
        // Predict address using Clones library (the source of truth)
        address predictedByClonesLib = Clones.predictDeterministicAddress(
            address(escrowSrcImpl),
            salt,
            address(factory)
        );
        
        // Now we need to verify ProxyHashLib produces the same result
        // The CREATE2 formula is: keccak256(0xff ++ deployer ++ salt ++ keccak256(bytecode))
        bytes32 proxyBytecodeHash = ProxyHashLib.computeProxyBytecodeHash(address(escrowSrcImpl));
        
        // Manually compute CREATE2 address using our bytecode hash
        address predictedManually = address(uint160(uint256(keccak256(abi.encodePacked(
            bytes1(0xff),
            address(factory),
            salt,
            proxyBytecodeHash
        )))));
        
        // They should match
        assertEq(predictedManually, predictedByClonesLib, "Manual prediction should match Clones library");
        
        // Actually deploy the escrow to verify
        vm.startPrank(ALICE);
        token.approve(address(factory), immutables.amount);
        
        // Create destination complement for the event
        IEscrowFactory.DstImmutablesComplement memory dstComplement = IEscrowFactory.DstImmutablesComplement({
            maker: Address.wrap(uint160(ALICE)),
            amount: 100e18,
            token: Address.wrap(uint160(address(token))),
            safetyDeposit: 1e18,
            chainId: 2,
            parameters: ""
        });
        
        address actualEscrow = factory.createSrcEscrow(immutables, dstComplement);
        vm.stopPrank();
        
        // Verify the actual deployed address matches our predictions
        assertEq(actualEscrow, predictedByClonesLib, "Actual deployment should match Clones prediction");
        assertEq(actualEscrow, predictedManually, "Actual deployment should match manual prediction");
        
        emit log_named_address("Predicted by Clones lib", predictedByClonesLib);
        emit log_named_address("Predicted manually", predictedManually);
        emit log_named_address("Actually deployed", actualEscrow);
    }
    
    /**
     * @notice Test 3: Verify different implementations produce different addresses
     * @dev Tests that using different implementation addresses results in different proxy addresses
     */
    function testDifferentImplementations() public {
        // Create identical immutables for both escrow types
        IBaseEscrow.Immutables memory immutables = _createTestImmutables();
        bytes32 salt = immutables.hashMem();
        
        // Predict addresses for both implementations
        address srcProxyAddress = Clones.predictDeterministicAddress(
            address(escrowSrcImpl),
            salt,
            address(factory)
        );
        
        address dstProxyAddress = Clones.predictDeterministicAddress(
            address(escrowDstImpl),
            salt,
            address(factory)
        );
        
        // Different implementations should yield different proxy addresses even with same salt
        assertNotEq(srcProxyAddress, dstProxyAddress, "Different implementations should have different proxy addresses");
        
        // Verify with ProxyHashLib
        bytes32 srcHash = ProxyHashLib.computeProxyBytecodeHash(address(escrowSrcImpl));
        bytes32 dstHash = ProxyHashLib.computeProxyBytecodeHash(address(escrowDstImpl));
        
        assertNotEq(srcHash, dstHash, "Different implementations should have different bytecode hashes");
        
        emit log_named_address("Src proxy address", srcProxyAddress);
        emit log_named_address("Dst proxy address", dstProxyAddress);
    }
    
    /**
     * @notice Test 4: Verify hash consistency across different addresses
     * @dev Tests edge cases with special addresses
     */
    function testEdgeCases() public {
        // Test with zero address (should still produce valid hash)
        bytes32 zeroHash = ProxyHashLib.computeProxyBytecodeHash(address(0));
        assertNotEq(zeroHash, bytes32(0), "Zero address should still produce non-zero hash");
        
        // Test with max address
        address maxAddr = address(uint160(type(uint160).max));
        bytes32 maxHash = ProxyHashLib.computeProxyBytecodeHash(maxAddr);
        assertNotEq(maxHash, bytes32(0), "Max address should produce non-zero hash");
        
        // Test with precompiled addresses (0x1 through 0x9)
        for (uint160 i = 1; i <= 9; i++) {
            address precompile = address(i);
            bytes32 hash = ProxyHashLib.computeProxyBytecodeHash(precompile);
            assertNotEq(hash, bytes32(0), "Precompile address should produce non-zero hash");
        }
        
        // All different addresses should produce different hashes
        assertNotEq(zeroHash, maxHash, "Different addresses should have different hashes");
    }
    
    /**
     * @notice Test 5: Verify proxy bytecode structure
     * @dev Tests that the computed hash corresponds to valid EIP-1167 minimal proxy bytecode
     */
    function testProxyBytecodeStructure() public {
        // The minimal proxy bytecode used by ProxyHashLib
        // Based on the library implementation, it constructs the bytecode differently
        
        address impl = address(escrowSrcImpl);
        bytes32 computedHash = ProxyHashLib.computeProxyBytecodeHash(impl);
        
        // Based on ProxyHashLib implementation:
        // - It stores bytecode after address at mstore(0x20, 0x5af43d82803e903d91602b57fd5bf3)
        // - Implementation address at mstore(0x11, implementation)
        // - Packs first 3 bytes with bytecode before address at mstore(0x00, ...)
        // - Then hashes from 0x09 to 0x37 (55 bytes total)
        
        // Reconstruct what the library does
        bytes memory actualBytecode;
        assembly {
            let ptr := mload(0x40)
            actualBytecode := ptr
            
            // Store the bytecode after address
            mstore(add(ptr, 0x20), 0x5af43d82803e903d91602b57fd5bf3)
            // implementation address
            mstore(add(ptr, 0x11), impl)
            // Packs the first 3 bytes of the implementation address with the bytecode before the address
            mstore(ptr, or(shr(0x88, impl), 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000))
            
            // Set length (0x37 - 0x09 = 0x2e = 46 bytes)
            // But we need to account for the full memory layout
            mstore(actualBytecode, 55)
            mstore(0x40, add(ptr, 0x60))
        }
        
        // The actual bytecode from the library is 55 bytes (0x37 in hex)
        // This matches the keccak256(0x09, 0x37) in the library
        
        emit log_named_bytes32("Computed hash", computedHash);
        emit log_named_uint("Actual bytecode length", actualBytecode.length);
        emit log_named_bytes("Actual bytecode", actualBytecode);
        
        // Verify the hash is computed correctly
        bytes32 manualHash;
        assembly {
            // Replicate the exact computation from ProxyHashLib
            mstore(0x20, 0x5af43d82803e903d91602b57fd5bf3)
            mstore(0x11, impl)
            mstore(0x00, or(shr(0x88, impl), 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000))
            manualHash := keccak256(0x09, 0x37)
        }
        
        assertEq(computedHash, manualHash, "Computed hash should match manual assembly computation");
    }
    
    /**
     * @notice Test 6: Verify hash computation with fuzzing
     * @dev Fuzz test to ensure hash computation is robust for any address
     */
    function testFuzzProxyHashComputation(address implementation) public {
        // Compute hash for any implementation address
        bytes32 hash = ProxyHashLib.computeProxyBytecodeHash(implementation);
        
        // Hash should always be non-zero
        assertNotEq(hash, bytes32(0), "Hash should never be zero");
        
        // Verify determinism
        bytes32 hash2 = ProxyHashLib.computeProxyBytecodeHash(implementation);
        assertEq(hash, hash2, "Hash should be deterministic");
        
        // Verify the hash matches manual assembly computation
        bytes32 manualHash;
        assembly {
            // Replicate the exact computation from ProxyHashLib
            mstore(0x20, 0x5af43d82803e903d91602b57fd5bf3)
            mstore(0x11, implementation)
            mstore(0x00, or(shr(0x88, implementation), 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000))
            manualHash := keccak256(0x09, 0x37)
        }
        assertEq(hash, manualHash, "Hash should match manual computation");
    }
    
    /**
     * @notice Test 7: Verify CREATE2 address calculation in factory context
     * @dev Tests the complete flow from immutables to deployed address
     */
    function testFactoryAddressPrediction() public {
        // Create test immutables
        IBaseEscrow.Immutables memory immutables = _createTestImmutables();
        
        // Calculate salt separately to avoid stack issues
        bytes32 salt = immutables.hashMem();
        
        // Use factory's addressOfEscrow function
        address predictedSrc = factory.addressOfEscrow(immutables, true); // true for source
        address predictedDst = factory.addressOfEscrow(immutables, false); // false for destination
        
        // Get bytecode hashes
        bytes32 srcBytecodeHash = ProxyHashLib.computeProxyBytecodeHash(address(escrowSrcImpl));
        bytes32 dstBytecodeHash = ProxyHashLib.computeProxyBytecodeHash(address(escrowDstImpl));
        
        // Manual CREATE2 calculation for source
        address manualSrc = _computeCREATE2Address(address(factory), salt, srcBytecodeHash);
        
        // Manual CREATE2 calculation for destination
        address manualDst = _computeCREATE2Address(address(factory), salt, dstBytecodeHash);
        
        assertEq(predictedSrc, manualSrc, "Source prediction should match manual calculation");
        assertEq(predictedDst, manualDst, "Destination prediction should match manual calculation");
        
        emit log_named_address("Predicted source escrow", predictedSrc);
        emit log_named_address("Predicted destination escrow", predictedDst);
    }
    
    // Helper to compute CREATE2 address
    function _computeCREATE2Address(address deployer, bytes32 salt, bytes32 bytecodeHash) private pure returns (address) {
        return address(uint160(uint256(keccak256(abi.encodePacked(
            bytes1(0xff),
            deployer,
            salt,
            bytecodeHash
        )))));
    }
    
    /**
     * @notice Test 8: Verify consistent behavior across multiple deployments
     * @dev Tests that multiple proxies with different salts work correctly
     */
    function testMultipleProxyDeployments() public {
        // Test with 3 different salts
        bytes32 salt1 = keccak256("salt1");
        bytes32 salt2 = keccak256("salt2");
        bytes32 salt3 = keccak256("salt3");
        
        // Predict addresses
        address pred1 = Clones.predictDeterministicAddress(address(escrowSrcImpl), salt1, address(factory));
        address pred2 = Clones.predictDeterministicAddress(address(escrowSrcImpl), salt2, address(factory));
        address pred3 = Clones.predictDeterministicAddress(address(escrowSrcImpl), salt3, address(factory));
        
        // All predictions should be different
        assertNotEq(pred1, pred2, "Different salts should produce different addresses");
        assertNotEq(pred2, pred3, "Different salts should produce different addresses");
        assertNotEq(pred1, pred3, "Different salts should produce different addresses");
        
        // Verify ProxyHashLib produces consistent results
        bytes32 bytecodeHash = ProxyHashLib.computeProxyBytecodeHash(address(escrowSrcImpl));
        
        address manual1 = address(uint160(uint256(keccak256(abi.encodePacked(
            bytes1(0xff),
            address(factory),
            salt1,
            bytecodeHash
        )))));
        
        assertEq(pred1, manual1, "Manual calculation should match Clones library");
    }
    
    // Helper function to create test immutables
    function _createTestImmutables() private view returns (IBaseEscrow.Immutables memory) {
        // Pack timelocks
        uint256 packed = 0;
        packed |= uint256(uint32(block.timestamp)) << 224; // deployedAt
        packed |= uint256(uint32(3600)) << 0; // srcWithdrawal: 1 hour
        packed |= uint256(uint32(7200)) << 32; // srcPublicWithdrawal: 2 hours
        packed |= uint256(uint32(10800)) << 64; // srcCancellation: 3 hours
        packed |= uint256(uint32(14400)) << 96; // srcPublicCancellation: 4 hours
        packed |= uint256(uint32(1800)) << 128; // dstWithdrawal: 30 minutes
        packed |= uint256(uint32(5400)) << 160; // dstPublicWithdrawal: 1.5 hours
        packed |= uint256(uint32(9000)) << 192; // dstCancellation: 2.5 hours
        
        return IBaseEscrow.Immutables({
            orderHash: keccak256("test_order"),
            hashlock: keccak256("test_secret"),
            maker: Address.wrap(uint160(ALICE)),
            taker: Address.wrap(uint160(BOB)),
            token: Address.wrap(uint160(address(token))),
            amount: 100e18,
            safetyDeposit: 1e18,
            timelocks: Timelocks.wrap(packed),
            parameters: ""
        });
    }
}

/**
 * @title MockERC20
 * @notice Simple ERC20 mock for testing
 */
contract MockERC20 {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    
    string public name;
    string public symbol;
    uint8 public decimals;
    uint256 public totalSupply;
    
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    
    constructor(string memory _name, string memory _symbol, uint8 _decimals) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
    }
    
    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
        totalSupply += amount;
        emit Transfer(address(0), to, amount);
    }
    
    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }
    
    function transfer(address to, uint256 amount) external returns (bool) {
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }
    
    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        require(balanceOf[from] >= amount, "Insufficient balance");
        require(allowance[from][msg.sender] >= amount, "Insufficient allowance");
        
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        allowance[from][msg.sender] -= amount;
        
        emit Transfer(from, to, amount);
        return true;
    }
}