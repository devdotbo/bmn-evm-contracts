// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "@1inch/solidity-utils/contracts/mocks/TokenMock.sol";

/**
 * @title Deploy Test Tokens on Mainnet
 * @notice Deploys TKA on Base and TKB on Etherlink for cross-chain testing
 * @dev Run with:
 * - Base: forge script script/DeployTestTokensMainnet.s.sol --rpc-url base --broadcast -vvv
 * - Etherlink: forge script script/DeployTestTokensMainnet.s.sol --rpc-url etherlink --broadcast -vvv
 */
contract DeployTestTokensMainnet is Script {
    // Test accounts
    address constant DEPLOYER = 0x5f29827e25dc174a6A51C99e6811Bbd7581285b0;
    address constant ALICE = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
    address constant BOB_RESOLVER = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;
    
    // Token amounts for testing (small amounts for mainnet)
    uint256 constant INITIAL_SUPPLY = 10_000 ether;
    uint256 constant ALICE_AMOUNT = 1_000 ether;
    uint256 constant BOB_AMOUNT = 1_000 ether;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        require(deployer == DEPLOYER, "Wrong deployer key");
        
        uint256 chainId = block.chainid;
        console.log("Deploying test tokens on chain", chainId);
        
        vm.startBroadcast(deployerPrivateKey);
        
        if (chainId == 8453) { // Base
            // Deploy TKA on Base
            TokenMock tka = new TokenMock("Test Token A", "TKA");
            console.log("TKA deployed at:", address(tka));
            
            // Mint initial supply
            tka.mint(deployer, INITIAL_SUPPLY);
            
            // Distribute to test accounts
            tka.mint(ALICE, ALICE_AMOUNT);
            tka.mint(BOB_RESOLVER, BOB_AMOUNT);
            
            console.log("Minted TKA to test accounts:");
            console.log("  Alice:", ALICE_AMOUNT / 1e18, "TKA");
            console.log("  Bob:", BOB_AMOUNT / 1e18, "TKA");
            
            // Save deployment
            string memory json = string.concat(
                '{"chainId": 8453, "TKA": "',
                vm.toString(address(tka)),
                '"}'
            );
            vm.writeFile("deployments/base-test-tokens.json", json);
            
        } else if (chainId == 42793) { // Etherlink
            // Deploy TKB on Etherlink
            TokenMock tkb = new TokenMock("Test Token B", "TKB");
            console.log("TKB deployed at:", address(tkb));
            
            // Mint initial supply
            tkb.mint(deployer, INITIAL_SUPPLY);
            
            // Distribute to test accounts
            tkb.mint(ALICE, ALICE_AMOUNT);
            tkb.mint(BOB_RESOLVER, BOB_AMOUNT);
            
            console.log("Minted TKB to test accounts:");
            console.log("  Alice:", ALICE_AMOUNT / 1e18, "TKB");
            console.log("  Bob:", BOB_AMOUNT / 1e18, "TKB");
            
            // Save deployment
            string memory json = string.concat(
                '{"chainId": 42793, "TKB": "',
                vm.toString(address(tkb)),
                '"}'
            );
            vm.writeFile("deployments/etherlink-test-tokens.json", json);
        }
        
        vm.stopBroadcast();
    }
}