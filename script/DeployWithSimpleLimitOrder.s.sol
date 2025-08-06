// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import "../contracts/CrossChainEscrowFactory.sol";
import "../contracts/EscrowSrc.sol";
import "../contracts/EscrowDst.sol";
import "../contracts/test/TokenMock.sol";

interface ICREATE3Factory {
    function deploy(bytes32 salt, bytes memory creationCode) external payable returns (address deployed);
    function getDeployed(address deployer, bytes32 salt) external view returns (address deployed);
}

contract DeployWithSimpleLimitOrder is Script {
    // CREATE3 Factory deployed on all chains at same address
    ICREATE3Factory constant CREATE3_FACTORY = ICREATE3Factory(0x7B9e9BE124C5A0E239E04fDC93b66ead4e8C669d);
    
    // SimpleLimitOrderProtocol addresses (your deployed contracts)
    address constant SIMPLE_LIMIT_ORDER_OPTIMISM = 0x44716439C19c2E8BD6E1bCB5556ed4C31dA8cDc7;
    address constant SIMPLE_LIMIT_ORDER_BASE = 0x1c1A74b677A28ff92f4AbF874b3Aa6dE864D3f06;
    
    // BMN Token address (same on all chains)
    address constant BMN_TOKEN = 0x8287CD2aC7E227D9D927F998EB600a0683a832A1;
    
    // Salts for deterministic deployment
    bytes32 constant SALT_ESCROW_SRC = keccak256("BMN_ESCROW_SRC_V2");
    bytes32 constant SALT_ESCROW_DST = keccak256("BMN_ESCROW_DST_V2");
    bytes32 constant SALT_FACTORY = keccak256("BMN_FACTORY_SIMPLE_LIMIT_ORDER_V2");
    
    function run() external {
        uint256 deployerKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);
        
        // Determine chain and select correct limit order protocol
        uint256 chainId = block.chainid;
        address limitOrderProtocol;
        string memory chainName;
        
        if (chainId == 10) {
            limitOrderProtocol = SIMPLE_LIMIT_ORDER_OPTIMISM;
            chainName = "Optimism";
        } else if (chainId == 8453) {
            limitOrderProtocol = SIMPLE_LIMIT_ORDER_BASE;
            chainName = "Base";
        } else if (chainId == 42793) {
            // Etherlink - needs deployment of SimpleLimitOrderProtocol first
            revert("SimpleLimitOrderProtocol not yet deployed on Etherlink");
        } else {
            revert("Unsupported chain");
        }
        
        console.log("========================================");
        console.log("Deploying with SimpleLimitOrderProtocol");
        console.log("========================================");
        console.log("Chain:", chainName);
        console.log("Chain ID:", chainId);
        console.log("Deployer:", deployer);
        console.log("SimpleLimitOrderProtocol:", limitOrderProtocol);
        console.log("BMN Token:", BMN_TOKEN);
        
        vm.startBroadcast(deployerKey);
        
        // Deploy EscrowSrc implementation
        address escrowSrcPredicted = CREATE3_FACTORY.getDeployed(deployer, SALT_ESCROW_SRC);
        console.log("\nDeploying EscrowSrc implementation...");
        console.log("Predicted address:", escrowSrcPredicted);
        
        address escrowSrc = CREATE3_FACTORY.deploy(
            SALT_ESCROW_SRC,
            type(EscrowSrc).creationCode
        );
        console.log("EscrowSrc deployed at:", escrowSrc);
        
        // Deploy EscrowDst implementation
        address escrowDstPredicted = CREATE3_FACTORY.getDeployed(deployer, SALT_ESCROW_DST);
        console.log("\nDeploying EscrowDst implementation...");
        console.log("Predicted address:", escrowDstPredicted);
        
        address escrowDst = CREATE3_FACTORY.deploy(
            SALT_ESCROW_DST,
            type(EscrowDst).creationCode
        );
        console.log("EscrowDst deployed at:", escrowDst);
        
        // Deploy CrossChainEscrowFactory with SimpleLimitOrderProtocol
        address factoryPredicted = CREATE3_FACTORY.getDeployed(deployer, SALT_FACTORY);
        console.log("\nDeploying CrossChainEscrowFactory...");
        console.log("Predicted address:", factoryPredicted);
        
        bytes memory factoryBytecode = abi.encodePacked(
            type(CrossChainEscrowFactory).creationCode,
            abi.encode(
                limitOrderProtocol,    // SimpleLimitOrderProtocol address
                IERC20(BMN_TOKEN),     // Fee token
                IERC20(BMN_TOKEN),     // Access token (same as fee token)
                deployer,              // Owner
                escrowSrc,             // Source escrow implementation
                escrowDst              // Destination escrow implementation
            )
        );
        
        address factory = CREATE3_FACTORY.deploy(
            SALT_FACTORY,
            factoryBytecode
        );
        
        console.log("CrossChainEscrowFactory deployed at:", factory);
        
        vm.stopBroadcast();
        
        console.log("\n========================================");
        console.log("DEPLOYMENT SUCCESSFUL!");
        console.log("========================================");
        console.log("EscrowSrc Implementation:", escrowSrc);
        console.log("EscrowDst Implementation:", escrowDst);
        console.log("CrossChainEscrowFactory:", factory);
        console.log("SimpleLimitOrderProtocol:", limitOrderProtocol);
        console.log("\nNext steps:");
        console.log("1. Verify contracts on block explorer");
        console.log("2. Update resolver configuration with new factory address");
        console.log("3. Test integration with SimpleLimitOrderProtocol");
        console.log("4. Deploy to other chains with same salts");
    }
}