// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { Clones } from "@openzeppelin/contracts/proxy/Clones.sol";
import { Create2 } from "@openzeppelin/contracts/utils/Create2.sol";
import { IBaseEscrow } from "../contracts/interfaces/IBaseEscrow.sol";
import { ImmutablesLib } from "../contracts/libraries/ImmutablesLib.sol";
import { TestEscrowFactory } from "../contracts/test/TestEscrowFactory.sol";
import { Timelocks } from "../contracts/libraries/TimelocksLib.sol";
import { Address, AddressLib } from "solidity-utils/contracts/libraries/AddressLib.sol";

contract TestAddressFix is Script {
    using ImmutablesLib for IBaseEscrow.Immutables;
    using AddressLib for Address;

    function run() external view {
        // Factory and implementation addresses from mainnet
        address factory = 0xC6C18181B6a438bB4cd8Ebf0f06fFBB74CD4B7Ac;
        address dstImplementation = 0xDde30688c44C0635C2e0CefF75f079E1Dc1bB9ea;
        
        // The actual deployed escrow
        address actualEscrow = 0x9850803017DF87F40b8c9a91aC9af3C0DC3C78b0;
        
        // Create the immutables that were used
        IBaseEscrow.Immutables memory immutables = IBaseEscrow.Immutables({
            orderHash: bytes32(0),
            hashlock: 0xa658a3e4fe67ba9cc553eb6614f3e3e99cece8ee77fff86a15f300a132d782a4,
            maker: Address.wrap(uint160(0xfdF1dDeB176BEA06c7430166e67E615bC312b7B5)),
            taker: Address.wrap(uint160(0x240E2588e35FB9D3D60B283B45108a49972FFFd8)),
            token: Address.wrap(uint160(0x9900D2f569F413DaBE121C4bB2758be46ad537eC)),
            amount: 10 ether,
            safetyDeposit: 0.0001 ether,
            timelocks: Timelocks.wrap(47292777315030051494376390587445924151222761819550151656107649410606070497280)
        });
        
        bytes32 salt = immutables.hashMem();
        console.log("Salt:", vm.toString(salt));
        
        // Current (wrong) method using Create2
        bytes32 proxyBytecodeHash = 0x3f6e7cae79a08f2b80b654d1c042f18459a7bde3f1ef1d9bee1b73c1e2d2f108;
        address wrongPrediction = Create2.computeAddress(salt, proxyBytecodeHash, factory);
        console.log("\nCurrent (wrong) prediction:", wrongPrediction);
        
        // Correct method using Clones
        address correctPrediction = Clones.predictDeterministicAddress(dstImplementation, salt, factory);
        console.log("Correct prediction using Clones:", correctPrediction);
        console.log("Actual deployed address:", actualEscrow);
        console.log("Matches actual?", correctPrediction == actualEscrow);
        
        // Show the fix
        console.log("\n=== THE FIX ===");
        console.log("Replace in BaseEscrowFactory.sol:");
        console.log("OLD: return Create2.computeAddress(immutables.hash(), _PROXY_DST_BYTECODE_HASH);");
        console.log("NEW: return Clones.predictDeterministicAddress(ESCROW_DST_IMPLEMENTATION, immutables.hash(), address(this));");
    }
}