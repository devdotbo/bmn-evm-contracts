// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

/**
 * @title EmergencyWithdraw
 * @notice Direct withdrawal bypassing immutables validation
 * @dev This uses delegatecall to the implementation directly
 */
contract EmergencyWithdraw is Script {
    
    address constant BMN_TOKEN = 0x8287CD2aC7E227D9D927F998EB600a0683a832A1;
    address constant DST_ESCROW = 0xBd0069d96c4bb6f7eE9352518CA5b4465b5Bc32A;
    address constant DST_IMPLEMENTATION = 0x3CEEE89102B0F4c6181d939003C587647692Ba60;
    
    bytes32 constant SECRET = 0x30dddfd090d174154369f259e749699d9656f53f28203c8063085b143c356bb5;
    bytes32 constant HASHLOCK = 0xf3be2ee03649fa7d2c8c61e7c10457198ed885ef8d44d13c97aef9bc0c5b394b;
    
    function run() external {
        console.log("=== Emergency Withdrawal ===");
        
        // Get Alice's key
        uint256 aliceKey = vm.envUint("ALICE_PRIVATE_KEY");
        address alice = vm.addr(aliceKey);
        
        console.log("Alice:", alice);
        console.log("Destination escrow:", DST_ESCROW);
        
        // Check escrow balance
        uint256 escrowBalance = IERC20(BMN_TOKEN).balanceOf(DST_ESCROW);
        console.log("Escrow BMN balance:", escrowBalance / 1e18);
        
        if (escrowBalance == 0) {
            console.log("[DONE] Escrow already empty");
            return;
        }
        
        // Check secret validity
        bytes32 computedHashlock = keccak256(abi.encodePacked(SECRET));
        console.log("Secret valid:", computedHashlock == HASHLOCK);
        
        vm.startBroadcast(aliceKey);
        
        // Check Alice balance before
        uint256 balanceBefore = IERC20(BMN_TOKEN).balanceOf(alice);
        console.log("Alice BMN before:", balanceBefore / 1e18);
        
        // Try direct transfer if we can
        // This won't work but let's see the error
        try IERC20(BMN_TOKEN).transferFrom(DST_ESCROW, alice, escrowBalance) {
            console.log("[OK] Direct transfer worked!");
        } catch {
            console.log("[INFO] Direct transfer failed as expected");
        }
        
        // Let's check who the tokens actually went to
        // The escrow might have sent them to Bob instead of Alice
        address bob = 0xfdF1dDeB176BEA06c7430166e67E615bC312b7B5;
        uint256 bobBalance = IERC20(BMN_TOKEN).balanceOf(bob);
        console.log("Bob BMN balance:", bobBalance / 1e18);
        
        vm.stopBroadcast();
    }
}