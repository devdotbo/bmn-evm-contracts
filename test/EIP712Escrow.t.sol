// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Test.sol";
import { Clones } from "openzeppelin-contracts/contracts/proxy/Clones.sol";
import { EscrowSrc } from "../contracts/EscrowSrc.sol";
import { EscrowDst } from "../contracts/EscrowDst.sol";
import { SimplifiedEscrowFactoryV2_3 } from "../contracts/SimplifiedEscrowFactoryV2_3.sol";
import { IBaseEscrow } from "../contracts/interfaces/IBaseEscrow.sol";
import { TokenMock } from "../contracts/mocks/TokenMock.sol";
import { Timelocks } from "../contracts/libraries/TimelocksLib.sol";
import { Address } from "solidity-utils/contracts/libraries/AddressLib.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract EIP712EscrowTest is Test {
    address deployer = address(uint160(uint256(keccak256("DEPLOYER"))));
    uint256 resolverPk = 0xBEEF;
    address resolver = vm.addr(resolverPk);
    address maker = address(0xA11CE);
    address taker = address(0xB0B);

    TokenMock bmn;
    SimplifiedEscrowFactoryV2_3 factory;

    function setUp() public {
        vm.startPrank(deployer);
        bmn = new TokenMock("BMN", "BMN", 18);
        bmn.mint(resolver, 1e18);
        bmn.mint(maker, 100e18);

        factory = new SimplifiedEscrowFactoryV2_3(IERC20(address(bmn)), deployer, 1 hours);
        factory.addResolver(resolver);
        vm.stopPrank();
    }

    function _buildImmutables(bytes32 orderHash, address token, uint256 amount) internal view returns (IBaseEscrow.Immutables memory) {
        uint256 nowTs = block.timestamp;
        uint256 packed = uint256(uint32(nowTs)) << 224;
        return IBaseEscrow.Immutables({
            orderHash: orderHash,
            hashlock: bytes32(uint256(0x1234)),
            maker: Address.wrap(uint160(maker)),
            taker: Address.wrap(uint160(taker)),
            token: Address.wrap(uint160(token)),
            amount: amount,
            safetyDeposit: 0,
            timelocks: Timelocks.wrap(packed)
        });
    }

    function test_EIP712_DomainAndDigest() public {
        // Use the deployed src implementation to get typehash-based digest
        address srcImpl = factory.ESCROW_SRC_IMPLEMENTATION();
        IBaseEscrow.Immutables memory im = _buildImmutables(bytes32(uint256(0xABCD)), address(bmn), 1e18);
        // Call into the implementation to get digest (via public function on BaseEscrow helper)
        bytes32 digest = EscrowSrc(srcImpl)._hashPublicAction(im.orderHash, resolver, "SRC_PUBLIC_WITHDRAW");
        assertTrue(digest != bytes32(0), "digest should be non-zero");

        // Sign with resolver key
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(resolverPk, digest);
        bytes memory sig = abi.encodePacked(r, s, v);

        // Ensure recover matches resolver via the same helper
        address recovered = EscrowSrc(srcImpl)._recover(digest, sig);
        assertEq(recovered, resolver, "recovered signer must equal resolver");
    }
}


