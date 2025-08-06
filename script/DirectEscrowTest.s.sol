// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Script.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IFactory {
    function deployEscrowSrc(
        bytes32 hashlock,
        address srcToken,
        uint256 srcAmount,
        address dstToken,
        uint256 dstAmount,
        address maker,
        address taker,
        uint256 timelocks,
        bytes32 salt
    ) external returns (address);
    
    function whitelistedResolvers(address) external view returns (bool);
    function owner() external view returns (address);
    function emergencyPaused() external view returns (bool);
}

contract DirectEscrowTest is Script {
    address constant BMN_TOKEN = 0x8287CD2aC7E227D9D927F998EB600a0683a832A1;
    address constant BASE_FACTORY = 0xd599b1543467433F5A6f195Ccc4E01FcbF5AA157;
    
    function run() external {
        uint256 aliceKey = vm.envUint("ALICE_PRIVATE_KEY");
        uint256 resolverKey = vm.envUint("RESOLVER_PRIVATE_KEY");
        address alice = vm.addr(aliceKey);
        address resolver = vm.addr(resolverKey);
        
        console.log("=== DIRECT ESCROW DEPLOYMENT TEST ===");
        console.log("Alice:", alice);
        console.log("Resolver:", resolver);
        
        string memory baseRpc = "https://mainnet.base.org";
        vm.createSelectFork(baseRpc);
        
        IFactory factory = IFactory(BASE_FACTORY);
        
        // Check factory status
        console.log("\n=== FACTORY STATUS ===");
        console.log("Owner:", factory.owner());
        console.log("Emergency Paused:", factory.emergencyPaused());
        console.log("Resolver whitelisted:", factory.whitelistedResolvers(resolver));
        
        // Prepare escrow parameters
        bytes32 hashlock = keccak256("test_secret_123");
        uint256 amount = 10 * 1e18; // 10 BMN tokens
        
        // Create timelocks (simplified)
        uint256 timelocks = uint256(uint32(block.timestamp + 3600)) | // srcWithdrawal
                           (uint256(uint32(block.timestamp + 7200)) << 32) | // srcPublicWithdrawal
                           (uint256(uint32(block.timestamp + 10800)) << 32*2) | // srcCancellation
                           (uint256(uint32(block.timestamp + 14400)) << 32*3) | // srcPublicCancellation
                           (uint256(uint32(block.timestamp + 3600)) << 32*4) | // dstWithdrawal
                           (uint256(uint32(block.timestamp + 10800)) << 32*5) | // dstCancellation
                           (uint256(uint32(block.timestamp + 14400)) << 32*6); // dstPublicCancellation
        
        bytes32 salt = keccak256(abi.encodePacked(block.timestamp, alice));
        
        // Check BMN balance and approve
        IERC20 bmn = IERC20(BMN_TOKEN);
        uint256 balance = bmn.balanceOf(alice);
        console.log("\nAlice BMN balance:", balance / 1e18, "BMN");
        
        if (balance >= amount) {
            console.log("Attempting to deploy escrow with 10 BMN...");
            
            vm.startBroadcast(aliceKey);
            
            // Approve factory to spend tokens
            bmn.approve(BASE_FACTORY, amount);
            console.log("Approved factory to spend 10 BMN");
            
            // Try to deploy escrow
            try factory.deployEscrowSrc(
                hashlock,
                BMN_TOKEN, // srcToken
                amount,    // srcAmount
                BMN_TOKEN, // dstToken (same for simplicity)
                amount,    // dstAmount
                alice,     // maker
                resolver,  // taker
                timelocks,
                salt
            ) returns (address escrow) {
                console.log("[SUCCESS] Escrow deployed at:", escrow);
            } catch Error(string memory reason) {
                console.log("[FAILED] Deployment failed:", reason);
            } catch {
                console.log("[FAILED] Deployment failed with unknown error");
            }
            
            vm.stopBroadcast();
        } else {
            console.log("Insufficient BMN balance for test");
        }
    }
}