// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { Create3 } from "./libraries/Create3.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title Create3Factory
 * @notice Factory contract for deterministic cross-chain deployments using CREATE3
 * @dev Enables deployment at same address across all chains regardless of bytecode
 */
contract Create3Factory is Ownable {
    using Create3 for bytes32;

    /// @notice Emitted when a contract is deployed
    event ContractDeployed(
        address indexed deployer,
        address indexed deployed,
        bytes32 indexed salt
    );

    /// @notice Error when deployment fails
    error DeploymentFailed();

    /// @notice Error when trying to deploy with empty bytecode
    error EmptyBytecode();

    /// @notice Error when caller is not authorized
    error Unauthorized();

    /// @notice Mapping of deployer => salt => deployed address
    mapping(address => mapping(bytes32 => address)) public deployments;

    /// @notice Mapping of addresses authorized to deploy
    mapping(address => bool) public authorized;

    constructor(address _owner) Ownable(_owner) {
        // Authorize the owner by default
        authorized[_owner] = true;
    }

    /**
     * @notice Authorize an address to deploy contracts
     * @param account Address to authorize
     */
    function authorize(address account) external onlyOwner {
        authorized[account] = true;
    }

    /**
     * @notice Revoke deployment authorization
     * @param account Address to deauthorize
     */
    function deauthorize(address account) external onlyOwner {
        authorized[account] = false;
    }

    /**
     * @notice Deploy contract using CREATE3
     * @param salt Salt for deterministic deployment
     * @param creationCode Contract bytecode with constructor args
     * @return deployed Address of deployed contract
     */
    function deploy(
        bytes32 salt, 
        bytes calldata creationCode
    ) external returns (address deployed) {
        // Check authorization
        if (!authorized[msg.sender]) revert Unauthorized();
        
        // Validate bytecode
        if (creationCode.length == 0) revert EmptyBytecode();

        // Calculate unique salt including sender
        bytes32 uniqueSalt = keccak256(abi.encodePacked(msg.sender, salt));
        
        // Deploy using CREATE3
        deployed = Create3.create3(uniqueSalt, creationCode);
        
        // Store deployment info
        deployments[msg.sender][salt] = deployed;
        
        emit ContractDeployed(msg.sender, deployed, salt);
    }

    /**
     * @notice Deploy contract with ETH value using CREATE3
     * @param salt Salt for deterministic deployment
     * @param creationCode Contract bytecode with constructor args
     * @return deployed Address of deployed contract
     */
    function deployWithValue(
        bytes32 salt,
        bytes calldata creationCode
    ) external payable returns (address deployed) {
        // Check authorization
        if (!authorized[msg.sender]) revert Unauthorized();
        
        // Validate bytecode
        if (creationCode.length == 0) revert EmptyBytecode();

        // Calculate unique salt including sender
        bytes32 uniqueSalt = keccak256(abi.encodePacked(msg.sender, salt));
        
        // Deploy using CREATE3
        deployed = Create3.create3(uniqueSalt, creationCode, msg.value);
        
        // Store deployment info
        deployments[msg.sender][salt] = deployed;
        
        emit ContractDeployed(msg.sender, deployed, salt);
    }

    /**
     * @notice Get deployment address for given deployer and salt
     * @param deployer Address that will deploy
     * @param salt Deployment salt
     * @return Address where contract will be deployed
     */
    function getDeploymentAddress(
        address deployer,
        bytes32 salt
    ) external view returns (address) {
        bytes32 uniqueSalt = keccak256(abi.encodePacked(deployer, salt));
        return Create3.addressOf(uniqueSalt);
    }

    /**
     * @notice Check if contract is already deployed
     * @param deployer Address that deployed
     * @param salt Deployment salt
     * @return True if already deployed
     */
    function isDeployed(
        address deployer,
        bytes32 salt
    ) external view returns (bool) {
        address deployed = deployments[deployer][salt];
        return deployed != address(0) && Create3.codeSize(deployed) > 0;
    }
}