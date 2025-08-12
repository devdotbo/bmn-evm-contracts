// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { SimplifiedEscrowFactoryV2_3 } from "../contracts/SimplifiedEscrowFactoryV2_3.sol";
import { Constants } from "../contracts/Constants.sol";

interface ICREATE3 { function deploy(bytes32 salt, bytes calldata bytecode) external payable returns (address); function getDeployed(address deployer, bytes32 salt) external view returns (address); }

contract DeployV2_3_Mainnet is Script {
    address constant CREATE3_FACTORY = 0x7B9e9BE124C5A0E239E04fDC93b66ead4e8C669d;
    uint256 constant RESCUE_DELAY = 604800; // 7 days
    bytes32 constant FACTORY_SALT = keccak256("BMN-SimplifiedEscrowFactory-v2.3.0-EIP712");

    address public factory;

    function run() external {
        uint256 pk = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(pk);

        console.log("=== Deploy SimplifiedEscrowFactory v2.3.0 (EIP-712) ===");
        console.log("Deployer:", deployer);
        console.log("Chain:", block.chainid);
        console.log("Create3:", CREATE3_FACTORY);
        console.log("BMN Token:", Constants.BMN_TOKEN);

        factory = ICREATE3(CREATE3_FACTORY).getDeployed(deployer, FACTORY_SALT);
        console.log("Predicted factory:", factory);

        vm.startBroadcast(pk);

        if (factory.code.length == 0) {
            bytes memory bytecode = abi.encodePacked(
                type(SimplifiedEscrowFactoryV2_3).creationCode,
                abi.encode(IERC20(Constants.BMN_TOKEN), deployer, uint32(RESCUE_DELAY))
            );
            address deployed = ICREATE3(CREATE3_FACTORY).deploy(FACTORY_SALT, bytecode);
            require(deployed == factory, "factory addr mismatch");
            console.log("Deployed factory v2.3 at:", deployed);
        } else {
            console.log("Factory already deployed at:", factory);
        }

        vm.stopBroadcast();

        string memory file = string(abi.encodePacked("deployments/v2.3.0-mainnet-", vm.toString(block.chainid), ".env"));
        string memory info = string(abi.encodePacked(
            "FACTORY_V2_3=", vm.toString(factory), "\n",
            "CHAIN_ID=", vm.toString(block.chainid), "\n"
        ));
        vm.writeFile(file, info);
        console.log("Saved:", file);
    }
}


