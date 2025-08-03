// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { IOrderMixin, LimitOrderProtocol, IWETH } from "limit-order-protocol/contracts/LimitOrderProtocol.sol";
import { TokenMock } from "solidity-utils/contracts/mocks/TokenMock.sol";
import { EscrowFactory } from "../contracts/EscrowFactory.sol";

contract MainnetDeploy is Script {
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

    // Mainnet chain IDs
    uint256 constant BASE_MAINNET_CHAIN_ID = 8453;
    uint256 constant ETHERLINK_MAINNET_CHAIN_ID = 42793;

    // Account addresses from mnemonic
    address constant DEPLOYER = 0x5f29827e25dc174a6A51C99e6811Bbd7581285b0;
    address constant BOB_RESOLVER = 0xfdF1dDeB176BEA06c7430166e67E615bC312b7B5;
    address constant ALICE = 0x240E2588e35FB9D3D60B283B45108a49972FFFd8;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        uint256 chainId = block.chainid;

        // Validate deployer address matches expected
        require(deployer == DEPLOYER, "Deployer address mismatch");

        console.log("========================================");
        console.log("Deploying on Mainnet");
        console.log("Chain ID:", chainId);
        console.log("Chain Name:", getChainName(chainId));
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
            IERC20(address(feeToken)),
            IERC20(address(accessToken)),
            deployer, // owner
            604800,   // 7 days rescue delay (uint32)
            604800    // 7 days rescue delay (uint32)
        );
        console.log("Escrow Factory:", address(factory));

        console.log("\n--- Minting Tokens ---");
        
        if (chainId == BASE_MAINNET_CHAIN_ID) {
            // Base Mainnet (Chain A): Alice has tokenA, Bob needs tokenA as resolver
            console.log("Base Mainnet token distribution:");
            tokenA.mint(ALICE, 1000 ether);
            console.log("  Alice receives 1000 TKA");
            tokenA.mint(BOB_RESOLVER, 500 ether); // Bob needs tokenA to act as taker
            console.log("  Bob receives 500 TKA (for taker role)");
        } else if (chainId == ETHERLINK_MAINNET_CHAIN_ID) {
            // Etherlink Mainnet (Chain B): Bob has tokenB for liquidity
            console.log("Etherlink Mainnet token distribution:");
            tokenB.mint(BOB_RESOLVER, 1000 ether);
            console.log("  Bob receives 1000 TKB (liquidity)");
            tokenB.mint(ALICE, 100 ether); // Alice might need some for testing
            console.log("  Alice receives 100 TKB (for testing)");
        }

        // Both chains: access tokens and fee tokens
        accessToken.mint(ALICE, 1);
        accessToken.mint(BOB_RESOLVER, 1);
        feeToken.mint(BOB_RESOLVER, 100 ether);
        console.log("  Both receive access tokens");
        console.log("  Bob receives 100 fee tokens");

        console.log("\n========================================");
        console.log("Deployment Summary:");
        console.log("Factory:", address(factory));
        console.log("LimitOrderProtocol:", address(lop));
        console.log("Alice:", ALICE);
        console.log("Bob (Resolver):", BOB_RESOLVER);
        console.log("========================================");

        // Save deployment data
        string memory chainName = getChainFileName(chainId);
        string memory filename = string.concat("deployments/", chainName, ".json");
        
        DeploymentData memory data = DeploymentData({
            factory: address(factory),
            limitOrderProtocol: address(lop),
            tokenA: address(tokenA),
            tokenB: address(tokenB),
            accessToken: address(accessToken),
            feeToken: address(feeToken),
            alice: ALICE,
            bob: BOB_RESOLVER,
            deployer: deployer,
            chainId: chainId
        });

        string memory json = _generateJson(data);
        vm.writeFile(filename, json);
        console.log("\nDeployment data saved to:", filename);

        vm.stopBroadcast();
    }

    function getChainName(uint256 chainId) internal pure returns (string memory) {
        if (chainId == BASE_MAINNET_CHAIN_ID) return "Base Mainnet";
        if (chainId == ETHERLINK_MAINNET_CHAIN_ID) return "Etherlink Mainnet";
        return "Unknown";
    }

    function getChainFileName(uint256 chainId) internal pure returns (string memory) {
        if (chainId == BASE_MAINNET_CHAIN_ID) return "baseMainnet";
        if (chainId == ETHERLINK_MAINNET_CHAIN_ID) return "etherlinkMainnet";
        revert("Unsupported chain ID");
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