// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import "../contracts/SimplifiedEscrowFactory.sol";
import "../contracts/EscrowSrc.sol";
import "../contracts/EscrowDst.sol";
import { ICREATE3Factory } from "create3-factory/ICREATE3Factory.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

/**
 * @title Deploy
 * @notice Deployment script for SimplifiedEscrowFactory
 * @dev Uses CREATE3 for deterministic cross-chain addresses
 */
contract Deploy is Script {
    // CREATE3 Factory address (same on all chains)
    address constant CREATE3_FACTORY = 0x7B9e9BE124C5A0E239E04fDC93b66ead4e8C669d;
    
    // Salt for deterministic deployment - change this for new deployments
    bytes32 constant SALT = keccak256("BMN_FACTORY");
    
    function run() external {
        // Get deployer private key from environment
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("Deployer:", deployer);
        console.log("Chain ID:", block.chainid);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy implementation contracts directly (not via CREATE3)
        // These will have different addresses per chain, which is fine
        uint32 rescueDelay = 7 days;
        address accessToken = address(0); // No access token for v3.0.2
        
        EscrowSrc escrowSrcImpl = new EscrowSrc(rescueDelay, IERC20(accessToken));
        EscrowDst escrowDstImpl = new EscrowDst(rescueDelay, IERC20(accessToken));
        
        console.log("EscrowSrc Implementation:", address(escrowSrcImpl));
        console.log("EscrowDst Implementation:", address(escrowDstImpl));
        
        // Prepare factory deployment bytecode
        bytes memory factoryBytecode = abi.encodePacked(
            type(SimplifiedEscrowFactory).creationCode,
            abi.encode(
                address(escrowSrcImpl),
                address(escrowDstImpl),
                deployer // owner
            )
        );
        
        // Deploy factory via CREATE3
        ICREATE3Factory create3 = ICREATE3Factory(CREATE3_FACTORY);
        address factory = create3.deploy(SALT, factoryBytecode);
        
        console.log("SimplifiedEscrowFactory deployed at:", factory);
        
        // Log configuration
        SimplifiedEscrowFactory deployedFactory = SimplifiedEscrowFactory(factory);
        console.log("Owner:", deployedFactory.owner());
        console.log("Whitelist Bypassed:", deployedFactory.whitelistBypassed());
        console.log("Emergency Paused:", deployedFactory.emergencyPaused());
        
        vm.stopBroadcast();
        
        console.log("\nDeployment complete!");
        console.log("Factory is ready for use at:", factory);
        console.log("\nResolver Integration:");
        console.log("- Resolvers must read block.timestamp from event blocks");
        console.log("- See deployments/deployment.md for integration instructions");
    }
    
    /**
     * @notice Verify deployment by checking a specific factory address
     * @dev Pass the factory address as an environment variable FACTORY_ADDRESS
     */
    function verify() external view {
        address factoryAddress = vm.envAddress("FACTORY_ADDRESS");
        
        // Check factory exists
        require(factoryAddress.code.length > 0, "Factory not deployed");
        
        SimplifiedEscrowFactory factory = SimplifiedEscrowFactory(factoryAddress);
        
        // Verify implementations are set
        require(factory.ESCROW_SRC_IMPLEMENTATION() != address(0), "Src implementation not set");
        require(factory.ESCROW_DST_IMPLEMENTATION() != address(0), "Dst implementation not set");
        
        console.log("Verification passed!");
        console.log("Factory:", factoryAddress);
        console.log("Src Implementation:", factory.ESCROW_SRC_IMPLEMENTATION());
        console.log("Dst Implementation:", factory.ESCROW_DST_IMPLEMENTATION());
        console.log("Owner:", factory.owner());
    }
}