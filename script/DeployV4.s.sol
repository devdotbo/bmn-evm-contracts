// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import "../contracts/SimplifiedEscrowFactoryV4.sol";
import "../test/mocks/MockLimitOrderProtocol.sol";
import { ICREATE3Factory } from "create3-factory/ICREATE3Factory.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

/**
 * @title DeployV4
 * @notice Deployment script for SimplifiedEscrowFactoryV4 with 1inch integration
 * @dev Uses constructor-based implementation deployment and SimpleSettlement inheritance
 */
contract DeployV4 is Script {
    // CREATE3 Factory address (same on all chains) - for factory deployment only
    address constant CREATE3_FACTORY = 0x7B9e9BE124C5A0E239E04fDC93b66ead4e8C669d;
    
    // Salt for deterministic factory deployment - change this for new deployments
    bytes32 constant SALT = keccak256("BMN_FACTORY_V4");
    
    // Configuration struct for deployment parameters
    struct DeployConfig {
        address limitOrderProtocol;
        address owner;
        uint32 rescueDelay;
        address accessToken;
        address weth;
        bool useMockProtocol;
        bool useCreate3;
    }
    
    function run() external {
        // Get deployer private key from environment
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("=== SimplifiedEscrowFactoryV4 Deployment ===");
        console.log("Deployer:", deployer);
        console.log("Chain ID:", block.chainid);
        
        // Load configuration
        DeployConfig memory config = getDeployConfig(deployer);
        
        console.log("\nConfiguration:");
        console.log("- Limit Order Protocol:", config.limitOrderProtocol);
        console.log("- Owner:", config.owner);
        console.log("- Rescue Delay:", config.rescueDelay, "seconds");
        console.log("- Access Token:", config.accessToken);
        console.log("- WETH:", config.weth);
        console.log("- Using Mock Protocol:", config.useMockProtocol);
        console.log("- Using CREATE3:", config.useCreate3);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy mock LimitOrderProtocol if needed (for testing)
        if (config.useMockProtocol) {
            MockLimitOrderProtocol mockProtocol = new MockLimitOrderProtocol();
            config.limitOrderProtocol = address(mockProtocol);
            console.log("\nDeployed MockLimitOrderProtocol at:", config.limitOrderProtocol);
        }
        
        address payable factory;
        
        if (config.useCreate3) {
            // Deploy factory via CREATE3 for deterministic address
            factory = payable(deployWithCreate3(config));
        } else {
            // Direct deployment (for local testing)
            factory = payable(deployDirect(config));
        }
        
        // Verify deployment
        verifyDeployment(factory);
        
        vm.stopBroadcast();
        
        // Log deployment summary
        logDeploymentSummary(factory, config);
    }
    
    /**
     * @notice Deploy factory using CREATE3 for deterministic address
     */
    function deployWithCreate3(DeployConfig memory config) internal returns (address) {
        console.log("\nDeploying with CREATE3...");
        
        // Prepare factory deployment bytecode
        bytes memory factoryBytecode = abi.encodePacked(
            type(SimplifiedEscrowFactoryV4).creationCode,
            abi.encode(
                config.limitOrderProtocol,
                config.owner,
                config.rescueDelay,
                IERC20(config.accessToken),
                config.weth
            )
        );
        
        // Deploy factory via CREATE3
        ICREATE3Factory create3 = ICREATE3Factory(CREATE3_FACTORY);
        address factory = create3.deploy(SALT, factoryBytecode);
        
        console.log("Factory deployed via CREATE3 at:", factory);
        return factory;
    }
    
    /**
     * @notice Deploy factory directly without CREATE3
     */
    function deployDirect(DeployConfig memory config) internal returns (address) {
        console.log("\nDeploying directly...");
        
        SimplifiedEscrowFactoryV4 factory = new SimplifiedEscrowFactoryV4(
            config.limitOrderProtocol,
            config.owner,
            config.rescueDelay,
            IERC20(config.accessToken),
            config.weth
        );
        
        console.log("Factory deployed directly at:", address(factory));
        return address(factory);
    }
    
    /**
     * @notice Get deployment configuration based on chain and environment
     */
    function getDeployConfig(address deployer) internal view returns (DeployConfig memory) {
        DeployConfig memory config;
        
        // Default configuration
        config.owner = deployer;
        config.rescueDelay = 7 days;
        
        // Check for environment variable overrides
        config.rescueDelay = uint32(vm.envOr("RESCUE_DELAY", uint256(config.rescueDelay)));
        
        // Chain-specific configuration
        if (block.chainid == 1) {
            // Mainnet
            config.limitOrderProtocol = vm.envOr("LIMIT_ORDER_PROTOCOL", address(0x119c71D3BbAC22029622cbaEc24854d3D32D2828)); // 1inch v4
            config.weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
            config.accessToken = address(0); // No access token on mainnet
            config.useMockProtocol = false;
            config.useCreate3 = true;
        } else if (block.chainid == 10) {
            // Optimism
            config.limitOrderProtocol = vm.envOr("LIMIT_ORDER_PROTOCOL", address(0x119c71D3BbAC22029622cbaEc24854d3D32D2828)); // 1inch v4
            config.weth = 0x4200000000000000000000000000000000000006;
            config.accessToken = address(0);
            config.useMockProtocol = false;
            config.useCreate3 = true;
        } else if (block.chainid == 8453) {
            // Base
            config.limitOrderProtocol = vm.envOr("LIMIT_ORDER_PROTOCOL", address(0x119c71D3BbAC22029622cbaEc24854d3D32D2828)); // 1inch v4
            config.weth = 0x4200000000000000000000000000000000000006;
            config.accessToken = address(0);
            config.useMockProtocol = false;
            config.useCreate3 = true;
        } else if (block.chainid == 31337) {
            // Local Anvil - use mock protocol
            config.limitOrderProtocol = address(0); // Will deploy mock
            config.weth = address(0); // No WETH needed for testing
            config.accessToken = address(0); // No access token for testing
            config.useMockProtocol = true;
            config.useCreate3 = vm.envOr("USE_CREATE3", false);
        } else {
            // Other chains - use environment variables
            config.limitOrderProtocol = vm.envAddress("LIMIT_ORDER_PROTOCOL");
            config.weth = vm.envOr("WETH", address(0));
            config.accessToken = vm.envOr("ACCESS_TOKEN", address(0));
            config.useMockProtocol = vm.envOr("USE_MOCK_PROTOCOL", false);
            config.useCreate3 = vm.envOr("USE_CREATE3", true);
        }
        
        // Allow override from environment
        config.owner = vm.envOr("OWNER", config.owner);
        
        return config;
    }
    
    /**
     * @notice Verify the deployment was successful
     */
    function verifyDeployment(address payable factoryAddress) internal view {
        require(factoryAddress.code.length > 0, "Factory not deployed");
        
        SimplifiedEscrowFactoryV4 factory = SimplifiedEscrowFactoryV4(factoryAddress);
        
        // Verify implementations are set
        require(factory.ESCROW_SRC_IMPLEMENTATION() != address(0), "Src implementation not set");
        require(factory.ESCROW_DST_IMPLEMENTATION() != address(0), "Dst implementation not set");
        
        // Verify proxy bytecode hashes are set
        require(factory.ESCROW_SRC_PROXY_BYTECODE_HASH() != bytes32(0), "Src proxy hash not set");
        require(factory.ESCROW_DST_PROXY_BYTECODE_HASH() != bytes32(0), "Dst proxy hash not set");
        
        console.log("\nDeployment verification passed!");
    }
    
    /**
     * @notice Log deployment summary for documentation
     */
    function logDeploymentSummary(address payable factory, DeployConfig memory config) internal view {
        SimplifiedEscrowFactoryV4 deployedFactory = SimplifiedEscrowFactoryV4(factory);
        
        console.log("\n=== Deployment Complete ===");
        console.log("\nContract Addresses:");
        console.log("- Factory:", factory);
        console.log("- Src Implementation:", deployedFactory.ESCROW_SRC_IMPLEMENTATION());
        console.log("- Dst Implementation:", deployedFactory.ESCROW_DST_IMPLEMENTATION());
        if (config.useMockProtocol) {
            console.log("- Mock Protocol:", config.limitOrderProtocol);
        }
        
        console.log("\nConfiguration:");
        console.log("- Owner:", deployedFactory.owner());
        console.log("- Whitelist Bypassed:", deployedFactory.whitelistBypassed());
        console.log("- Emergency Paused:", deployedFactory.emergencyPaused());
        console.log("- Resolver Count:", deployedFactory.resolverCount());
        
        console.log("\nProxy Bytecode Hashes:");
        console.log("- Src:", vm.toString(deployedFactory.ESCROW_SRC_PROXY_BYTECODE_HASH()));
        console.log("- Dst:", vm.toString(deployedFactory.ESCROW_DST_PROXY_BYTECODE_HASH()));
        
        console.log("\n1inch Integration:");
        console.log("- SimpleSettlement inheritance active");
        console.log("- postInteraction() entry point ready");
        console.log("- Limit Order Protocol:", config.limitOrderProtocol);
        
        console.log("\nResolver Integration:");
        console.log("- Resolvers must approve factory for token transfers");
        console.log("- Resolvers must read block.timestamp from event blocks");
        console.log("- See docs/V4.0-COMPLETE-ANALYSIS.md for integration guide");
        
        console.log("\nVerification Commands:");
        if (block.chainid == 8453) {
            console.log("forge verify-contract --watch \\");
            console.log("  --chain base \\");
            console.log("  ", factory, " \\");
            console.log("  contracts/SimplifiedEscrowFactoryV4.sol:SimplifiedEscrowFactoryV4 \\");
            console.log("  --constructor-args $(cast abi-encode \"constructor(address,address,uint32,address,address)\" ...) \\");
            console.log("  Args:", config.limitOrderProtocol, config.owner);
            console.log("       ", config.rescueDelay, config.accessToken, config.weth);
            console.log("  --verifier etherscan \\");
            console.log("  --etherscan-api-key $BASESCAN_API_KEY");
        } else if (block.chainid == 10) {
            console.log("forge verify-contract --watch \\");
            console.log("  --chain optimism \\");
            console.log("  ", factory, " \\");
            console.log("  contracts/SimplifiedEscrowFactoryV4.sol:SimplifiedEscrowFactoryV4 \\");
            console.log("  --constructor-args $(cast abi-encode \"constructor(address,address,uint32,address,address)\" ...) \\");
            console.log("  Args:", config.limitOrderProtocol, config.owner);
            console.log("       ", config.rescueDelay, config.accessToken, config.weth);
            console.log("  --verifier etherscan \\");
            console.log("  --etherscan-api-key $OPTIMISM_ETHERSCAN_API_KEY");
        }
    }
    
    /**
     * @notice Verify existing deployment
     * @dev Run with: FACTORY_ADDRESS=0x... forge script script/DeployV4.s.sol:DeployV4 --sig "verify()"
     */
    function verify() external view {
        address payable factoryAddress = payable(vm.envAddress("FACTORY_ADDRESS"));
        
        console.log("=== Verifying SimplifiedEscrowFactoryV4 ===");
        console.log("Factory Address:", factoryAddress);
        
        // Check factory exists
        require(factoryAddress.code.length > 0, "Factory not deployed at this address");
        
        SimplifiedEscrowFactoryV4 factory = SimplifiedEscrowFactoryV4(factoryAddress);
        
        // Basic checks
        console.log("\nBasic Configuration:");
        console.log("- Owner:", factory.owner());
        console.log("- Whitelist Bypassed:", factory.whitelistBypassed());
        console.log("- Emergency Paused:", factory.emergencyPaused());
        
        // Implementation checks
        console.log("\nImplementations:");
        console.log("- Src Implementation:", factory.ESCROW_SRC_IMPLEMENTATION());
        console.log("- Dst Implementation:", factory.ESCROW_DST_IMPLEMENTATION());
        
        require(factory.ESCROW_SRC_IMPLEMENTATION() != address(0), "Src implementation not set");
        require(factory.ESCROW_DST_IMPLEMENTATION() != address(0), "Dst implementation not set");
        
        // Proxy bytecode hashes
        console.log("\nProxy Bytecode Hashes:");
        console.log("- Src:", vm.toString(factory.ESCROW_SRC_PROXY_BYTECODE_HASH()));
        console.log("- Dst:", vm.toString(factory.ESCROW_DST_PROXY_BYTECODE_HASH()));
        
        require(factory.ESCROW_SRC_PROXY_BYTECODE_HASH() != bytes32(0), "Src proxy hash not set");
        require(factory.ESCROW_DST_PROXY_BYTECODE_HASH() != bytes32(0), "Dst proxy hash not set");
        
        console.log("\nVerification passed!");
    }
}