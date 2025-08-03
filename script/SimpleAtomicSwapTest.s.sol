// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { IBaseEscrow } from "../contracts/interfaces/IBaseEscrow.sol";
import { BaseEscrowFactory } from "../contracts/BaseEscrowFactory.sol";
import { EscrowDst } from "../contracts/EscrowDst.sol";
import { Timelocks, TimelocksLib } from "../contracts/libraries/TimelocksLib.sol";
import { Address, AddressLib } from "solidity-utils/contracts/libraries/AddressLib.sol";

/**
 * @title SimpleAtomicSwapTest
 * @notice Simple test for atomic swap using only destination escrow creation
 * @dev Since source escrow needs limit order protocol, we'll focus on destination escrow
 */
contract SimpleAtomicSwapTest is Script {
    using AddressLib for address;
    using TimelocksLib for Timelocks;

    // Deployed contract addresses (same on both chains)
    address constant FACTORY = 0xc72ed1E8a0649e51Cd046a0FfccC8f8c0bf385Fa;
    address constant BMN_TOKEN = 0x8287CD2aC7E227D9D927F998EB600a0683a832A1; // BMN V1 with 18 decimals
    
    // Test accounts from .env
    address constant ALICE = 0x240E2588e35FB9D3D60B283B45108a49972FFFd8;
    address constant BOB = 0xfdF1dDeB176BEA06c7430166e67E615bC312b7B5;
    
    // Test parameters
    uint256 constant SWAP_AMOUNT = 10e18; // 10 BMN (18 decimals)
    uint256 constant SAFETY_DEPOSIT = 0.001 ether; // Safety deposit in ETH
    
    function run() external {
        string memory action = vm.envOr("ACTION", string(""));
        
        if (keccak256(bytes(action)) == keccak256(bytes("create-dst"))) {
            createDstEscrow();
        } else if (keccak256(bytes(action)) == keccak256(bytes("check-balances"))) {
            checkBalances();
        } else {
            console.log("Usage:");
            console.log("  ACTION=create-dst forge script script/SimpleAtomicSwapTest.s.sol --rpc-url <ETHERLINK_RPC> --broadcast");
            console.log("  ACTION=check-balances forge script script/SimpleAtomicSwapTest.s.sol --rpc-url <RPC>");
            console.log("");
            console.log("Note: Source escrow creation requires going through 1inch Limit Order Protocol");
        }
    }

    function createDstEscrow() internal {
        console.log("--- Creating Destination Escrow ---");
        
        // Get Bob's private key (resolver)
        uint256 bobKey = vm.envUint("RESOLVER_PRIVATE_KEY");
        address bob = vm.addr(bobKey);
        require(bob == BOB, "Bob address mismatch");

        vm.startBroadcast(bobKey);

        // Create test hashlock
        bytes32 secret = keccak256(abi.encodePacked(block.timestamp, "test-secret"));
        bytes32 hashlock = keccak256(abi.encodePacked(secret));
        
        console.log("Secret:", vm.toString(secret));
        console.log("Hashlock:", vm.toString(hashlock));

        // Check Bob's balance
        uint256 balance = IERC20(BMN_TOKEN).balanceOf(bob);
        console.log("Bob BMN balance:", balance / 1e18, "BMN");
        require(balance >= SWAP_AMOUNT, "Insufficient BMN balance");

        // Create destination immutables
        IBaseEscrow.Immutables memory dstImmutables = IBaseEscrow.Immutables({
            orderHash: bytes32(0), // No order hash for testing
            hashlock: hashlock,
            maker: Address.wrap(uint160(BOB)), // Bob is maker on destination
            taker: Address.wrap(uint160(ALICE)), // Alice is taker on destination
            token: Address.wrap(uint160(BMN_TOKEN)),
            amount: SWAP_AMOUNT,
            safetyDeposit: SAFETY_DEPOSIT,
            timelocks: createTimelocks()
        });

        // Calculate expected escrow address
        address expectedEscrow = BaseEscrowFactory(FACTORY).addressOfEscrowDst(dstImmutables);
        console.log("Expected escrow address:", expectedEscrow);

        // Pre-fund the escrow with safety deposit
        console.log("Sending safety deposit:", SAFETY_DEPOSIT / 1e18, "ETH");
        (bool sent,) = expectedEscrow.call{value: SAFETY_DEPOSIT}("");
        require(sent, "Failed to send safety deposit");

        // Approve token transfer to escrow
        IERC20(BMN_TOKEN).approve(expectedEscrow, SWAP_AMOUNT);
        console.log("Approved", SWAP_AMOUNT / 1e18, "BMN to escrow");

        // Create destination escrow
        BaseEscrowFactory(FACTORY).createDstEscrow{value: 0}(dstImmutables, block.timestamp);
        
        console.log("Destination escrow created!");
        console.log("Escrow address:", expectedEscrow);
        
        // Verify deployment
        uint256 escrowBalance = IERC20(BMN_TOKEN).balanceOf(expectedEscrow);
        console.log("Escrow BMN balance:", escrowBalance / 1e18, "BMN");
        
        vm.stopBroadcast();
    }

    function createTimelocks() internal view returns (Timelocks) {
        uint256 currentTime = block.timestamp;
        return TimelocksLib.setTimelocks(
            Timelocks.wrap(0),
            TimelocksLib.Stage.SrcWithdrawal,        currentTime + 0
        ).setTimelocks(
            TimelocksLib.Stage.SrcPublicWithdrawal,  currentTime + 300    // 5 minutes
        ).setTimelocks(
            TimelocksLib.Stage.SrcCancellation,      currentTime + 900    // 15 minutes
        ).setTimelocks(
            TimelocksLib.Stage.SrcPublicCancellation, currentTime + 1200  // 20 minutes
        ).setTimelocks(
            TimelocksLib.Stage.DstWithdrawal,        currentTime + 0
        ).setTimelocks(
            TimelocksLib.Stage.DstPublicWithdrawal,  currentTime + 300    // 5 minutes
        ).setTimelocks(
            TimelocksLib.Stage.DstCancellation,      currentTime + 900    // 15 minutes
        );
    }

    function checkBalances() internal view {
        console.log("=== Token Balances ===");
        console.log("Alice BMN:", IERC20(BMN_TOKEN).balanceOf(ALICE) / 1e18);
        console.log("Bob BMN:", IERC20(BMN_TOKEN).balanceOf(BOB) / 1e18);
    }
}