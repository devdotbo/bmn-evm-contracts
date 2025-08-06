// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import { EscrowSrc } from "../contracts/EscrowSrc.sol";
import { EscrowDst } from "../contracts/EscrowDst.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

interface ICREATE3 {
    function deploy(bytes32 salt, bytes calldata bytecode) external payable returns (address);
    function getDeployed(address deployer, bytes32 salt) external view returns (address);
}

contract DeployStep1Implementations is Script {
    address constant CREATE3_FACTORY = 0x7B9e9BE124C5A0E239E04fDC93b66ead4e8C669d;
    bytes32 constant SRC_SALT = keccak256("BMN-EscrowSrc-MAINNET-v1");
    bytes32 constant DST_SALT = keccak256("BMN-EscrowDst-MAINNET-v1");
    address constant BMN_TOKEN = 0x8287CD2aC7E227D9D927F998EB600a0683a832A1;
    uint32 constant RESCUE_DELAY = 7 days;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("[STEP 1: DEPLOY IMPLEMENTATIONS]");
        console.log("Chain ID:", block.chainid);
        console.log("Deployer:", deployer);
        
        address srcAddr = ICREATE3(CREATE3_FACTORY).getDeployed(deployer, SRC_SALT);
        address dstAddr = ICREATE3(CREATE3_FACTORY).getDeployed(deployer, DST_SALT);
        
        console.log("\nTarget addresses:");
        console.log("EscrowSrc:", srcAddr);
        console.log("EscrowDst:", dstAddr);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy EscrowSrc
        if (srcAddr.code.length == 0) {
            console.log("\nDeploying EscrowSrc...");
            bytes memory srcCode = abi.encodePacked(
                type(EscrowSrc).creationCode,
                abi.encode(RESCUE_DELAY, IERC20(BMN_TOKEN))
            );
            address deployed = ICREATE3(CREATE3_FACTORY).deploy(SRC_SALT, srcCode);
            console.log("[DEPLOYED] EscrowSrc:", deployed);
            require(deployed == srcAddr, "Address mismatch");
        } else {
            console.log("EscrowSrc already deployed");
        }
        
        // Deploy EscrowDst
        if (dstAddr.code.length == 0) {
            console.log("\nDeploying EscrowDst...");
            bytes memory dstCode = abi.encodePacked(
                type(EscrowDst).creationCode,
                abi.encode(RESCUE_DELAY, IERC20(BMN_TOKEN))
            );
            address deployed = ICREATE3(CREATE3_FACTORY).deploy(DST_SALT, dstCode);
            console.log("[DEPLOYED] EscrowDst:", deployed);
            require(deployed == dstAddr, "Address mismatch");
        } else {
            console.log("EscrowDst already deployed");
        }
        
        vm.stopBroadcast();
        
        console.log("\n[COMPLETE] Implementations ready");
        console.log("EscrowSrc:", srcAddr);
        console.log("EscrowDst:", dstAddr);
    }
}