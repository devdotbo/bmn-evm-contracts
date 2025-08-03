// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { Timelocks, TimelocksLib } from "../contracts/libraries/TimelocksLib.sol";
import { IBaseEscrow } from "../contracts/interfaces/IBaseEscrow.sol";
import { Address, AddressLib } from "solidity-utils/contracts/libraries/AddressLib.sol";

contract TryWithdraw is Script {
    using TimelocksLib for Timelocks;
    using AddressLib for Address;

    function run() external {
        uint256 aliceKey = vm.envUint("ALICE_PRIVATE_KEY");
        
        vm.startBroadcast(aliceKey);
        
        address escrow = 0x9850803017DF87F40b8c9a91aC9af3C0DC3C78b0;
        bytes32 secret = 0x0f1cf0e6fe123e743f7e849f13e8623aa913c84681e1337ebe1329ed872ac82c;
        
        // Try different combinations
        // 1. With deployed timelocks from transaction input
        IBaseEscrow.Immutables memory immutables = IBaseEscrow.Immutables({
            orderHash: bytes32(0),
            hashlock: 0xa658a3e4fe67ba9cc553eb6614f3e3e99cece8ee77fff86a15f300a132d782a4,
            maker: Address.wrap(uint160(0xfdF1dDeB176BEA06c7430166e67E615bC312b7B5)),
            taker: Address.wrap(uint160(0x240E2588e35FB9D3D60B283B45108a49972FFFd8)),
            token: Address.wrap(uint160(0x9900D2f569F413DaBE121C4bB2758be46ad537eC)),
            amount: 10 ether,
            safetyDeposit: 0.0001 ether,
            timelocks: Timelocks.wrap(0x688ec36d000003840000012c00000000000004b0000003840000012c00000000)
        });
        
        console.log("Trying withdrawal with timelocks from tx input...");
        try IBaseEscrow(escrow).withdraw(secret, immutables) {
            console.log("Success!");
            vm.stopBroadcast();
            return;
        } catch {
            console.log("Failed with timelocks from tx input");
        }
        
        // 2. Try with calculated deployed timelocks  
        immutables.timelocks = Timelocks.wrap(47292777315030051494376390587445924151222761819550151656107649410606070497280);
        
        console.log("Trying withdrawal with calculated deployed timelocks...");
        try IBaseEscrow(escrow).withdraw(secret, immutables) {
            console.log("Success!");
            vm.stopBroadcast();
            return;
        } catch {
            console.log("Failed with calculated deployed timelocks");
        }
        
        vm.stopBroadcast();
    }
}