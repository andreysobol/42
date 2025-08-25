// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {NFT42} from "../src/42.sol";
import {MintGuard} from "../src/Sale.sol";

contract ReuseAddressTest is Test {
    NFT42 private nft;
    MintGuard private sale;

    address private permissionSigner;
    uint256 private permissionSignerPk;

    address private buyer;

    uint256 private constant PRICE = 0.01 ether;

    function setUp() public {
        permissionSignerPk = 0xA11CE;
        permissionSigner = vm.addr(permissionSignerPk);

        address predictedSale = vm.computeCreateAddress(address(this), vm.getNonce(address(this)) + 1);
        nft = new NFT42("ipfs://base/", predictedSale);
        sale = new MintGuard(nft, PRICE, permissionSigner);

        buyer = makeAddr("buyer");
        vm.deal(buyer, 2 ether); // Fund for two purchases
    }

    function test_reuse_address_first_buy_succeeds_second_reverts() public {
        bytes32 digest = keccak256(abi.encodePacked(buyer));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(permissionSignerPk, digest);

        MintGuard.Permission memory perm = MintGuard.Permission({minter: buyer, v: v, r: r, s: s});

        // First buy should succeed
        vm.prank(buyer);
        uint256 tokenId = sale.buy{value: PRICE}(perm);
        assertEq(nft.ownerOf(tokenId), buyer, "First buy: owner should be buyer");
        assertTrue(sale.mint_address(buyer), "First buy: address should be marked as minted");

        // Second buy with same address should fail
        vm.prank(buyer);
        vm.expectRevert(MintGuard.AlreadyMinted.selector);
        sale.buy{value: PRICE}(perm);
    }
}
