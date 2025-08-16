// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { SimplifiedEscrowFactory } from "./SimplifiedEscrowFactory.sol";
import { EscrowSrc } from "./EscrowSrc.sol";
import { EscrowDst } from "./EscrowDst.sol";

/**
 * @title SimplifiedEscrowFactoryV3_0_2
 * @notice v3.0.2 Factory deployment that fixes the FACTORY immutable bug.
 * @dev This factory deploys its own escrow implementations in the constructor
 *      ensuring that the FACTORY immutable inside escrows correctly points
 *      to this factory address rather than the CREATE3 factory.
 *      
 *      The bug was that when implementations were deployed via CREATE3,
 *      msg.sender was the CREATE3 factory, causing validation failures.
 *      This approach ensures msg.sender during implementation deployment
 *      is the actual SimplifiedEscrowFactory.
 */
contract SimplifiedEscrowFactoryV3_0_2 is SimplifiedEscrowFactory {
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