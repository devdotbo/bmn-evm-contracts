// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { IBaseEscrow } from "../contracts/interfaces/IBaseEscrow.sol";
import { TimelocksLib, Timelocks } from "../contracts/libraries/TimelocksLib.sol";
import { ImmutablesLib } from "../contracts/libraries/ImmutablesLib.sol";
import { AddressLib, Address } from "solidity-utils/contracts/libraries/AddressLib.sol";
import { Clones } from "openzeppelin-contracts/contracts/proxy/Clones.sol";

/**
 * @title AnalyzeDeployment
 * @notice Reverse engineer the exact immutables from deployment
 */
contract AnalyzeDeployment is Script {
    using TimelocksLib for Timelocks;
    using ImmutablesLib for IBaseEscrow.Immutables;
    using AddressLib for Address;
    
    address constant FACTORY = 0x6b3E1410513DcC0874E367CbD79Ee3448D6478C9;
    address constant DST_IMPLEMENTATION = 0x3CEEE89102B0F4c6181d939003C587647692Ba60;
    address constant DST_ESCROW = 0xBd0069d96c4bb6f7eE9352518CA5b4465b5Bc32A;
    
    bytes32 constant SECRET = 0x30dddfd090d174154369f259e749699d9656f53f28203c8063085b143c356bb5;
    bytes32 constant HASHLOCK = 0xf3be2ee03649fa7d2c8c61e7c10457198ed885ef8d44d13c97aef9bc0c5b394b;
    
    function run() external view {
        console.log("=== Analyzing Deployment ===");
        
        // Known deployment block: 22577145 (from transaction)
        // Transaction: 0xc30729f56751331b06dd48941246bdcc50088d508d3954ff27a9d75859f61d18
        
        // Let's try different timestamps around the deployment
        uint256 baseTime = 1754231207; // From our logs
        
        for (uint256 offset = 0; offset <= 20; offset++) {
            for (int256 direction = -1; direction <= 1; direction += 2) {
                if (offset == 0 && direction == -1) continue;
                
                uint256 tryTime = direction > 0 
                    ? baseTime + offset 
                    : baseTime - offset;
                
                // Build immutables with this timestamp
                IBaseEscrow.Immutables memory immutables = IBaseEscrow.Immutables({
                    orderHash: bytes32(0),
                    hashlock: HASHLOCK,
                    maker: Address.wrap(uint160(0xfdF1dDeB176BEA06c7430166e67E615bC312b7B5)), // Bob
                    taker: Address.wrap(uint160(0x240E2588e35FB9D3D60B283B45108a49972FFFd8)), // Alice
                    token: Address.wrap(uint160(0x8287CD2aC7E227D9D927F998EB600a0683a832A1)), // BMN
                    amount: 10 ether,
                    safetyDeposit: 0.00001 ether,
                    timelocks: createTimelocks().setDeployedAt(tryTime)
                });
                
                // Calculate expected address
                address calculated = Clones.predictDeterministicAddress(
                    DST_IMPLEMENTATION,
                    immutables.hashMem(),
                    FACTORY
                );
                
                if (calculated == DST_ESCROW) {
                    console.log("[FOUND] Matching timestamp:", tryTime);
                    console.log("  Offset from base:", int256(tryTime) - int256(baseTime));
                    console.log("  Packed timelocks:", Timelocks.unwrap(immutables.timelocks));
                    
                    // Print the exact immutables to use
                    console.log("\nUse these exact values for withdrawal:");
                    console.log("  Timestamp:", tryTime);
                    console.log("  Timelocks (packed):", Timelocks.unwrap(immutables.timelocks));
                    return;
                }
            }
        }
        
        console.log("[ERROR] Could not find matching timestamp");
        console.log("The escrow might have been deployed with different parameters");
    }
    
    function createTimelocks() internal pure returns (Timelocks) {
        uint256 packed = 0;
        packed |= uint256(uint32(0));      // SRC_WITHDRAWAL_START
        packed |= uint256(uint32(600)) << 32;  // SRC_PUBLIC_WITHDRAWAL_START
        packed |= uint256(uint32(1800)) << 64; // SRC_CANCELLATION_START
        packed |= uint256(uint32(2100)) << 96; // SRC_PUBLIC_CANCELLATION_START
        packed |= uint256(uint32(0)) << 128;   // DST_WITHDRAWAL_START
        packed |= uint256(uint32(600)) << 160; // DST_PUBLIC_WITHDRAWAL_START
        packed |= uint256(uint32(1800)) << 192; // DST_CANCELLATION_START
        
        return Timelocks.wrap(packed);
    }
}