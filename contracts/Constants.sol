// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

/**
 * @title Constants
 * @notice Global constants used throughout the Bridge Me Not protocol
 */
library Constants {
    // BMN Token address (same on all chains via CREATE2)
    address constant BMN_TOKEN = 0x8287CD2aC7E227D9D927F998EB600a0683a832A1;
    
    // Key addresses from BMN token deployment
    address constant BMN_DEPLOYER = 0x5f29827e25dc174a6A51C99e6811Bbd7581285b0;
    address constant ALICE = 0x240E2588e35FB9D3D60B283B45108a49972FFFd8;
    address constant BOB_RESOLVER = 0xfdF1dDeB176BEA06c7430166e67E615bC312b7B5;
    
    // CREATE2 Factory used for BMN deployment
    address constant CREATE2_FACTORY = 0x4e59b44847b379578588920cA78FbF26c0B4956C;
}