// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { Script, console } from "forge-std/Script.sol";
import { BMNAccessTokenV2 } from "../contracts/BMNAccessTokenV2.sol";

contract MintBMNTokens is Script {
    // BMN Access Token V2 deployed with CREATE2 - same on all chains
    address constant BMN_ACCESS_TOKEN = 0x18ae5BB6E03Dc346eA9fd1afA78FEc314343857e;
    
    // Expected owner address
    address constant EXPECTED_OWNER = 0x5f29827e25dc174a6A51C99e6811Bbd7581285b0;
    
    // Resolver addresses to mint to
    address constant DEPLOYER_OWNER = 0x5f29827e25dc174a6A51C99e6811Bbd7581285b0;
    address constant BOB_RESOLVER = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;
    
    // Amount to mint to each address (1000 BMN in 18-decimals)
    uint256 constant MINT_AMOUNT = 1000 * 10**18;
    
    // Chain IDs
    uint256 constant BASE_CHAIN_ID = 8453;
    uint256 constant ETHERLINK_CHAIN_ID = 42793;
    
    function run() external {
        uint256 ownerKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address owner = vm.addr(ownerKey);
        
        // Verify we're using the correct owner key
        require(owner == EXPECTED_OWNER, "MintBMNTokens: incorrect owner key");
        
        // Get current chain ID
        uint256 chainId = block.chainid;
        string memory chainName = getChainName(chainId);
        
        console.log("=== MINTING BMN TOKENS ON", chainName, "===");
        console.log("Chain ID:", chainId);
        console.log("BMN Token Address:", BMN_ACCESS_TOKEN);
        console.log("Owner:", owner);
        console.log("");
        
        vm.startBroadcast(ownerKey);
        
        BMNAccessTokenV2 bmnToken = BMNAccessTokenV2(BMN_ACCESS_TOKEN);
        
        // Verify ownership
        address currentOwner = bmnToken.owner();
        require(currentOwner == owner, "MintBMNTokens: not the token owner");
        console.log("Verified ownership");
        console.log("");
        
        // Check and authorize addresses if needed
        checkAndAuthorize(bmnToken, DEPLOYER_OWNER);
        checkAndAuthorize(bmnToken, BOB_RESOLVER);
        
        // Mint tokens
        mintTokens(bmnToken, DEPLOYER_OWNER, MINT_AMOUNT);
        mintTokens(bmnToken, BOB_RESOLVER, MINT_AMOUNT);
        
        vm.stopBroadcast();
        
        // Display final balances
        console.log("");
        console.log("=== FINAL BALANCES ===");
        console.log("Deployer/Owner balance:", bmnToken.balanceOf(DEPLOYER_OWNER));
        console.log("Bob/Resolver balance:", bmnToken.balanceOf(BOB_RESOLVER));
        console.log("Total supply:", bmnToken.totalSupply());
        console.log("====================");
    }
    
    function checkAndAuthorize(BMNAccessTokenV2 token, address account) private {
        if (!token.authorized(account)) {
            console.log("Authorizing address:", account);
            token.authorize(account);
            console.log("Authorized successfully");
        } else {
            console.log("Address already authorized:", account);
        }
    }
    
    function mintTokens(BMNAccessTokenV2 token, address to, uint256 amount) private {
        uint256 balanceBefore = token.balanceOf(to);
        console.log("");
        console.log("Minting", amount, "tokens to:", to);
        console.log("Balance before:", balanceBefore);
        
        token.mint(to, amount);
        
        uint256 balanceAfter = token.balanceOf(to);
        console.log("Balance after:", balanceAfter);
        console.log("Minted", balanceAfter - balanceBefore, "tokens successfully");
    }
    
    function getChainName(uint256 chainId) private pure returns (string memory) {
        if (chainId == BASE_CHAIN_ID) {
            return "BASE";
        } else if (chainId == ETHERLINK_CHAIN_ID) {
            return "ETHERLINK";
        } else {
            return "UNKNOWN CHAIN";
        }
    }
}