// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import "../contracts/SimplifiedEscrowFactory.sol";
import "../contracts/EscrowSrc.sol";
import "../contracts/EscrowDst.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

/**
 * @title DeploySecureFactory
 * @notice Deployment script for secured factory on mainnet
 * @dev Deploy with: forge script script/DeploySecureFactory.s.sol --rpc-url $RPC_URL --broadcast
 */
contract DeploySecureFactory is Script {
    // Deployment configuration
    struct DeployConfig {
        address owner;
        address[] initialResolvers;
        uint32 rescueDelaySrc;
        uint32 rescueDelayDst;
        address bmnToken;
    }
    
    // Chain configurations
    mapping(uint256 => DeployConfig) public configs;
    
    // Deployed addresses
    address public escrowSrcImpl;
    address public escrowDstImpl;
    address public factory;
    
    function setUp() public {
        // Base mainnet configuration
        configs[8453] = DeployConfig({
            owner: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266, // Update with actual owner
            initialResolvers: new address[](1),
            rescueDelaySrc: 7 days,
            rescueDelayDst: 7 days,
            bmnToken: 0x8287CD2aC7E227D9D927F998EB600a0683a832A1 // BMN token on Base
        });
        configs[8453].initialResolvers[0] = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
        
        // Optimism mainnet configuration
        configs[10] = DeployConfig({
            owner: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266, // Update with actual owner
            initialResolvers: new address[](1),
            rescueDelaySrc: 7 days,
            rescueDelayDst: 7 days,
            bmnToken: 0x8287CD2aC7E227D9D927F998EB600a0683a832A1 // BMN token on Optimism
        });
        configs[10].initialResolvers[0] = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
        
        // Etherlink mainnet configuration (chain ID 42793)
        configs[42793] = DeployConfig({
            owner: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266, // Update with actual owner
            initialResolvers: new address[](1),
            rescueDelaySrc: 7 days,
            rescueDelayDst: 7 days,
            bmnToken: 0x8287CD2aC7E227D9D927F998EB600a0683a832A1 // BMN token on Etherlink
        });
        configs[42793].initialResolvers[0] = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
        
        // Local test configuration
        configs[31337] = DeployConfig({
            owner: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266, // Anvil account 0
            initialResolvers: new address[](2),
            rescueDelaySrc: 1 hours,
            rescueDelayDst: 1 hours,
            bmnToken: address(0) // Will deploy mock token for local
        });
        configs[31337].initialResolvers[0] = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
        configs[31337].initialResolvers[1] = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC; // Bob
    }
    
    function run() public {
        uint256 chainId = block.chainid;
        DeployConfig memory config = configs[chainId];
        
        require(config.owner != address(0), "Chain not configured");
        
        // Get deployer private key from environment
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        
        console.log("=== BMN Secure Factory Deployment ===");
        console.log("Chain ID:", chainId);
        console.log("Owner:", config.owner);
        console.log("BMN Token:", config.bmnToken);
        console.log("");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy BMN token mock if local
        if (chainId == 31337 && config.bmnToken == address(0)) {
            // Deploy a simple mock token for testing
            MockERC20 mockBMN = new MockERC20("BMN Token", "BMN");
            config.bmnToken = address(mockBMN);
            console.log("Deployed Mock BMN Token:", config.bmnToken);
        }
        
        // Deploy escrow implementations
        console.log("Deploying escrow implementations...");
        
        escrowSrcImpl = address(new EscrowSrc(
            config.rescueDelaySrc,
            IERC20(config.bmnToken)
        ));
        console.log("EscrowSrc Implementation:", escrowSrcImpl);
        
        escrowDstImpl = address(new EscrowDst(
            config.rescueDelayDst,
            IERC20(config.bmnToken)
        ));
        console.log("EscrowDst Implementation:", escrowDstImpl);
        
        // Deploy factory
        console.log("\nDeploying SimplifiedEscrowFactory...");
        factory = address(new SimplifiedEscrowFactory(
            escrowSrcImpl,
            escrowDstImpl,
            config.owner
        ));
        console.log("Factory deployed at:", factory);
        
        // Add initial resolvers
        SimplifiedEscrowFactory factoryContract = SimplifiedEscrowFactory(factory);
        
        for (uint i = 1; i < config.initialResolvers.length; i++) {
            // Skip first resolver as it's the owner and already added
            address resolver = config.initialResolvers[i];
            if (resolver != address(0) && resolver != config.owner) {
                factoryContract.addResolver(resolver);
                console.log("Added resolver:", resolver);
            }
        }
        
        vm.stopBroadcast();
        
        // Save deployment info
        _saveDeployment();
        
        console.log("\n=== Deployment Complete ===");
        console.log("Factory is paused by default: false");
        console.log("Resolver count:", factoryContract.resolverCount());
        console.log("\nNEXT STEPS:");
        console.log("1. Verify contracts on Etherscan/Basescan");
        console.log("2. Test with small amounts first");
        console.log("3. Add production resolvers");
        console.log("4. Monitor events for any issues");
    }
    
    function _saveDeployment() internal {
        string memory chainName = _getChainName();
        string memory deploymentPath = string.concat(
            "deployments/",
            chainName,
            "-secure-factory.json"
        );
        
        string memory json = "deployment";
        vm.serializeAddress(json, "factory", factory);
        vm.serializeAddress(json, "escrowSrcImpl", escrowSrcImpl);
        vm.serializeAddress(json, "escrowDstImpl", escrowDstImpl);
        vm.serializeUint(json, "chainId", block.chainid);
        vm.serializeUint(json, "blockNumber", block.number);
        string memory output = vm.serializeUint(json, "timestamp", block.timestamp);
        
        vm.writeJson(output, deploymentPath);
        console.log("Deployment saved to:", deploymentPath);
    }
    
    function _getChainName() internal view returns (string memory) {
        uint256 chainId = block.chainid;
        if (chainId == 8453) return "base";
        if (chainId == 10) return "optimism";
        if (chainId == 42793) return "etherlink";
        if (chainId == 31337) return "local";
        return "unknown";
    }
}

// Simple mock token for local testing
contract MockERC20 is IERC20 {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    
    string public name;
    string public symbol;
    uint8 public decimals = 18;
    uint256 public totalSupply;
    
    constructor(string memory _name, string memory _symbol) {
        name = _name;
        symbol = _symbol;
        // Mint some tokens to deployer for testing
        balanceOf[msg.sender] = 1000000 * 10**18;
        totalSupply = 1000000 * 10**18;
    }
    
    function transfer(address to, uint256 amount) external returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }
    
    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }
    
    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}