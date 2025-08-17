// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import "../contracts/SimplifiedEscrowFactoryV4.sol";
import "../test/mocks/MockLimitOrderProtocol.sol";
import "../contracts/mocks/TokenMock.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

/**
 * @title LocalDeployV4
 * @notice Local deployment script for SimplifiedEscrowFactoryV4 with test setup
 * @dev Deploys factory with mock protocol and test tokens for local development
 */
contract LocalDeployV4 is Script {
    // Known Anvil test accounts
    address constant ALICE = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
    address constant BOB = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;
    
    // Token amounts for testing
    uint256 constant INITIAL_ALICE_TKA = 1000 * 10**18;
    uint256 constant INITIAL_ALICE_TKB = 100 * 10**18;
    uint256 constant INITIAL_BOB_TKA = 500 * 10**18;
    uint256 constant INITIAL_BOB_TKB = 1000 * 10**18;
    
    struct DeploymentResult {
        address factory;
        address mockProtocol;
        address tokenA;
        address tokenB;
        address alice;
        address bob;
    }
    
    function run() external returns (DeploymentResult memory result) {
        // Get deployer private key from environment (default to Anvil account 0)
        uint256 deployerPrivateKey = vm.envOr("DEPLOYER_PRIVATE_KEY", 
            uint256(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80));
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("=== Local SimplifiedEscrowFactoryV4 Deployment ===");
        console.log("Deployer:", deployer);
        console.log("Chain ID:", block.chainid);
        console.log("Alice:", ALICE);
        console.log("Bob (Resolver):", BOB);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // 1. Deploy test tokens
        console.log("\n1. Deploying test tokens...");
        TokenMock tokenA = new TokenMock("Token A", "TKA", 18);
        TokenMock tokenB = new TokenMock("Token B", "TKB", 18);
        
        console.log("- Token A:", address(tokenA));
        console.log("- Token B:", address(tokenB));
        
        // 2. Deploy mock LimitOrderProtocol
        console.log("\n2. Deploying MockLimitOrderProtocol...");
        MockLimitOrderProtocol mockProtocol = new MockLimitOrderProtocol();
        console.log("- Mock Protocol:", address(mockProtocol));
        
        // 3. Deploy SimplifiedEscrowFactoryV4
        console.log("\n3. Deploying SimplifiedEscrowFactoryV4...");
        SimplifiedEscrowFactoryV4 factory = new SimplifiedEscrowFactoryV4(
            address(mockProtocol),  // limitOrderProtocol
            deployer,                // owner
            7 days,                  // rescueDelay
            IERC20(address(0)),      // no access token for local testing
            address(0)               // no WETH for local testing
        );
        console.log("- Factory:", address(factory));
        console.log("- Src Implementation:", factory.ESCROW_SRC_IMPLEMENTATION());
        console.log("- Dst Implementation:", factory.ESCROW_DST_IMPLEMENTATION());
        
        // 4. Configure factory for testing
        console.log("\n4. Configuring factory...");
        
        // Add Bob as resolver
        factory.addResolver(BOB);
        console.log("- Added Bob as resolver");
        
        // Ensure whitelist is bypassed for easier testing
        if (!factory.whitelistBypassed()) {
            factory.setWhitelistBypassed(true);
            console.log("- Whitelist bypassed for testing");
        }
        
        // 5. Mint test tokens to Alice and Bob
        console.log("\n5. Minting test tokens...");
        
        // Alice gets more TKA, less TKB (she'll swap TKA for TKB)
        tokenA.mint(ALICE, INITIAL_ALICE_TKA);
        tokenB.mint(ALICE, INITIAL_ALICE_TKB);
        console.log("- Minted to Alice: 1000 TKA, 100 TKB");
        
        // Bob gets less TKA, more TKB (he'll provide liquidity)
        tokenA.mint(BOB, INITIAL_BOB_TKA);
        tokenB.mint(BOB, INITIAL_BOB_TKB);
        console.log("- Minted to Bob: 500 TKA, 1000 TKB");
        
        // 6. Setup approvals for testing
        console.log("\n6. Setting up test approvals...");
        
        // Approve factory from Bob's account (resolver needs to approve for postInteraction)
        vm.stopBroadcast();
        vm.startBroadcast(0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC); // Bob's private key (Anvil account 2)
        
        tokenB.approve(address(factory), type(uint256).max);
        console.log("- Bob approved factory for TKB transfers");
        
        // Approve mock protocol from Bob (for testing direct transfers)
        tokenB.approve(address(mockProtocol), type(uint256).max);
        console.log("- Bob approved mock protocol for TKB transfers");
        
        vm.stopBroadcast();
        
        // Mock protocol is ready to use with factory as the extension parameter
        
        // 7. Log deployment summary
        logDeploymentSummary(factory, mockProtocol, tokenA, tokenB);
        
        // Return deployment result
        result = DeploymentResult({
            factory: address(factory),
            mockProtocol: address(mockProtocol),
            tokenA: address(tokenA),
            tokenB: address(tokenB),
            alice: ALICE,
            bob: BOB
        });
    }
    
    function logDeploymentSummary(
        SimplifiedEscrowFactoryV4 factory,
        MockLimitOrderProtocol mockProtocol,
        TokenMock tokenA,
        TokenMock tokenB
    ) internal view {
        console.log("\n=== Deployment Summary ===");
        
        console.log("\nCore Contracts:");
        console.log("- Factory:", address(factory));
        console.log("- Mock Protocol:", address(mockProtocol));
        console.log("- Token A (TKA):", address(tokenA));
        console.log("- Token B (TKB):", address(tokenB));
        
        console.log("\nFactory Configuration:");
        console.log("- Owner:", factory.owner());
        console.log("- Whitelist Bypassed:", factory.whitelistBypassed());
        console.log("- Emergency Paused:", factory.emergencyPaused());
        console.log("- Resolver Count:", factory.resolverCount());
        
        console.log("\nTest Accounts:");
        console.log("- Alice (Maker):", ALICE);
        console.log("  - TKA Balance:", tokenA.balanceOf(ALICE) / 10**18, "TKA");
        console.log("  - TKB Balance:", tokenB.balanceOf(ALICE) / 10**18, "TKB");
        console.log("- Bob (Resolver):", BOB);
        console.log("  - TKA Balance:", tokenA.balanceOf(BOB) / 10**18, "TKA");
        console.log("  - TKB Balance:", tokenB.balanceOf(BOB) / 10**18, "TKB");
        console.log("  - Whitelisted:", factory.whitelistedResolvers(BOB));
        console.log("  - Factory Approval:", tokenB.allowance(BOB, address(factory)) == type(uint256).max ? "MAX" : "0");
        
        console.log("\nTest Flow:");
        console.log("1. Alice creates order to swap 10 TKA for 10 TKB");
        console.log("2. Mock protocol simulates fillOrder()");
        console.log("3. Factory.postInteraction() creates escrows");
        console.log("4. Bob (resolver) locks TKB on destination");
        console.log("5. Bob reveals secret and withdraws TKA");
        console.log("6. Alice uses secret to withdraw TKB");
        
        console.log("\nUsage Example:");
        console.log("// Run integration test");
        console.log("forge test --match-test testPostInteractionFlow -vvv");
        
        console.log("\n// Or use with resolver script");
        console.log("export FACTORY_ADDRESS=", address(factory));
        console.log("export TOKEN_A=", address(tokenA));
        console.log("export TOKEN_B=", address(tokenB));
        console.log("node scripts/resolver.js");
    }
    
    /**
     * @notice Helper function to get deployment addresses from existing deployment
     * @dev Run with: forge script script/LocalDeployV4.s.sol:LocalDeployV4 --sig "getDeployment()"
     */
    function getDeployment() external view {
        address payable factoryAddress = payable(vm.envAddress("FACTORY_ADDRESS"));
        
        console.log("=== Existing Deployment Info ===");
        console.log("Factory:", factoryAddress);
        
        SimplifiedEscrowFactoryV4 factory = SimplifiedEscrowFactoryV4(factoryAddress);
        console.log("- Src Implementation:", factory.ESCROW_SRC_IMPLEMENTATION());
        console.log("- Dst Implementation:", factory.ESCROW_DST_IMPLEMENTATION());
        console.log("- Owner:", factory.owner());
        console.log("- Whitelist Bypassed:", factory.whitelistBypassed());
        
        // Try to read token addresses from environment
        address tokenA = vm.envOr("TOKEN_A", address(0));
        address tokenB = vm.envOr("TOKEN_B", address(0));
        
        if (tokenA != address(0)) {
            console.log("\nTokens:");
            console.log("- Token A:", tokenA);
            console.log("- Token B:", tokenB);
        }
        
        console.log("\nTest Accounts:");
        console.log("- Alice:", ALICE);
        console.log("- Bob:", BOB);
    }
}