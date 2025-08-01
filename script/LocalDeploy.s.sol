// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { IOrderMixin, LimitOrderProtocol, IWETH } from "limit-order-protocol/contracts/LimitOrderProtocol.sol";
import { TokenMock } from "solidity-utils/contracts/mocks/TokenMock.sol";
import { EscrowFactory } from "../contracts/EscrowFactory.sol";

contract LocalDeploy is Script {
    struct DeploymentData {
        address factory;
        address limitOrderProtocol;
        address tokenA;
        address tokenB;
        address accessToken;
        address feeToken;
        address alice;
        address bob;
        address deployer;
        uint256 chainId;
    }

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        uint256 chainId = block.chainid;

        console.log("========================================");
        console.log("Deploying on Chain ID:", chainId);
        console.log("Deployer:", deployer);
        console.log("========================================");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy mock tokens
        TokenMock tokenA = new TokenMock("Token A", "TKA");
        TokenMock tokenB = new TokenMock("Token B", "TKB");
        TokenMock accessToken = new TokenMock("Access Token", "ACCESS");
        TokenMock feeToken = new TokenMock("Fee Token", "FEE");

        console.log("Token A:", address(tokenA));
        console.log("Token B:", address(tokenB));
        console.log("Access Token:", address(accessToken));
        console.log("Fee Token:", address(feeToken));

        // Deploy Limit Order Protocol
        LimitOrderProtocol lop = new LimitOrderProtocol(IWETH(address(0)));
        console.log("Limit Order Protocol:", address(lop));

        // Deploy Escrow Factory
        EscrowFactory factory = new EscrowFactory(
            address(lop),
            feeToken,
            accessToken,
            deployer, // owner
            604800,   // 7 days rescue delay
            604800    // 7 days rescue delay
        );
        console.log("Escrow Factory:", address(factory));

        // Test accounts
        address alice = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8; // Anvil account 1
        address bob = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;   // Anvil account 2

        console.log("\n--- Minting Tokens ---");
        
        if (chainId == 1337) {
            // Chain A: Alice has tokenA, Bob needs tokenA as resolver
            console.log("Chain A token distribution:");
            tokenA.mint(alice, 1000 ether);
            console.log("  Alice receives 1000 TKA");
            tokenA.mint(bob, 500 ether); // Bob needs tokenA to act as taker
            console.log("  Bob receives 500 TKA (for taker role)");
        } else if (chainId == 1338) {
            // Chain B: Bob has tokenB for liquidity
            console.log("Chain B token distribution:");
            tokenB.mint(bob, 1000 ether);
            console.log("  Bob receives 1000 TKB (liquidity)");
            tokenB.mint(alice, 100 ether); // Alice might need some for testing
            console.log("  Alice receives 100 TKB (for testing)");
        }

        // Both chains: access tokens and fee tokens
        accessToken.mint(alice, 1);
        accessToken.mint(bob, 1);
        feeToken.mint(bob, 100 ether);
        console.log("  Both receive access tokens");
        console.log("  Bob receives 100 fee tokens");

        console.log("\n========================================");
        console.log("Deployment Summary:");
        console.log("Factory:", address(factory));
        console.log("LimitOrderProtocol:", address(lop));
        console.log("Alice:", alice);
        console.log("Bob (Resolver):", bob);
        console.log("========================================");

        // Save deployment data
        string memory chainName = chainId == 1337 ? "chainA" : "chainB";
        string memory filename = string.concat("deployments/", chainName, ".json");
        
        DeploymentData memory data = DeploymentData({
            factory: address(factory),
            limitOrderProtocol: address(lop),
            tokenA: address(tokenA),
            tokenB: address(tokenB),
            accessToken: address(accessToken),
            feeToken: address(feeToken),
            alice: alice,
            bob: bob,
            deployer: deployer,
            chainId: chainId
        });

        string memory json = _generateJson(data);
        vm.writeFile(filename, json);
        console.log("\nDeployment data saved to:", filename);

        vm.stopBroadcast();
    }

    function _generateJson(DeploymentData memory data) internal pure returns (string memory) {
        return string.concat(
            '{\n',
            '  "chainId": ', vm.toString(data.chainId), ',\n',
            '  "contracts": {\n',
            '    "factory": "', vm.toString(data.factory), '",\n',
            '    "limitOrderProtocol": "', vm.toString(data.limitOrderProtocol), '",\n',
            '    "tokenA": "', vm.toString(data.tokenA), '",\n',
            '    "tokenB": "', vm.toString(data.tokenB), '",\n',
            '    "accessToken": "', vm.toString(data.accessToken), '",\n',
            '    "feeToken": "', vm.toString(data.feeToken), '"\n',
            '  },\n',
            '  "accounts": {\n',
            '    "deployer": "', vm.toString(data.deployer), '",\n',
            '    "alice": "', vm.toString(data.alice), '",\n',
            '    "bob": "', vm.toString(data.bob), '"\n',
            '  }\n',
            '}'
        );
    }
}