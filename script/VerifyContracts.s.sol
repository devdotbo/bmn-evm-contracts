// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { Script } from "forge-std/Script.sol";
import { console2 } from "forge-std/console2.sol";

/**
 * @title VerifyContracts
 * @notice Script to help with contract verification on block explorers
 * @dev Provides constructor arguments encoding for manual verification
 */
contract VerifyContracts is Script {
    // Deployed contract addresses
    address constant BMN_ACCESS_TOKEN_V2 = 0x18ae5BB6E03Dc346eA9fd1afA78FEc314343857e;
    address constant ESCROW_FACTORY = 0x068aABdFa6B8c442CD32945A9A147B45ad7146d2;
    address constant ESCROW_SRC_IMPL = 0x8F92Da1e1B537003569B7293B8063e6e79f27Fc6;
    address constant ESCROW_DST_IMPL = 0xFd3114ef8B537003569b7293B8063E6e79f27FC6;
    
    // Constructor arguments
    address constant OWNER = 0x5f29827e25dc174a6A51C99e6811Bbd7581285b0;
    address constant LIMIT_ORDER_PROTOCOL = address(0);
    address constant FEE_TOKEN = address(0);
    uint32 constant RESCUE_DELAY = 86400; // 1 day
    
    function run() external view {
        console2.log("=== Contract Verification Information ===");
        console2.log("");
        
        // BMNAccessTokenV2
        console2.log("1. BMNAccessTokenV2");
        console2.log("   Address:", BMN_ACCESS_TOKEN_V2);
        console2.log("   Constructor args (ABI encoded):");
        bytes memory bmnArgs = abi.encode(OWNER);
        console2.log("   ", vm.toString(bmnArgs));
        console2.log("");
        
        // EscrowFactory
        console2.log("2. EscrowFactory");
        console2.log("   Address:", ESCROW_FACTORY);
        console2.log("   Constructor args (ABI encoded):");
        bytes memory factoryArgs = abi.encode(
            LIMIT_ORDER_PROTOCOL,
            FEE_TOKEN,
            BMN_ACCESS_TOKEN_V2,
            OWNER,
            RESCUE_DELAY,
            RESCUE_DELAY
        );
        console2.log("   ", vm.toString(factoryArgs));
        console2.log("");
        
        // EscrowSrc Implementation
        console2.log("3. EscrowSrc Implementation");
        console2.log("   Address:", ESCROW_SRC_IMPL);
        console2.log("   Constructor args (ABI encoded):");
        bytes memory srcArgs = abi.encode(RESCUE_DELAY, BMN_ACCESS_TOKEN_V2);
        console2.log("   ", vm.toString(srcArgs));
        console2.log("");
        
        // EscrowDst Implementation
        console2.log("4. EscrowDst Implementation");
        console2.log("   Address:", ESCROW_DST_IMPL);
        console2.log("   Constructor args (ABI encoded):");
        bytes memory dstArgs = abi.encode(RESCUE_DELAY, BMN_ACCESS_TOKEN_V2);
        console2.log("   ", vm.toString(dstArgs));
        console2.log("");
        
        console2.log("=== Verification Commands ===");
        console2.log("");
        console2.log("For Base:");
        console2.log("./scripts/verify-base.sh");
        console2.log("");
        console2.log("For Etherlink:");
        console2.log("./scripts/verify-etherlink.sh");
    }
    
    /**
     * @notice Generate constructor arguments for BMNAccessTokenV2
     */
    function getBMNAccessTokenV2Args() external pure returns (bytes memory) {
        return abi.encode(OWNER);
    }
    
    /**
     * @notice Generate constructor arguments for EscrowFactory
     */
    function getEscrowFactoryArgs() external pure returns (bytes memory) {
        return abi.encode(
            LIMIT_ORDER_PROTOCOL,
            FEE_TOKEN,
            BMN_ACCESS_TOKEN_V2,
            OWNER,
            RESCUE_DELAY,
            RESCUE_DELAY
        );
    }
    
    /**
     * @notice Generate constructor arguments for EscrowSrc
     */
    function getEscrowSrcArgs() external pure returns (bytes memory) {
        return abi.encode(RESCUE_DELAY, BMN_ACCESS_TOKEN_V2);
    }
    
    /**
     * @notice Generate constructor arguments for EscrowDst
     */
    function getEscrowDstArgs() external pure returns (bytes memory) {
        return abi.encode(RESCUE_DELAY, BMN_ACCESS_TOKEN_V2);
    }
}