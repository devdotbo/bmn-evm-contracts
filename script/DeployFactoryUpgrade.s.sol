// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import { EscrowSrc } from "../contracts/EscrowSrc.sol";
import { EscrowDst } from "../contracts/EscrowDst.sol";
import { CrossChainEscrowFactory } from "../contracts/CrossChainEscrowFactory.sol";
import { Constants } from "../contracts/Constants.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

// CREATE3 Factory interface
interface ICREATE3 {
    function deploy(bytes32 salt, bytes calldata bytecode) external payable returns (address);
    function getDeployed(address deployer, bytes32 salt) external view returns (address);
}

/**
 * @title DeployFactoryUpgrade
 * @notice Deploy upgraded CrossChainEscrowFactory with enhanced events for direct escrow address emission
 * @dev This upgrade enables Ponder indexer to work efficiently on Etherlink by avoiding factory pattern
 */
contract DeployFactoryUpgrade is Script {
    // CREATE3 factory deployed on both Base and Etherlink
    address constant CREATE3_FACTORY = 0x7B9e9BE124C5A0E239E04fDC93b66ead4e8C669d;
    
    // Updated salt for the new factory version (v1.1.0 includes event enhancement)
    bytes32 constant FACTORY_SALT = keccak256("BMN-CrossChainEscrowFactory-v1.1.0-EventEnhanced");
    
    // Existing implementation addresses (reuse from v1.0.0 deployment)
    address constant SRC_IMPLEMENTATION = 0x77CC1A51dC5855bcF0d9f1c1FceaeE7fb855a535;
    address constant DST_IMPLEMENTATION = 0x36938b7899A17362520AA741C0E0dA0c8EfE5e3b;
    
    // Known mainnet addresses
    address constant LIMIT_ORDER_PROTOCOL = 0x1111111254EEB25477B68fb85Ed929f73A960582;
    address constant FEE_TOKEN = Constants.BMN_TOKEN;
    address constant ACCESS_TOKEN = Constants.BMN_TOKEN;
    
    // Chain configuration
    uint256 constant BASE_CHAIN_ID = 8453;
    uint256 constant ETHERLINK_CHAIN_ID = 42793;
    
    // Deployment result
    address public upgradedFactory;
    
    function run() external {
        // Load deployer from environment
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        // Deploying Factory Event Enhancement Upgrade
        // Deployer and chain info logged by forge
        
        // Validate chain
        require(
            block.chainid == BASE_CHAIN_ID || block.chainid == ETHERLINK_CHAIN_ID,
            "Invalid chain - must be Base or Etherlink mainnet"
        );
        
        string memory chainName = block.chainid == BASE_CHAIN_ID ? "Base" : "Etherlink";
        
        // Predict factory address
        upgradedFactory = ICREATE3(CREATE3_FACTORY).getDeployed(deployer, FACTORY_SALT);
        // Predicted upgraded factory address calculated
        
        // Check if already deployed
        if (upgradedFactory.code.length > 0) {
            // Upgraded factory already deployed, skipping
            _verifyDeployment();
            return;
        }
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy upgraded factory with enhanced events
        // Deploying upgraded CrossChainEscrowFactory
        // Using existing implementations
        
        bytes memory factoryBytecode = abi.encodePacked(
            type(CrossChainEscrowFactory).creationCode,
            abi.encode(
                LIMIT_ORDER_PROTOCOL,
                IERC20(FEE_TOKEN),
                IERC20(ACCESS_TOKEN),
                deployer, // owner
                SRC_IMPLEMENTATION,
                DST_IMPLEMENTATION
            )
        );
        
        address deployedFactory = ICREATE3(CREATE3_FACTORY).deploy(FACTORY_SALT, factoryBytecode);
        require(deployedFactory == upgradedFactory, "Factory address mismatch");
        
        // Upgraded CrossChainEscrowFactory deployed successfully
        // Transaction hash logged by forge automatically
        
        vm.stopBroadcast();
        
        // Verify deployment
        _verifyDeployment();
        
        // Save deployment info
        _saveDeploymentInfo(deployer);
        
        // Factory Upgrade Deployment Complete
        // Next steps:
        // 1. Verify contract on block explorer
        // 2. Test event emission with sample transaction  
        // 3. Update indexer to use new factory address
        // 4. Monitor event processing
    }
    
    function _verifyDeployment() private view {
        // Verifying deployment...
        
        // Check factory code exists
        require(upgradedFactory.code.length > 0, "Factory not deployed");
        // Factory has code
        
        // Verify factory can access implementations
        CrossChainEscrowFactory factory = CrossChainEscrowFactory(upgradedFactory);
        
        // These are public immutable variables in BaseEscrowFactory
        address srcImpl = address(factory.ESCROW_SRC_IMPLEMENTATION());
        address dstImpl = address(factory.ESCROW_DST_IMPLEMENTATION());
        
        require(srcImpl == SRC_IMPLEMENTATION, "Invalid SRC implementation");
        require(dstImpl == DST_IMPLEMENTATION, "Invalid DST implementation");
        
        // Factory correctly references implementations
        // Deployment verification passed
    }
    
    function _saveDeploymentInfo(address deployer) private {
        string memory chainName = block.chainid == BASE_CHAIN_ID ? "base" : "etherlink";
        
        string memory deploymentInfo = string(abi.encodePacked(
            "# BMN Factory Event Enhancement Upgrade\n",
            "# Deployed: ", vm.toString(block.timestamp), "\n",
            "CHAIN_ID=", vm.toString(block.chainid), "\n",
            "CHAIN_NAME=", chainName, "\n",
            "CREATE3_FACTORY=", vm.toString(CREATE3_FACTORY), "\n",
            "UPGRADED_FACTORY=", vm.toString(upgradedFactory), "\n",
            "SRC_IMPLEMENTATION=", vm.toString(SRC_IMPLEMENTATION), "\n",
            "DST_IMPLEMENTATION=", vm.toString(DST_IMPLEMENTATION), "\n",
            "DEPLOYER=", vm.toString(deployer), "\n",
            "FACTORY_SALT=", vm.toString(FACTORY_SALT), "\n"
        ));
        
        string memory filename = string(abi.encodePacked(
            "deployments/factory-upgrade-",
            chainName,
            "-",
            vm.toString(block.timestamp),
            ".env"
        ));
        
        vm.writeFile(filename, deploymentInfo);
        // Deployment info saved
        
        // Also update a latest symlink
        string memory latestFilename = string(abi.encodePacked(
            "deployments/factory-upgrade-",
            chainName,
            "-latest.env"
        ));
        
        vm.writeFile(latestFilename, deploymentInfo);
        // Latest deployment info saved
    }
}