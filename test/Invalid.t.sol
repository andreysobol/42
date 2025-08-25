// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {NFT42} from "../src/42.sol";
import {MintGuard} from "../src/MintGuard.sol";

contract InvalidTest is Test {
    NFT42 private nft;
    MintGuard private mintGuard;

    address private voucherSigner;
    uint256 private voucherSignerPk;

    address private buyer;

    uint256 private constant FEE = 0.01 ether;

    function setUp() public {
        voucherSignerPk = 0xA11CE;
        voucherSigner = vm.addr(voucherSignerPk);

        address predictedMintGuard = vm.computeCreateAddress(address(this), vm.getNonce(address(this)) + 1);
        nft = new NFT42("ipfs://base/", predictedMintGuard, 1024);
        mintGuard = new MintGuard(nft, FEE, voucherSigner);

        buyer = makeAddr("buyer");
        vm.deal(buyer, 1 ether);
    }

    function test_invalid_signature_wrong_private_key() public {
        bytes32 digest = keccak256(abi.encodePacked(buyer));

        // Sign with the wrong private key
        uint256 wrongPk = 0xB0B;
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(wrongPk, digest);

        MintGuard.Voucher memory voucher = MintGuard.Voucher({minter: buyer, v: v, r: r, s: s});

        vm.prank(buyer);
        vm.expectRevert(MintGuard.InvalidSignature.selector);
        mintGuard.mint{value: FEE}(voucher);
    }

    function test_wrong_signer_configured() public {
        bytes32 digest = keccak256(abi.encodePacked(buyer));

        // Sign with the original permission signer
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(voucherSignerPk, digest);

        MintGuard.Voucher memory voucher = MintGuard.Voucher({minter: buyer, v: v, r: r, s: s});

        // Change the permission signer to a new one
        address newSigner = makeAddr("newSigner");
        vm.prank(address(this));
        mintGuard.setVoucherSigner(newSigner);

        // Try to use the old signer's signature - should fail
        vm.prank(buyer);
        vm.expectRevert(MintGuard.InvalidSignature.selector);
        mintGuard.mint{value: FEE}(voucher);
    }
}
