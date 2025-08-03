// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { Address, AddressLib } from "solidity-utils/contracts/libraries/AddressLib.sol";
import { IBaseEscrow } from "../contracts/interfaces/IBaseEscrow.sol";
import { Timelocks, TimelocksLib } from "../contracts/libraries/TimelocksLib.sol";
import { Constants } from "../contracts/Constants.sol";

/**
 * @title WithdrawSrcMainnetTest
 * @notice Script to withdraw from source escrow with correct immutables
 */
contract WithdrawSrcMainnetTest is Script {
    using AddressLib for address;
    using TimelocksLib for Timelocks;

    function run() external {
        // Configuration
        address srcEscrow = 0x299Bb6CA2537C1D5b5685185bD0aBa7FaDB3D2F9;
        bytes32 secret = 0x173c160980cf11dc8d5b81a65ea5de305e68219626e2823384922cea01e3af2b;
        bytes32 hashlock = 0x69982c0e07c20f1435e596d86ad3f86a5a0d7fa64c3160bf04c245a44100a131;
        uint256 actualDeploymentTimestamp = 1754224847; // From block timestamp
        
        // Get Bob's private key from environment
        uint256 bobKey = vm.envUint("RESOLVER_PRIVATE_KEY");
        address bob = vm.addr(bobKey);
        
        vm.startBroadcast(bobKey);
        
        // Check balance before
        uint256 balanceBefore = IERC20(Constants.BMN_TOKEN).balanceOf(bob);
        console.log("Bob BMN balance before:", balanceBefore / 1e18);
        
        // Create timelocks with actual deployment timestamp
        uint256 packedTimelocks = 0;
        packedTimelocks |= uint256(uint32(0)); // SRC_WITHDRAWAL_START
        packedTimelocks |= uint256(uint32(300)) << 32; // SRC_PUBLIC_WITHDRAWAL_START
        packedTimelocks |= uint256(uint32(900)) << 64; // SRC_CANCELLATION_START
        packedTimelocks |= uint256(uint32(1200)) << 96; // SRC_PUBLIC_CANCELLATION_START
        packedTimelocks |= uint256(uint32(0)) << 128; // DST_WITHDRAWAL_START
        packedTimelocks |= uint256(uint32(300)) << 160; // DST_PUBLIC_WITHDRAWAL_START
        packedTimelocks |= uint256(uint32(900)) << 192; // DST_CANCELLATION_START
        packedTimelocks |= uint256(uint64(actualDeploymentTimestamp)) << 224; // DEPLOYED_AT
        
        Timelocks timelocks = Timelocks.wrap(packedTimelocks);
        
        // Create immutables matching what the escrow expects
        IBaseEscrow.Immutables memory srcImmutables = IBaseEscrow.Immutables({
            orderHash: bytes32(0),
            hashlock: hashlock,
            maker: Address.wrap(uint160(0x240E2588e35FB9D3D60B283B45108a49972FFFd8)), // Alice
            taker: Address.wrap(uint160(bob)), // Bob
            token: Address.wrap(uint160(Constants.BMN_TOKEN)),
            amount: 10 ether,
            safetyDeposit: 0.00001 ether,
            timelocks: timelocks
        });
        
        console.log("Attempting withdrawal with:");
        console.log("  Escrow:", srcEscrow);
        console.log("  Secret:", vm.toString(secret));
        console.log("  Deployment timestamp:", actualDeploymentTimestamp);
        
        // Withdraw from source escrow
        IBaseEscrow(srcEscrow).withdraw(secret, srcImmutables);
        
        // Check balance after
        uint256 balanceAfter = IERC20(Constants.BMN_TOKEN).balanceOf(bob);
        console.log("Bob BMN balance after:", balanceAfter / 1e18);
        console.log("Bob received:", (balanceAfter - balanceBefore) / 1e18, "BMN");
        
        vm.stopBroadcast();
    }
}