// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import "../contracts/SimplifiedEscrowFactory.sol";
import "../contracts/EscrowSrc.sol";
import "../contracts/EscrowDst.sol";
import "../contracts/mocks/TokenMock.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

/**
 * @title LocalDeploy
 * @notice Simple deployment script for local testing with Anvil
 * @dev Deploys factory and test tokens for development
 */
contract LocalDeploy is Script {
    function run() external {
        // Use Anvil's default private key if not specified
        uint256 deployerPrivateKey;
        try vm.envUint("DEPLOYER_PRIVATE_KEY") returns (uint256 key) {
            deployerPrivateKey = key;
        } catch {
            deployerPrivateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        }
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("Deployer:", deployer);
        console.log("Chain ID:", block.chainid);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy implementation contracts
        uint32 rescueDelay = 7 days;
        address accessToken = address(0); // No access token for local testing
        
        EscrowSrc escrowSrcImpl = new EscrowSrc(rescueDelay, IERC20(accessToken));
        EscrowDst escrowDstImpl = new EscrowDst(rescueDelay, IERC20(accessToken));
        
        console.log("EscrowSrc Implementation:", address(escrowSrcImpl));
        console.log("EscrowDst Implementation:", address(escrowDstImpl));
        
        // Deploy factory
        SimplifiedEscrowFactory factory = new SimplifiedEscrowFactory(
            address(escrowSrcImpl),
            address(escrowDstImpl),
            deployer // owner
        );
        
        console.log("SimplifiedEscrowFactory:", address(factory));
        
        // Deploy test tokens
        TokenMock tokenA = new TokenMock("Token A", "TKA", 18);
        TokenMock tokenB = new TokenMock("Token B", "TKB", 18);
        
        console.log("Token A:", address(tokenA));
        console.log("Token B:", address(tokenB));
        
        // Mint tokens to test accounts
        address alice = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8; // Anvil account 1
        address bob = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;   // Anvil account 2
        
        // Alice gets TKA on source chain
        tokenA.mint(alice, 1000 * 10**18);
        console.log("Minted 1000 TKA to Alice");
        
        // Bob (resolver) gets TKB on destination chain
        tokenB.mint(bob, 1000 * 10**18);
        console.log("Minted 1000 TKB to Bob");
        
        // Also give them some of the opposite tokens for testing
        tokenB.mint(alice, 100 * 10**18);
        tokenA.mint(bob, 500 * 10**18);
        
        vm.stopBroadcast();
        
        // Write deployment info to file for other scripts
        string memory json = string.concat(
            '{"factory":"', vm.toString(address(factory)), '",',
            '"tokenA":"', vm.toString(address(tokenA)), '",',
            '"tokenB":"', vm.toString(address(tokenB)), '",',
            '"escrowSrcImpl":"', vm.toString(address(escrowSrcImpl)), '",',
            '"escrowDstImpl":"', vm.toString(address(escrowDstImpl)), '"}'
        );
        
        vm.writeFile("deployments/local.json", json);
        
        console.log("\nLocal deployment complete!");
        console.log("Deployment info saved to deployments/local.json");
        console.log("\nTest Accounts:");
        console.log("- Alice:", alice);
        console.log("- Bob (Resolver):", bob);
    }
}