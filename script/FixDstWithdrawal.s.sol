// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {TimelocksLib, Timelocks} from "../contracts/libraries/TimelocksLib.sol";
import {ImmutablesLib} from "../contracts/libraries/ImmutablesLib.sol";
import {IBaseEscrow} from "../contracts/interfaces/IBaseEscrow.sol";
import {AddressLib, Address} from "@1inch/solidity-utils/contracts/libraries/AddressLib.sol";

contract FixDstWithdrawal is Script {
    using TimelocksLib for Timelocks;
    using AddressLib for Address;
    
    // Actual deployed escrow address from event
    address constant DST_ESCROW = 0xBd0069d96c4bb6f7eE9352518CA5b4465b5Bc32A;
    address constant BMN_TOKEN = 0x8287CD2aC7E227D9D927F998EB600a0683a832A1;
    bytes32 constant SECRET = 0x30dddfd090d174154369f259e749699d9656f53f28203c8063085b143c356bb5;
    
    // From transaction logs
    uint256 constant ACTUAL_DEPLOY_TIME = 1754231207;
    
    function run() external {
        console.log("Starting FixDstWithdrawal script");
        console.log("Destination escrow:", DST_ESCROW);
        console.log("Secret:", vm.toString(SECRET));
        
        uint256 aliceKey = vm.envUint("ALICE_PRIVATE_KEY");
        address alice = vm.addr(aliceKey);
        console.log("Alice address:", alice);
        
        vm.startBroadcast(aliceKey);
        
        // Load state to get original immutables
        string memory stateJson = vm.readFile("deployments/mainnet-test-state.json");
        bytes memory dstImmutablesData = vm.parseJsonBytes(stateJson, ".dstImmutables");
        IBaseEscrow.Immutables memory immutables = abi.decode(dstImmutablesData, (IBaseEscrow.Immutables));
        
        console.log("Original immutables:");
        console.log("  hashlock:", vm.toString(immutables.hashlock));
        console.log("  maker:", Address.unwrap(immutables.maker));
        console.log("  taker:", Address.unwrap(immutables.taker));
        console.log("  amount:", immutables.amount);
        
        // Update timelocks with actual deployment timestamp
        Timelocks fixedTimelocks = immutables.timelocks.setDeployedAt(ACTUAL_DEPLOY_TIME);
        
        // Create immutables with fixed timestamp
        IBaseEscrow.Immutables memory fixedImmutables = IBaseEscrow.Immutables({
            orderHash: immutables.orderHash,
            hashlock: immutables.hashlock,
            maker: immutables.maker,
            taker: immutables.taker,
            token: immutables.token,
            amount: immutables.amount,
            safetyDeposit: immutables.safetyDeposit,
            timelocks: fixedTimelocks
        });
        
        // Check balance before
        uint256 balanceBefore = IERC20(BMN_TOKEN).balanceOf(alice);
        console.log("Alice BMN balance before:", balanceBefore / 1e18);
        
        // Withdraw
        try IBaseEscrow(DST_ESCROW).withdraw(SECRET, fixedImmutables) {
            console.log("[OK] Withdrawal successful!");
            
            uint256 balanceAfter = IERC20(BMN_TOKEN).balanceOf(alice);
            console.log("Alice BMN balance after:", balanceAfter / 1e18);
            console.log("Alice received:", (balanceAfter - balanceBefore) / 1e18, "BMN");
        } catch Error(string memory reason) {
            console.log("[ERROR] Withdrawal failed:", reason);
            revert(reason);
        } catch (bytes memory data) {
            console.log("[ERROR] Withdrawal failed with data:");
            console.logBytes(data);
            revert("Withdrawal failed");
        }
        
        vm.stopBroadcast();
    }
}