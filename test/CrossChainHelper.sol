// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { IOrderMixin } from "limit-order-protocol/contracts/interfaces/IOrderMixin.sol";
import { LimitOrderProtocol, IWETH } from "limit-order-protocol/contracts/LimitOrderProtocol.sol";
import { TokenMock } from "solidity-utils/contracts/mocks/TokenMock.sol";
import { Address, AddressLib } from "solidity-utils/contracts/libraries/AddressLib.sol";

import { IBaseEscrow } from "../contracts/interfaces/IBaseEscrow.sol";
import { IEscrowFactory } from "../contracts/interfaces/IEscrowFactory.sol";
import { EscrowFactory } from "../contracts/EscrowFactory.sol";
import { Timelocks, TimelocksLib } from "../contracts/libraries/TimelocksLib.sol";
import { ImmutablesLib } from "../contracts/libraries/ImmutablesLib.sol";

contract CrossChainHelper is Test {
    using AddressLib for address;
    using TimelocksLib for Timelocks;
    
    // Test constants
    uint256 constant CHAIN_A_ID = 1337;
    uint256 constant CHAIN_B_ID = 1338;
    uint256 constant DEFAULT_SAFETY_DEPOSIT = 0.01 ether;
    uint256 constant DEFAULT_RESCUE_DELAY = 7 days;
    
    // Default timelock periods (in seconds from deployment)
    uint256 constant SRC_WITHDRAWAL_START = 0;
    uint256 constant SRC_PUBLIC_WITHDRAWAL_START = 1 hours;
    uint256 constant SRC_CANCELLATION_START = 2 hours;
    uint256 constant SRC_PUBLIC_CANCELLATION_START = 3 hours;
    uint256 constant DST_WITHDRAWAL_START = 0;
    uint256 constant DST_PUBLIC_WITHDRAWAL_START = 1 hours;
    uint256 constant DST_CANCELLATION_START = 2 hours;
    
    // Test accounts
    address deployer = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address alice = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
    address bob = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;
    
    // Private keys for test accounts (Anvil defaults)
    uint256 deployerKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    uint256 aliceKey = 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d;
    uint256 bobKey = 0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a;
    
    // Contract instances
    EscrowFactory factory;
    LimitOrderProtocol lop;
    TokenMock tokenA;
    TokenMock tokenB;
    TokenMock accessToken;
    TokenMock feeToken;
    
    /**
     * @notice Sets up test environment with deployed contracts
     */
    function setupContracts() internal {
        vm.startPrank(deployer);
        
        // Deploy tokens
        tokenA = new TokenMock("Token A", "TKA");
        tokenB = new TokenMock("Token B", "TKB");
        accessToken = new TokenMock("Access Token", "ACCESS");
        feeToken = new TokenMock("Fee Token", "FEE");
        
        // Deploy Limit Order Protocol
        lop = new LimitOrderProtocol(IWETH(address(0)));
        
        // Deploy Escrow Factory
        factory = new EscrowFactory(
            address(lop),
            feeToken,
            accessToken,
            deployer,
            DEFAULT_RESCUE_DELAY,
            DEFAULT_RESCUE_DELAY
        );
        
        // Mint tokens for testing
        tokenA.mint(alice, 1000 ether);
        tokenA.mint(bob, 500 ether);
        tokenB.mint(bob, 1000 ether);
        tokenB.mint(alice, 100 ether);
        
        // Mint access tokens
        accessToken.mint(alice, 1);
        accessToken.mint(bob, 1);
        
        // Mint fee tokens
        feeToken.mint(bob, 100 ether);
        
        vm.stopPrank();
        
        // Fund accounts with ETH
        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
    }
    
    /**
     * @notice Creates a basic order for testing
     */
    function createBasicOrder(
        address maker,
        address makerAsset,
        address takerAsset,
        uint256 makingAmount,
        uint256 takingAmount,
        address receiver
    ) public pure returns (IOrderMixin.Order memory) {
        return IOrderMixin.Order({
            salt: uint256(keccak256(abi.encodePacked(maker, block.timestamp))),
            maker: maker,
            receiver: receiver,
            makerAsset: makerAsset,
            takerAsset: takerAsset,
            makingAmount: makingAmount,
            takingAmount: takingAmount,
            makerTraits: 0
        });
    }
    
    /**
     * @notice Creates default timelocks for testing
     */
    function createDefaultTimelocks() public view returns (Timelocks) {
        return createCustomTimelocks(
            SRC_WITHDRAWAL_START,
            SRC_PUBLIC_WITHDRAWAL_START,
            SRC_CANCELLATION_START,
            SRC_PUBLIC_CANCELLATION_START,
            DST_WITHDRAWAL_START,
            DST_PUBLIC_WITHDRAWAL_START,
            DST_CANCELLATION_START
        );
    }
    
    /**
     * @notice Creates custom timelocks with specified periods
     */
    function createCustomTimelocks(
        uint256 srcWithdrawal,
        uint256 srcPublicWithdrawal,
        uint256 srcCancellation,
        uint256 srcPublicCancellation,
        uint256 dstWithdrawal,
        uint256 dstPublicWithdrawal,
        uint256 dstCancellation
    ) public view returns (Timelocks) {
        // Pack timelocks according to TimelocksLib structure
        // Each stage uses 32 bits (4 bytes)
        uint256 packed = 0;
        packed |= uint32(srcWithdrawal);
        packed |= uint32(srcPublicWithdrawal) << 32;
        packed |= uint32(srcCancellation) << 64;
        packed |= uint32(srcPublicCancellation) << 96;
        packed |= uint32(dstWithdrawal) << 128;
        packed |= uint32(dstPublicWithdrawal) << 160;
        packed |= uint32(dstCancellation) << 192;
        
        // Add deployment timestamp (will be set when escrow is deployed)
        packed |= uint32(block.timestamp) << 224;
        
        return Timelocks.wrap(packed);
    }
    
    /**
     * @notice Creates immutables for source escrow
     */
    function createSrcImmutables(
        bytes32 orderHash,
        bytes32 hashlock,
        address maker,
        address taker,
        address token,
        uint256 amount,
        uint256 safetyDeposit,
        Timelocks timelocks
    ) public pure returns (IBaseEscrow.Immutables memory) {
        return IBaseEscrow.Immutables({
            orderHash: orderHash,
            hashlock: hashlock,
            maker: maker.toAddress(),
            taker: taker.toAddress(),
            token: token.toAddress(),
            amount: amount,
            safetyDeposit: safetyDeposit,
            timelocks: timelocks
        });
    }
    
    /**
     * @notice Creates immutables for destination escrow
     */
    function createDstImmutables(
        bytes32 orderHash,
        bytes32 hashlock,
        address maker,
        address taker,
        address token,
        uint256 amount,
        uint256 safetyDeposit,
        Timelocks timelocks
    ) public pure returns (IBaseEscrow.Immutables memory) {
        // For destination escrow, maker and taker are swapped
        return IBaseEscrow.Immutables({
            orderHash: orderHash,
            hashlock: hashlock,
            maker: taker.toAddress(),  // Taker becomes maker on dst
            taker: maker.toAddress(),  // Maker becomes taker on dst
            token: token.toAddress(),
            amount: amount,
            safetyDeposit: safetyDeposit,
            timelocks: timelocks
        });
    }
    
    /**
     * @notice Generates a secret and its hash for testing
     */
    function generateSecretAndHash() public pure returns (bytes32 secret, bytes32 hashlock) {
        secret = keccak256(abi.encodePacked("test_secret", block.timestamp));
        hashlock = keccak256(abi.encodePacked(secret));
    }
    
    /**
     * @notice Approves tokens for escrow
     */
    function approveTokens(address owner, address token, address spender, uint256 amount) public {
        vm.prank(owner);
        IERC20(token).approve(spender, amount);
    }
    
    /**
     * @notice Helper to advance time
     */
    function advanceTime(uint256 seconds_) public {
        vm.warp(block.timestamp + seconds_);
    }
    
    /**
     * @notice Helper to advance to specific timelock stage
     */
    function advanceToStage(Timelocks timelocks, TimelocksLib.Stage stage) public {
        uint256 stageStart = timelocks.get(stage);
        if (block.timestamp < stageStart) {
            vm.warp(stageStart);
        }
    }
    
    /**
     * @notice Helper to check if current time is within a specific stage
     */
    function isInStage(Timelocks timelocks, TimelocksLib.Stage stage) public view returns (bool) {
        uint256 stageStart = timelocks.get(stage);
        
        // Determine the end of the stage (start of next stage)
        uint256 stageEnd;
        if (stage == TimelocksLib.Stage.SrcWithdrawal) {
            stageEnd = timelocks.get(TimelocksLib.Stage.SrcPublicWithdrawal);
        } else if (stage == TimelocksLib.Stage.SrcPublicWithdrawal) {
            stageEnd = timelocks.get(TimelocksLib.Stage.SrcCancellation);
        } else if (stage == TimelocksLib.Stage.SrcCancellation) {
            stageEnd = timelocks.get(TimelocksLib.Stage.SrcPublicCancellation);
        } else if (stage == TimelocksLib.Stage.DstWithdrawal) {
            stageEnd = timelocks.get(TimelocksLib.Stage.DstPublicWithdrawal);
        } else if (stage == TimelocksLib.Stage.DstPublicWithdrawal) {
            stageEnd = timelocks.get(TimelocksLib.Stage.DstCancellation);
        } else {
            // Last stages have no end
            stageEnd = type(uint256).max;
        }
        
        return block.timestamp >= stageStart && block.timestamp < stageEnd;
    }
    
    /**
     * @notice Fork helper for multi-chain testing
     */
    function createAndSelectFork(string memory rpcUrl) public returns (uint256) {
        return vm.createSelectFork(rpcUrl);
    }
    
    /**
     * @notice Helper to get balance including both ETH and tokens
     */
    function getBalances(address account, address token) public view returns (uint256 ethBalance, uint256 tokenBalance) {
        ethBalance = account.balance;
        tokenBalance = IERC20(token).balanceOf(account);
    }
}