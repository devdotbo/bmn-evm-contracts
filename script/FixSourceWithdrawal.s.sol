// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {TimelocksLib, Timelocks} from "../contracts/libraries/TimelocksLib.sol";
import {ImmutablesLib} from "../contracts/libraries/ImmutablesLib.sol";
import {IBaseEscrow} from "../contracts/interfaces/IBaseEscrow.sol";
import {AddressLib} from "@1inch/solidity-utils/contracts/libraries/AddressLib.sol";

contract FixSourceWithdrawal is Script {
    using TimelocksLib for Timelocks;
    using TimelocksLib for uint256;
    
    // Mainnet addresses
    address constant BMN_TOKEN = 0x8287CD2aC7E227D9D927F998EB600a0683a832A1;
    address constant SRC_ESCROW = 0xE73bFBDA2536DeD96dDCe725C31cc14FBE30d846;
    
    // Secret revealed on destination
    bytes32 constant REVEALED_SECRET = 0x065ffa72d04873fca0bb49ad393714a5ad7874e3f48530479a8d3311269dd3c3;
    
    // Deployment timestamp from state file
    uint32 constant SRC_DEPLOY_TIME = 1754229097;
    
    function run() external {
        console.log("Starting FixSourceWithdrawal script");
        console.log("Source escrow address:", SRC_ESCROW);
        console.log("BMN token address:", BMN_TOKEN);
        console.log("Secret:", uint256(REVEALED_SECRET));
        console.log("Deploy timestamp:", SRC_DEPLOY_TIME);
        
        // Load resolver private key
        uint256 resolverPrivateKey = vm.envUint("RESOLVER_PRIVATE_KEY");
        address resolver = vm.addr(resolverPrivateKey);
        console.log("Resolver address:", resolver);
        
        // Start broadcasting transactions
        vm.startBroadcast(resolverPrivateKey);
        
        // Load immutables from state file
        string memory stateJson = vm.readFile("deployments/mainnet-test-state.json");
        bytes memory srcImmutablesData = vm.parseJsonBytes(stateJson, ".srcImmutables");
        IBaseEscrow.Immutables memory currentImmutables = abi.decode(srcImmutablesData, (IBaseEscrow.Immutables));
        
        console.log("Current immutables:");
        console.log("  maker:", AddressLib.get(currentImmutables.maker));
        console.log("  taker:", AddressLib.get(currentImmutables.taker));
        console.log("  token:", AddressLib.get(currentImmutables.token));
        console.log("  amount:", currentImmutables.amount);
        console.log("  safetyDeposit:", currentImmutables.safetyDeposit);
        console.log("  hashlock:", uint256(currentImmutables.hashlock));
        
        // Log current timelocks - no need to unpack, already have Timelocks type
        Timelocks currentTimelocks = currentImmutables.timelocks;
        console.log("Current timelocks (packed):", Timelocks.unwrap(currentTimelocks));
        
        // Update timelocks with correct deployment timestamp
        Timelocks fixedTimelocks = currentTimelocks.setDeployedAt(SRC_DEPLOY_TIME);
        
        console.log("Fixed timelocks with correct deployedAt:", SRC_DEPLOY_TIME);
        
        // Create immutables with fixed timestamp
        IBaseEscrow.Immutables memory fixedImmutables = IBaseEscrow.Immutables({
            orderHash: currentImmutables.orderHash,
            hashlock: currentImmutables.hashlock,
            maker: currentImmutables.maker,
            taker: currentImmutables.taker,
            token: currentImmutables.token,
            amount: currentImmutables.amount,
            safetyDeposit: currentImmutables.safetyDeposit,
            timelocks: fixedTimelocks
        });
        
        // Check resolver's balance before withdrawal
        IERC20 bmn = IERC20(BMN_TOKEN);
        uint256 balanceBefore = bmn.balanceOf(resolver);
        console.log("Resolver BMN balance before:", balanceBefore);
        
        // Check escrow balance
        uint256 escrowBalance = bmn.balanceOf(SRC_ESCROW);
        console.log("Escrow BMN balance:", escrowBalance);
        
        // Get expected withdrawal amount
        uint256 expectedAmount = currentImmutables.amount + currentImmutables.safetyDeposit;
        console.log("Expected withdrawal amount (amount + safety deposit):", expectedAmount);
        
        try IBaseEscrow(SRC_ESCROW).withdraw(REVEALED_SECRET, fixedImmutables) {
            console.log("[OK] Withdrawal successful!");
            
            // Check resolver's balance after withdrawal
            uint256 balanceAfter = bmn.balanceOf(resolver);
            console.log("Resolver BMN balance after:", balanceAfter);
            console.log("Amount received:", balanceAfter - balanceBefore);
            
            // Verify the correct amount was received
            require(
                balanceAfter - balanceBefore == expectedAmount,
                "Incorrect withdrawal amount"
            );
            
        } catch Error(string memory reason) {
            console.log("[ERROR] Withdrawal failed with reason:", reason);
            revert(reason);
        } catch (bytes memory lowLevelData) {
            console.log("[ERROR] Withdrawal failed with low-level error");
            console.logBytes(lowLevelData);
            revert("Withdrawal failed");
        }
        
        vm.stopBroadcast();
        
        console.log("\n[OK] Source withdrawal completed successfully!");
    }
}