// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { SimplifiedEscrowFactory } from "./SimplifiedEscrowFactory.sol";
import { EscrowSrc } from "./EscrowSrc.sol";
import { EscrowDst } from "./EscrowDst.sol";

/**
 * @title SimplifiedEscrowFactoryV2_3
 * @notice Factory that deploys its own escrow implementations so immutables
 *         (FACTORY) inside escrows point to this factory (required for EIP-712 checks).
 */
contract SimplifiedEscrowFactoryV2_3 is SimplifiedEscrowFactory {
    /**
     * @param accessToken BMN / access token used by escrows (kept for backward compat)
     * @param _owner Factory owner
     * @param rescueDelay Rescue delay for escrows
     */
    constructor(IERC20 accessToken, address _owner, uint32 rescueDelay)
        SimplifiedEscrowFactory(
            address(new EscrowSrc(rescueDelay, accessToken)),
            address(new EscrowDst(rescueDelay, accessToken)),
            _owner
        )
    {}
}


