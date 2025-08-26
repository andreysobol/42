// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {NFT42} from "../src/42.sol";
import {MintGuard} from "../src/MintGuard.sol";
import {TransparentUpgradeableProxy} from
    "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract UpdateSignerTest is Test {
    NFT42 private nft;
    MintGuard private mintGuard;

    address private voucherSigner;
    uint256 private voucherSignerPk;

    address private newSigner;
    uint256 private newSignerPk;

    address private buyer;

    uint256 private constant FEE = 0.01 ether;

    function setUp() public {
        voucherSignerPk = 0xA11CE;
        voucherSigner = vm.addr(voucherSignerPk);

        newSignerPk = 0xB0B;
        newSigner = vm.addr(newSignerPk);

        address predictedMintGuard = vm.computeCreateAddress(address(this), vm.getNonce(address(this)) + 2);
        nft = new NFT42("ipfs://base/", predictedMintGuard, 1024);
        mintGuard = MintGuard(
            payable(
                new TransparentUpgradeableProxy(
                    address(new MintGuard()),
                    address(this),
                    abi.encodeWithSelector(MintGuard.initialize.selector, nft, FEE, voucherSigner, address(this))
                )
            )
        );

        buyer = makeAddr("buyer");
        vm.deal(buyer, 2 ether);
    }

    function test_update_permission_signer() public {
        // Sign with old signer
        bytes32 digest = keccak256(abi.encodePacked(buyer));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(voucherSignerPk, digest);

        MintGuard.Voucher memory voucher;
        voucher = MintGuard.Voucher({minter: buyer, v: v, r: r, s: s});

        // Old signer should work before update
        vm.prank(buyer);
        uint256 tokenId = mintGuard.mint{value: FEE}(voucher);
        assertEq(nft.ownerOf(tokenId), buyer, "Old signer should work before update");

        // Update permission signer
        vm.prank(address(this));
        mintGuard.setVoucherSigner(newSigner);

        // Old signer should not work after update
        address buyer2 = address(uint160(uint160(buyer) + 1));
        vm.deal(buyer2, 2 ether);
        digest = keccak256(abi.encodePacked(buyer2));
        (v, r, s) = vm.sign(voucherSignerPk, digest);

        voucher = MintGuard.Voucher({minter: buyer2, v: v, r: r, s: s});

        vm.prank(buyer2);
        vm.expectRevert(MintGuard.InvalidSignature.selector);
        mintGuard.mint{value: FEE}(voucher);

        // New signer should work after update
        address buyer3 = address(uint160(uint160(buyer) + 2));
        vm.deal(buyer3, 2 ether);
        digest = keccak256(abi.encodePacked(buyer3));
        (v, r, s) = vm.sign(newSignerPk, digest);

        voucher = MintGuard.Voucher({minter: buyer3, v: v, r: r, s: s});

        vm.prank(buyer3);
        tokenId = mintGuard.mint{value: FEE}(voucher);
        assertEq(nft.ownerOf(tokenId), buyer3, "New signer should work after update");
    }
}
