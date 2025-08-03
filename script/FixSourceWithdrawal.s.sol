// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {EscrowSrc} from "../contracts/EscrowSrc.sol";
import {TimelocksLib} from "../contracts/libraries/TimelocksLib.sol";
import {ImmutablesLib} from "../contracts/libraries/ImmutablesLib.sol";

contract FixSourceWithdrawal is Script {
    using TimelocksLib for TimelocksLib.Timelocks;
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
        
        // Get escrow instance
        EscrowSrc srcEscrow = EscrowSrc(SRC_ESCROW);
        
        // Get current immutables
        ImmutablesLib.Immutables memory currentImmutables = srcEscrow.immutables();
        console.log("Current immutables:");
        console.log("  maker:", currentImmutables.maker);
        console.log("  taker:", currentImmutables.taker);
        console.log("  token:", currentImmutables.token);
        console.log("  amount:", currentImmutables.amount);
        console.log("  safetyDeposit:", currentImmutables.safetyDeposit);
        console.log("  hashlock:", uint256(currentImmutables.hashlock));
        
        // Log current timelocks
        TimelocksLib.Timelocks memory currentTimelocks = currentImmutables.timelocks.unpackTimelocks();
        console.log("Current timelocks:");
        console.log("  srcWithdrawal:", currentTimelocks.srcWithdrawal);
        console.log("  srcPublicWithdrawal:", currentTimelocks.srcPublicWithdrawal);
        console.log("  srcCancellation:", currentTimelocks.srcCancellation);
        console.log("  srcPublicCancellation:", currentTimelocks.srcPublicCancellation);
        console.log("  deployedAt:", currentTimelocks.deployedAt);
        
        // Create updated immutables with correct deployment timestamp
        TimelocksLib.Timelocks memory fixedTimelocks = TimelocksLib.Timelocks({
            srcWithdrawal: currentTimelocks.srcWithdrawal,
            srcPublicWithdrawal: currentTimelocks.srcPublicWithdrawal,
            srcCancellation: currentTimelocks.srcCancellation,
            srcPublicCancellation: currentTimelocks.srcPublicCancellation,
            dstWithdrawal: currentTimelocks.dstWithdrawal,
            dstPublicWithdrawal: currentTimelocks.dstPublicWithdrawal,
            dstCancellation: currentTimelocks.dstCancellation,
            dstPublicCancellation: currentTimelocks.dstPublicCancellation,
            deployedAt: SRC_DEPLOY_TIME // Use the actual deployment timestamp
        });
        
        console.log("Fixed timelocks with correct deployedAt:", SRC_DEPLOY_TIME);
        
        // Create immutables with fixed timestamp
        ImmutablesLib.Immutables memory fixedImmutables = ImmutablesLib.Immutables({
            maker: currentImmutables.maker,
            taker: currentImmutables.taker,
            token: currentImmutables.token,
            amount: currentImmutables.amount,
            safetyDeposit: currentImmutables.safetyDeposit,
            timelocks: fixedTimelocks.packTimelocks(),
            hashlock: currentImmutables.hashlock
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
        
        try srcEscrow.withdraw(REVEALED_SECRET, fixedImmutables) {
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