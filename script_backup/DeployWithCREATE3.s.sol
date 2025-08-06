// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import { EscrowSrc } from "../contracts/EscrowSrc.sol";
import { EscrowDst } from "../contracts/EscrowDst.sol";
import { CrossChainEscrowFactory } from "../contracts/CrossChainEscrowFactory.sol";
import { Constants } from "../contracts/Constants.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

// CREATE3 Factory interface - selector 0xcdcb760a for deploy, 0x50f1c464 for getDeployed
interface ICREATE3 {
    function deploy(bytes32 salt, bytes calldata bytecode) external payable returns (address);
    function getDeployed(address deployer, bytes32 salt) external view returns (address);
}

/**
 * @title DeployWithCREATE3
 * @notice Deploy BMN protocol contracts using CREATE3 for cross-chain consistency
 * @dev Uses verified CREATE3 factory at 0x7B9e9BE124C5A0E239E04fDC93b66ead4e8C669d
 */
contract DeployWithCREATE3 is Script {
    // CREATE3 factory deployed on both Base and Etherlink
    address constant CREATE3_FACTORY = 0x7B9e9BE124C5A0E239E04fDC93b66ead4e8C669d;
    
    // Deterministic salts for cross-chain consistency
    bytes32 constant SRC_IMPL_SALT = keccak256("BMN-EscrowSrc-v1.0.0");
    bytes32 constant DST_IMPL_SALT = keccak256("BMN-EscrowDst-v1.0.0");
    bytes32 constant FACTORY_SALT = keccak256("BMN-CrossChainEscrowFactory-v1.0.0");
    
    // Known mainnet addresses
    address constant LIMIT_ORDER_PROTOCOL = 0x1111111254EEB25477B68fb85Ed929f73A960582;
    address constant FEE_TOKEN = Constants.BMN_TOKEN;
    address constant ACCESS_TOKEN = Constants.BMN_TOKEN;
    
    // Deployment results
    address public srcImplementation;
    address public dstImplementation;
    address public factory;
    
    function run() external {
        // Load deployer from environment
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("Deploying BMN Protocol with CREATE3");
        console.log("=====================================");
        console.log("Deployer:", deployer);
        console.log("Chain ID:", block.chainid);
        console.log("CREATE3 Factory:", CREATE3_FACTORY);
        
        // Predict addresses
        srcImplementation = ICREATE3(CREATE3_FACTORY).getDeployed(deployer, SRC_IMPL_SALT);
        dstImplementation = ICREATE3(CREATE3_FACTORY).getDeployed(deployer, DST_IMPL_SALT);
        factory = ICREATE3(CREATE3_FACTORY).getDeployed(deployer, FACTORY_SALT);
        
        console.log("\nPredicted addresses:");
        console.log("SRC Implementation:", srcImplementation);
        console.log("DST Implementation:", dstImplementation);
        console.log("Factory:", factory);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy implementations
        if (srcImplementation.code.length == 0) {
            console.log("\nDeploying EscrowSrc implementation...");
            bytes memory srcBytecode = abi.encodePacked(
                type(EscrowSrc).creationCode,
                abi.encode(604800, IERC20(ACCESS_TOKEN)) // 7 days rescue delay
            );
            
            address deployedSrc = ICREATE3(CREATE3_FACTORY).deploy(SRC_IMPL_SALT, srcBytecode);
            require(deployedSrc == srcImplementation, "SRC implementation address mismatch");
            console.log("EscrowSrc deployed at:", deployedSrc);
        } else {
            console.log("EscrowSrc already deployed at:", srcImplementation);
        }
        
        if (dstImplementation.code.length == 0) {
            console.log("\nDeploying EscrowDst implementation...");
            bytes memory dstBytecode = abi.encodePacked(
                type(EscrowDst).creationCode,
                abi.encode(604800, IERC20(ACCESS_TOKEN)) // 7 days rescue delay
            );
            
            address deployedDst = ICREATE3(CREATE3_FACTORY).deploy(DST_IMPL_SALT, dstBytecode);
            require(deployedDst == dstImplementation, "DST implementation address mismatch");
            console.log("EscrowDst deployed at:", deployedDst);
        } else {
            console.log("EscrowDst already deployed at:", dstImplementation);
        }
        
        // Deploy factory
        if (factory.code.length == 0) {
            console.log("\nDeploying CrossChainEscrowFactory...");
            bytes memory factoryBytecode = abi.encodePacked(
                type(CrossChainEscrowFactory).creationCode,
                abi.encode(
                    LIMIT_ORDER_PROTOCOL,
                    IERC20(FEE_TOKEN),
                    IERC20(ACCESS_TOKEN),
                    deployer, // owner
                    srcImplementation,
                    dstImplementation
                )
            );
            
            address deployedFactory = ICREATE3(CREATE3_FACTORY).deploy(FACTORY_SALT, factoryBytecode);
            require(deployedFactory == factory, "Factory address mismatch");
            console.log("CrossChainEscrowFactory deployed at:", deployedFactory);
        } else {
            console.log("CrossChainEscrowFactory already deployed at:", factory);
        }
        
        vm.stopBroadcast();
        
        // Save deployment info
        string memory deploymentInfo = string(abi.encodePacked(
            "# BMN Protocol CREATE3 Deployment\n",
            "CHAIN_ID=", vm.toString(block.chainid), "\n",
            "CREATE3_FACTORY=", vm.toString(CREATE3_FACTORY), "\n",
            "SRC_IMPLEMENTATION=", vm.toString(srcImplementation), "\n",
            "DST_IMPLEMENTATION=", vm.toString(dstImplementation), "\n",
            "FACTORY=", vm.toString(factory), "\n",
            "DEPLOYER=", vm.toString(deployer), "\n"
        ));
        
        string memory filename = string(abi.encodePacked(
            "deployments/create3-",
            vm.toString(block.chainid),
            ".env"
        ));
        
        vm.writeFile(filename, deploymentInfo);
        console.log("\nDeployment info saved to:", filename);
        console.log("\n=== Deployment Complete ===");
    }
}