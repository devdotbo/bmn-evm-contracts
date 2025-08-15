// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import "../contracts/SimplifiedEscrowFactory.sol";
import "../contracts/EscrowSrc.sol";
import "../contracts/EscrowDst.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title DeployV3_0_1
 * @notice Deployment script for v3.0.1 bugfix release
 * @dev Fixes critical timing validation issue where hardcoded dstCancellation caused InvalidCreationTime errors
 * 
 * BUGFIX DETAILS:
 * - Issue: Hardcoded 2-hour dstCancellation incompatible with reduced 60s TIMESTAMP_TOLERANCE
 * - Fix: Align dstCancellation with srcCancellation to ensure validation always passes
 * - Impact: Enables instant atomic swaps with flexible cancellation times
 * 
 * DEPLOYMENT ADDRESSES:
 * - Will be deployed to new addresses on Base and Optimism
 * - Migration from v3.0.0 required (v3.0.0 is broken and unusable)
 */
contract DeployV3_0_1 is Script {
    // Configuration
    uint32 constant RESCUE_DELAY = 86400; // 1 day
    IERC20 constant NO_ACCESS_TOKEN = IERC20(address(0));
    
    // Expected addresses (will be different from v3.0.0)
    address public escrowSrcImpl;
    address public escrowDstImpl;
    address public factory;
    
    function run() external {
        // Get deployer from environment
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("=== V3.0.1 BUGFIX DEPLOYMENT ===");
        console.log("Deployer:", deployer);
        console.log("Chain ID:", block.chainid);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // 1. Deploy EscrowSrc implementation
        escrowSrcImpl = address(new EscrowSrc(RESCUE_DELAY, NO_ACCESS_TOKEN));
        console.log("EscrowSrc Implementation:", escrowSrcImpl);
        
        // 2. Deploy EscrowDst implementation
        escrowDstImpl = address(new EscrowDst(RESCUE_DELAY, NO_ACCESS_TOKEN));
        console.log("EscrowDst Implementation:", escrowDstImpl);
        
        // 3. Deploy SimplifiedEscrowFactory v3.0.1
        factory = address(new SimplifiedEscrowFactory(
            escrowSrcImpl,
            escrowDstImpl,
            deployer
        ));
        console.log("SimplifiedEscrowFactory v3.0.1:", factory);
        
        // 4. Configure factory
        SimplifiedEscrowFactory factoryContract = SimplifiedEscrowFactory(factory);
        
        // Deployer is already whitelisted in constructor, so skip that
        // Just enable whitelist bypass for easier testing initially
        factoryContract.setWhitelistBypassed(true);
        console.log("Whitelist bypass enabled for testing");
        
        vm.stopBroadcast();
        
        // Verification instructions
        console.log("\n=== VERIFICATION COMMANDS ===");
        console.log("Base:");
        console.log(string.concat(
            "forge verify-contract --watch --chain base ",
            vm.toString(factory),
            " contracts/SimplifiedEscrowFactory.sol:SimplifiedEscrowFactory --constructor-args ",
            vm.toString(abi.encode(escrowSrcImpl, escrowDstImpl, deployer))
        ));
        
        console.log("\nOptimism:");
        console.log(string.concat(
            "forge verify-contract --watch --chain optimism ",
            vm.toString(factory),
            " contracts/SimplifiedEscrowFactory.sol:SimplifiedEscrowFactory --constructor-args ",
            vm.toString(abi.encode(escrowSrcImpl, escrowDstImpl, deployer))
        ));
        
        // Output deployment summary
        console.log("\n=== DEPLOYMENT SUMMARY ===");
        console.log("Version: v3.0.1");
        console.log("Status: BUGFIX RELEASE");
        console.log("Critical Fix: dstCancellation now aligns with srcCancellation");
        console.log("Features:");
        console.log("- Instant withdrawals (0 delay)");
        console.log("- Flexible cancellation times (any duration)");
        console.log("- 60s timestamp tolerance");
        console.log("- Whitelist bypass enabled by default");
        console.log("\nFactory Address:", factory);
        console.log("EscrowSrc Impl:", escrowSrcImpl);
        console.log("EscrowDst Impl:", escrowDstImpl);
        
        // Save deployment info
        _saveDeployment();
    }
    
    function _saveDeployment() internal {
        string memory json = "deployment";
        vm.serializeString(json, "version", "v3.0.1");
        vm.serializeString(json, "status", "BUGFIX");
        vm.serializeAddress(json, "factory", factory);
        vm.serializeAddress(json, "escrowSrcImpl", escrowSrcImpl);
        vm.serializeAddress(json, "escrowDstImpl", escrowDstImpl);
        vm.serializeUint(json, "chainId", block.chainid);
        vm.serializeUint(json, "blockNumber", block.number);
        vm.serializeUint(json, "timestamp", block.timestamp);
        vm.serializeString(json, "bugfix", "Fixed InvalidCreationTime error by aligning dstCancellation with srcCancellation");
        
        string memory finalJson = vm.serializeString(json, "deployedBy", vm.toString(vm.addr(vm.envUint("DEPLOYER_PRIVATE_KEY"))));
        
        string memory filename = string.concat(
            "./deployments/v3_0_1_",
            vm.toString(block.chainid),
            "_",
            vm.toString(block.timestamp),
            ".json"
        );
        
        vm.writeJson(finalJson, filename);
        console.log("Deployment saved to:", filename);
    }
}