// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { IBaseEscrow } from "../contracts/interfaces/IBaseEscrow.sol";
import { TimelocksLib, Timelocks } from "../contracts/libraries/TimelocksLib.sol";
import { AddressLib, Address } from "solidity-utils/contracts/libraries/AddressLib.sol";

/**
 * @title DirectWithdraw
 * @notice Try every possible timestamp combination
 */
contract DirectWithdraw is Script {
    using TimelocksLib for Timelocks;
    
    address constant BMN_TOKEN = 0x8287CD2aC7E227D9D927F998EB600a0683a832A1;
    address constant DST_ESCROW = 0xBd0069d96c4bb6f7eE9352518CA5b4465b5Bc32A;
    
    bytes32 constant SECRET = 0x30dddfd090d174154369f259e749699d9656f53f28203c8063085b143c356bb5;
    bytes32 constant HASHLOCK = 0xf3be2ee03649fa7d2c8c61e7c10457198ed885ef8d44d13c97aef9bc0c5b394b;
    
    function run() external {
        console.log("=== Direct Withdrawal Attempt ===");
        
        uint256 aliceKey = vm.envUint("ALICE_PRIVATE_KEY");
        address alice = vm.addr(aliceKey);
        
        // Check current balance
        uint256 escrowBalance = IERC20(BMN_TOKEN).balanceOf(DST_ESCROW);
        console.log("Escrow balance:", escrowBalance / 1e18, "BMN");
        
        if (escrowBalance == 0) {
            console.log("Escrow already empty!");
            return;
        }
        
        vm.startBroadcast(aliceKey);
        
        // Try a range of timestamps around the known deployment time
        uint256 baseTime = 1754231207;
        bool success = false;
        
        for (uint256 i = 0; i <= 30 && !success; i++) {
            for (int256 dir = -1; dir <= 1 && !success; dir += 2) {
                if (i == 0 && dir == -1) continue;
                
                uint256 tryTime = dir > 0 ? baseTime + i : baseTime - i;
                
                // Build immutables
                IBaseEscrow.Immutables memory immutables = IBaseEscrow.Immutables({
                    orderHash: bytes32(0),
                    hashlock: HASHLOCK,
                    maker: Address.wrap(uint160(0xfdF1dDeB176BEA06c7430166e67E615bC312b7B5)),
                    taker: Address.wrap(uint160(alice)),
                    token: Address.wrap(uint160(BMN_TOKEN)),
                    amount: 10 ether,
                    safetyDeposit: 0.00001 ether,
                    timelocks: createTimelocks().setDeployedAt(tryTime)
                });
                
                try IBaseEscrow(DST_ESCROW).withdraw(SECRET, immutables) {
                    console.log("[SUCCESS] Withdrawn with timestamp:", tryTime);
                    success = true;
                    
                    uint256 newBalance = IERC20(BMN_TOKEN).balanceOf(alice);
                    console.log("Alice new balance:", newBalance / 1e18);
                } catch {
                    // Continue trying
                }
            }
        }
        
        if (!success) {
            console.log("[FAILED] Could not find correct timestamp");
            
            // Let's check where the tokens might have gone
            address bob = 0xfdF1dDeB176BEA06c7430166e67E615bC312b7B5;
            uint256 bobBalance = IERC20(BMN_TOKEN).balanceOf(bob);
            console.log("Bob balance:", bobBalance / 1e18);
            
            // Check if tokens went to the escrow maker (Bob)
            uint256 escrowNewBalance = IERC20(BMN_TOKEN).balanceOf(DST_ESCROW);
            if (escrowNewBalance < escrowBalance) {
                console.log("Tokens were withdrawn! Escrow now has:", escrowNewBalance / 1e18);
                console.log("Bob might have received them as he's the maker on destination");
            }
        }
        
        vm.stopBroadcast();
    }
    
    function createTimelocks() internal pure returns (Timelocks) {
        uint256 packed = 0;
        packed |= uint256(uint32(0));
        packed |= uint256(uint32(600)) << 32;
        packed |= uint256(uint32(1800)) << 64;
        packed |= uint256(uint32(2100)) << 96;
        packed |= uint256(uint32(0)) << 128;
        packed |= uint256(uint32(600)) << 160;
        packed |= uint256(uint32(1800)) << 192;
        
        return Timelocks.wrap(packed);
    }
}