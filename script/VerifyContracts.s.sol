// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { Script } from "forge-std/Script.sol";
import { console2 } from "forge-std/console2.sol";
import { Constants } from "../contracts/Constants.sol";

/**
 * @title VerifyContracts
 * @notice Script to help with contract verification on block explorers
 * @dev Provides constructor arguments encoding for manual verification
 */
contract VerifyContracts is Script {
    // Deployed contract addresses
    address constant ESCROW_FACTORY = 0x068aABdFa6B8c442CD32945A9A147B45ad7146d2;
    address constant ESCROW_SRC_IMPL = 0x8F92Da1e1B537003569B7293B8063e6e79f27Fc6;
    address constant ESCROW_DST_IMPL = 0xFd3114ef8B537003569b7293B8063E6e79f27FC6;
    
    // Constructor arguments
    address constant OWNER = Constants.BMN_DEPLOYER;
    address constant LIMIT_ORDER_PROTOCOL = address(0);
    address constant FEE_TOKEN = address(0);
    uint32 constant RESCUE_DELAY = 86400; // 1 day
    
    function run() external view {
        console2.log("=== Contract Verification Information ===");
        console2.log("");
        
        // BMN Token (external)
        console2.log("1. BMN Token (External)");
        console2.log("   Address:", Constants.BMN_TOKEN);
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
            Constants.BMN_TOKEN,
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
        bytes memory srcArgs = abi.encode(RESCUE_DELAY, Constants.BMN_TOKEN);
        console2.log("   ", vm.toString(srcArgs));
        console2.log("");
        
        // EscrowDst Implementation
        console2.log("4. EscrowDst Implementation");
        console2.log("   Address:", ESCROW_DST_IMPL);
        console2.log("   Constructor args (ABI encoded):");
        bytes memory dstArgs = abi.encode(RESCUE_DELAY, Constants.BMN_TOKEN);
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
     * @notice BMN Token is external - no constructor args needed for verification
     */
    
    /**
     * @notice Generate constructor arguments for EscrowFactory
     */
    function getEscrowFactoryArgs() external pure returns (bytes memory) {
        return abi.encode(
            LIMIT_ORDER_PROTOCOL,
            FEE_TOKEN,
            Constants.BMN_TOKEN,
            OWNER,
            RESCUE_DELAY,
            RESCUE_DELAY
        );
    }
    
    /**
     * @notice Generate constructor arguments for EscrowSrc
     */
    function getEscrowSrcArgs() external pure returns (bytes memory) {
        return abi.encode(RESCUE_DELAY, Constants.BMN_TOKEN);
    }
    
    /**
     * @notice Generate constructor arguments for EscrowDst
     */
    function getEscrowDstArgs() external pure returns (bytes memory) {
        return abi.encode(RESCUE_DELAY, Constants.BMN_TOKEN);
    }
}