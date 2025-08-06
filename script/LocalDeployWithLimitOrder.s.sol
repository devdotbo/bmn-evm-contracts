// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import "../contracts/CrossChainEscrowFactory.sol";
import "../contracts/EscrowSrc.sol";
import "../contracts/EscrowDst.sol";
import "../contracts/test/TokenMock.sol";

// Import SimpleLimitOrderProtocol interface
interface ISimpleLimitOrderProtocol {
    function DOMAIN_SEPARATOR() external view returns(bytes32);
}

// Mock WETH for local testing
contract MockWETH {
    function deposit() public payable {}
    function withdraw(uint256) public {}
    function approve(address, uint256) public returns (bool) { return true; }
    function transfer(address, uint256) public returns (bool) { return true; }
    function transferFrom(address, address, uint256) public returns (bool) { return true; }
    function balanceOf(address) public view returns (uint256) { return 0; }
}

contract LocalDeployWithLimitOrder is Script {
    function run() external {
        // Use first anvil account as deployer
        uint256 deployerKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        address deployer = vm.addr(deployerKey);
        
        // Test accounts
        address alice = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
        address bob = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;
        
        uint256 chainId = block.chainid;
        string memory chainName = chainId == 31337 ? "Anvil Chain A" : "Anvil Chain B";
        
        console.log("========================================");
        console.log("Local Deployment with SimpleLimitOrderProtocol");
        console.log("========================================");
        console.log("Chain:", chainName);
        console.log("Chain ID:", chainId);
        console.log("Deployer:", deployer);
        
        vm.startBroadcast(deployerKey);
        
        // Deploy Mock WETH
        MockWETH weth = new MockWETH();
        console.log("Mock WETH deployed at:", address(weth));
        
        // Deploy SimpleLimitOrderProtocol locally
        // Note: This is a simplified version for testing
        // In production, use the actual SimpleLimitOrderProtocol from bmn-evm-contracts-limit-order
        bytes memory limitOrderBytecode = vm.getCode("/Users/bioharz/git/2025_2/unite/bridge-me-not/bmn-evm-contracts-limit-order/out/SimpleLimitOrderProtocol.sol/SimpleLimitOrderProtocol.json");
        address limitOrderProtocol;
        assembly {
            limitOrderProtocol := create2(0, add(limitOrderBytecode, 0x20), mload(limitOrderBytecode), salt)
        }
        
        console.log("SimpleLimitOrderProtocol deployed at:", limitOrderProtocol);
        
        // Deploy tokens for testing
        TokenMock tokenA = new TokenMock("Token A", "TKA");
        TokenMock tokenB = new TokenMock("Token B", "TKB");
        console.log("Token A deployed at:", address(tokenA));
        console.log("Token B deployed at:", address(tokenB));
        
        // Deploy BMN token (used as fee/access token)
        TokenMock bmnToken = new TokenMock("Bridge Me Not", "BMN");
        console.log("BMN Token deployed at:", address(bmnToken));
        
        // Deploy escrow implementations
        EscrowSrc escrowSrc = new EscrowSrc();
        EscrowDst escrowDst = new EscrowDst();
        console.log("EscrowSrc implementation:", address(escrowSrc));
        console.log("EscrowDst implementation:", address(escrowDst));
        
        // Deploy CrossChainEscrowFactory with SimpleLimitOrderProtocol
        CrossChainEscrowFactory factory = new CrossChainEscrowFactory(
            limitOrderProtocol,           // SimpleLimitOrderProtocol address
            IERC20(address(bmnToken)),    // Fee token
            IERC20(address(bmnToken)),    // Access token
            deployer,                      // Owner
            address(escrowSrc),            // Source escrow implementation
            address(escrowDst)             // Destination escrow implementation
        );
        
        console.log("CrossChainEscrowFactory deployed at:", address(factory));
        
        // Mint tokens for testing
        if (chainId == 31337) {
            // Chain A: Alice has Token A, Bob needs Token A
            tokenA.mint(alice, 1000 * 10**18);
            tokenB.mint(bob, 100 * 10**18);
            console.log("\nChain A token distribution:");
            console.log("Alice has 1000 TKA");
            console.log("Bob has 100 TKB");
        } else {
            // Chain B: Bob has Token B, Alice needs Token B
            tokenA.mint(alice, 100 * 10**18);
            tokenB.mint(bob, 1000 * 10**18);
            console.log("\nChain B token distribution:");
            console.log("Alice has 100 TKA");
            console.log("Bob has 1000 TKB");
        }
        
        // Mint BMN tokens for access (both chains)
        bmnToken.mint(alice, 100 * 10**18);
        bmnToken.mint(bob, 100 * 10**18);
        console.log("Both Alice and Bob have 100 BMN for access");
        
        // Fund accounts with ETH for gas
        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
        
        vm.stopBroadcast();
        
        // Save deployment addresses to file for test scripts
        string memory deploymentData = string(abi.encodePacked(
            '{"chainId":', vm.toString(chainId),
            ',"limitOrderProtocol":"', vm.toString(limitOrderProtocol),
            '","factory":"', vm.toString(address(factory)),
            '","tokenA":"', vm.toString(address(tokenA)),
            '","tokenB":"', vm.toString(address(tokenB)),
            '","bmnToken":"', vm.toString(address(bmnToken)),
            '","weth":"', vm.toString(address(weth)),
            '"}'
        ));
        
        string memory filename = chainId == 31337 ? "deployments/local-chain-a.json" : "deployments/local-chain-b.json";
        vm.writeFile(filename, deploymentData);
        
        console.log("\n========================================");
        console.log("LOCAL DEPLOYMENT SUCCESSFUL!");
        console.log("========================================");
        console.log("Deployment data saved to:", filename);
        console.log("\nTo test cross-chain swaps:");
        console.log("1. Run this script on both Anvil chains (8545 and 8546)");
        console.log("2. Use test scripts to create and fill orders");
        console.log("3. Monitor escrow creation through factory events");
    }
}