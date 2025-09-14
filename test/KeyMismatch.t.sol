// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {NFT42} from "../src/42.sol";
import {MintGuard} from "../src/MintGuard.sol";
import {TransparentUpgradeableProxy} from
    "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract MinterMismatchTest is Test {
    NFT42 private nft;
    MintGuard private mintGuard;

    address private voucherSigner;
    uint256 private voucherSignerPk;

    address private buyer1;
    address private buyer2;

    uint256 private constant FEE = 0.01 ether;

    function setUp() public {
        voucherSignerPk = 0xA11CE;
        voucherSigner = vm.addr(voucherSignerPk);

        address predictedMintGuard = vm.computeCreateAddress(address(this), vm.getNonce(address(this)) + 2);
        nft = new NFT42("ipfs://base/", predictedMintGuard, 1024);
        mintGuard = MintGuard(
            payable(
                new TransparentUpgradeableProxy(
                    address(new MintGuard()),
                    address(this),
                    abi.encodeWithSelector(MintGuard.initialize.selector, FEE, voucherSigner, address(this))
                )
            )
        );
        mintGuard.setNft(nft);
        mintGuard.start(address(0), 0); // Start minting without admin minting

        buyer1 = makeAddr("buyer1");
        buyer2 = makeAddr("buyer2");
        vm.deal(buyer1, 1 ether);
        vm.deal(buyer2, 1 ether);
    }

    function test_signature_over_different_minter() public {
        // Sign for buyer1 but try to use buyer2
        bytes32 digest = keccak256(abi.encodePacked(buyer1));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(voucherSignerPk, digest);

        MintGuard.Voucher memory voucher = MintGuard.Voucher({
            minter: buyer2, // Different from what was signed (buyer1)
            v: v,
            r: r,
            s: s
        });

        vm.prank(buyer2);
        vm.expectRevert(MintGuard.InvalidSignature.selector);
        mintGuard.mint{value: FEE}(voucher);
    }
}
