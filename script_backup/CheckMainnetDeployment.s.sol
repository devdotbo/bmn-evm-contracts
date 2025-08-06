// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Script.sol";

interface ICREATE3 {
    function getDeployed(address deployer, bytes32 salt) external view returns (address);
}

contract CheckMainnetDeployment is Script {
    address constant CREATE3_FACTORY = 0x7B9e9BE124C5A0E239E04fDC93b66ead4e8C669d;
    address constant DEPLOYER = 0x5f29827e25dc174a6A51C99e6811Bbd7581285b0;
    
    function run() external view {
        // Production salts
        bytes32 srcSalt = keccak256("BMN-EscrowSrc-MAINNET-v1");
        bytes32 dstSalt = keccak256("BMN-EscrowDst-MAINNET-v1");
        bytes32 factorySalt = keccak256("BMN-Factory-MAINNET-v1");
        
        // Get addresses
        address srcImpl = ICREATE3(CREATE3_FACTORY).getDeployed(DEPLOYER, srcSalt);
        address dstImpl = ICREATE3(CREATE3_FACTORY).getDeployed(DEPLOYER, dstSalt);
        address factory = ICREATE3(CREATE3_FACTORY).getDeployed(DEPLOYER, factorySalt);
        
        console.log("========== MAINNET ADDRESSES ==========");
        console.log("Chain ID:", block.chainid);
        console.log("EscrowSrc:", srcImpl);
        console.log("EscrowDst:", dstImpl);
        console.log("Factory:", factory);
        console.log("");
        
        // Check deployment status
        console.log("========== DEPLOYMENT STATUS ==========");
        console.log("EscrowSrc:", srcImpl.code.length > 0 ? "DEPLOYED" : "NOT DEPLOYED");
        console.log("EscrowDst:", dstImpl.code.length > 0 ? "DEPLOYED" : "NOT DEPLOYED");
        console.log("Factory:", factory.code.length > 0 ? "DEPLOYED" : "NOT DEPLOYED");
        console.log("=======================================");
    }
}