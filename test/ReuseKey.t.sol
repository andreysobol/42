// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {NFT42} from "../src/42.sol";
import {MintGuard} from "../src/MintGuard.sol";

contract ReuseAddressTest is Test {
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
        vm.deal(buyer, 2 ether); // Fund for two purchases
    }

    function test_reuse_address_first_buy_succeeds_second_reverts() public {
        bytes32 digest = keccak256(abi.encodePacked(buyer));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(voucherSignerPk, digest);

        MintGuard.Voucher memory voucher = MintGuard.Voucher({minter: buyer, v: v, r: r, s: s});

        // First buy should succeed
        vm.prank(buyer);
        uint256 tokenId = mintGuard.mint{value: FEE}(voucher);
        assertEq(nft.ownerOf(tokenId), buyer, "First buy: owner should be buyer");
        assertTrue(mintGuard.mint_address(buyer), "First buy: address should be marked as minted");

        // Second buy with same address should fail
        vm.prank(buyer);
        vm.expectRevert(MintGuard.AlreadyMinted.selector);
        mintGuard.mint{value: FEE}(voucher);
    }
}
