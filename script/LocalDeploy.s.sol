// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { IOrderMixin, LimitOrderProtocol, IWETH } from "limit-order-protocol/contracts/LimitOrderProtocol.sol";
import { TokenMock } from "solidity-utils/contracts/mocks/TokenMock.sol";
import { EscrowFactory } from "../contracts/EscrowFactory.sol";

contract LocalDeploy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

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

        // Mint tokens to test accounts
        address alice = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8; // Anvil account 1
        address bob = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;   // Anvil account 2

        tokenA.mint(alice, 1000 ether);
        tokenB.mint(bob, 1000 ether);
        accessToken.mint(alice, 1);
        accessToken.mint(bob, 1);
        feeToken.mint(bob, 100 ether);

        console.log("Setup complete!");
        console.log("Alice:", alice);
        console.log("Bob (Resolver):", bob);

        vm.stopBroadcast();
    }
}