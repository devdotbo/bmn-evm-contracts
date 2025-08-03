// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { Timelocks, TimelocksLib } from "../contracts/libraries/TimelocksLib.sol";
import { IBaseEscrow } from "../contracts/interfaces/IBaseEscrow.sol";
import { ImmutablesLib } from "../contracts/libraries/ImmutablesLib.sol";
import { Create2 } from "openzeppelin-contracts/contracts/utils/Create2.sol";
import { Address, AddressLib } from "solidity-utils/contracts/libraries/AddressLib.sol";
import { ProxyHashLib } from "../contracts/libraries/ProxyHashLib.sol";

contract FindCorrectImmutables is Script {
    using TimelocksLib for Timelocks;
    using ImmutablesLib for IBaseEscrow.Immutables;
    using AddressLib for Address;

    function run() external view {
        address escrow = 0x9850803017DF87F40b8c9a91aC9af3C0DC3C78b0;
        address factory = 0xC6C18181B6a438bB4cd8Ebf0f06fFBB74CD4B7Ac;
        bytes32 proxyBytecodeHash = 0x3f6e7cae79a08f2b80b654d1c042f18459a7bde3f1ef1d9bee1b73c1e2d2f108;
        
        // Work backwards - what salt would produce this address?
        // We need to find salt where: keccak256(0xff ++ factory ++ salt ++ proxyBytecodeHash) == escrow
        
        console.log("Target escrow address:", escrow);
        console.log("Factory:", factory);
        console.log("Proxy bytecode hash:", vm.toString(proxyBytecodeHash));
        
        // Try the base immutables with different timestamps
        IBaseEscrow.Immutables memory immutables = IBaseEscrow.Immutables({
            orderHash: bytes32(0),
            hashlock: 0xa658a3e4fe67ba9cc553eb6614f3e3e99cece8ee77fff86a15f300a132d782a4,
            maker: Address.wrap(uint160(0xfdF1dDeB176BEA06c7430166e67E615bC312b7B5)),
            taker: Address.wrap(uint160(0x240E2588e35FB9D3D60B283B45108a49972FFFd8)),
            token: Address.wrap(uint160(0x9900D2f569F413DaBE121C4bB2758be46ad537eC)),
            amount: 10 ether,
            safetyDeposit: 0.0001 ether,
            timelocks: Timelocks.wrap(0)
        });
        
        // Try different timestamp values around the deployment time
        uint256 baseTimestamp = 1754186605;
        for (uint256 i = 0; i < 10; i++) {
            uint256 timestamp = baseTimestamp + i - 5;
            
            // Original timelocks
            Timelocks originalTimelocks = Timelocks.wrap(0x000003840000012c00000000000004b0000003840000012c00000000);
            immutables.timelocks = originalTimelocks.setDeployedAt(timestamp);
            
            bytes32 salt = immutables.hashMem();
            address computed = Create2.computeAddress(salt, proxyBytecodeHash, factory);
            
            if (computed == escrow) {
                console.log("\nFOUND MATCH!");
                console.log("Timestamp:", timestamp);
                console.log("Timelocks:", Timelocks.unwrap(immutables.timelocks));
                console.log("Salt:", vm.toString(salt));
                return;
            }
        }
        
        console.log("\nNo match found in timestamp range");
    }
}