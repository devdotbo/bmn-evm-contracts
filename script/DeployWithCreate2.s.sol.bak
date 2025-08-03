// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { EscrowSrc } from "../contracts/EscrowSrc.sol";
import { EscrowDst } from "../contracts/EscrowDst.sol";
import { TestEscrowFactory } from "../contracts/TestEscrowFactory.sol";
import { Constants } from "../contracts/Constants.sol";

/**
 * @title DeployWithCreate2
 * @notice Deploy escrow contracts with CREATE2 for cross-chain consistency
 * @dev Uses the same CREATE2 factory that deployed BMN token
 */
contract DeployWithCreate2 is Script {
    // Standard CREATE2 factory available on both Base and Etherlink
    address constant CREATE2_FACTORY = 0x4e59b44847b379578588920cA78FbF26c0B4956C;
    
    // Deterministic salts for cross-chain consistency
    bytes32 constant SRC_SALT = keccak256("BMN-EscrowSrc-V1");
    bytes32 constant DST_SALT = keccak256("BMN-EscrowDst-V1");
    bytes32 constant FACTORY_SALT = keccak256("BMN-Factory-V1");
    
    function run() external {
        uint256 deployerKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);
        
        console.log("Deploying with CREATE2 from:", deployer);
        console.log("CREATE2 Factory:", CREATE2_FACTORY);
        console.log("Chain ID:", block.chainid);
        
        vm.startBroadcast(deployerKey);
        
        // Step 1: Deploy implementation contracts
        address srcImpl = deployWithCreate2(
            SRC_SALT,
            type(EscrowSrc).creationCode,
            "EscrowSrc"
        );
        
        address dstImpl = deployWithCreate2(
            DST_SALT,
            type(EscrowDst).creationCode,
            "EscrowDst"
        );
        
        // Step 2: Deploy factory with implementations
        bytes memory factoryBytecode = abi.encodePacked(
            type(TestEscrowFactory).creationCode,
            abi.encode(
                srcImpl,
                dstImpl,
                Constants.BMN_TOKEN,
                0.00001 ether // safety deposit
            )
        );
        
        address factory = deployWithCreate2(
            FACTORY_SALT,
            factoryBytecode,
            "TestEscrowFactory"
        );
        
        // Log deployment addresses
        console.log("\n=== Deployment Complete ===");
        console.log("SRC Implementation:", srcImpl);
        console.log("DST Implementation:", dstImpl);
        console.log("Factory:", factory);
        console.log("\nThese addresses should be IDENTICAL on both chains!");
        
        // Verify deployment
        uint256 srcSize;
        uint256 dstSize;
        uint256 factorySize;
        assembly {
            srcSize := extcodesize(srcImpl)
            dstSize := extcodesize(dstImpl)
            factorySize := extcodesize(factory)
        }
        
        require(srcSize > 0, "SRC implementation deployment failed");
        require(dstSize > 0, "DST implementation deployment failed");
        require(factorySize > 0, "Factory deployment failed");
        
        console.log("\nDeployment verified successfully!");
        
        vm.stopBroadcast();
        
        // Calculate expected addresses for verification
        console.log("\n=== Expected Addresses (for verification) ===");
        logExpectedAddress(SRC_SALT, type(EscrowSrc).creationCode, "EscrowSrc");
        logExpectedAddress(DST_SALT, type(EscrowDst).creationCode, "EscrowDst");
        logExpectedAddress(FACTORY_SALT, factoryBytecode, "Factory");
    }
    
    function deployWithCreate2(
        bytes32 salt,
        bytes memory bytecode,
        string memory contractName
    ) internal returns (address deployed) {
        console.log("Deploying", contractName, "with salt:", vm.toString(salt));
        
        // Call CREATE2 factory
        (bool success, bytes memory result) = CREATE2_FACTORY.call(
            abi.encodePacked(salt, bytecode)
        );
        
        require(success, string.concat("CREATE2 deployment failed for ", contractName));
        
        // Extract deployed address from return data
        assembly {
            deployed := mload(add(result, 0x20))
        }
        
        console.log(contractName, "deployed at:", deployed);
        return deployed;
    }
    
    function logExpectedAddress(
        bytes32 salt,
        bytes memory bytecode,
        string memory contractName
    ) internal pure {
        address expected = computeCreate2Address(salt, bytecode);
        console.log(contractName, "expected at:", expected);
    }
    
    function computeCreate2Address(
        bytes32 salt,
        bytes memory bytecode
    ) internal pure returns (address) {
        bytes32 hash = keccak256(
            abi.encodePacked(
                bytes1(0xff),
                CREATE2_FACTORY,
                salt,
                keccak256(bytecode)
            )
        );
        return address(uint160(uint256(hash)));
    }
}