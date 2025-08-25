// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {NFT42} from "../src/42.sol";
import {Sale} from "../src/Sale.sol";

contract SuccessTest is Test {
    NFT42 private nft;
    Sale private sale;

    address private permissionSigner;
    uint256 private permissionSignerPk;

    address private buyer;
    address private receiver;

    uint256 private constant PRICE = 0.01 ether;

    function setUp() public {
        permissionSignerPk = 0xA11CE;
        permissionSigner = vm.addr(permissionSignerPk);

        address predictedSale = vm.computeCreateAddress(address(this), vm.getNonce(address(this)) + 1);
        nft = new NFT42("ipfs://base/", predictedSale);
        sale = new Sale(nft, PRICE, permissionSigner);

        buyer = makeAddr("buyer");
        receiver = makeAddr("receiver");
        vm.deal(buyer, 1 ether);
    }

    function test_successful_buy_and_transfer() public {
        bytes32 digest = keccak256(abi.encodePacked(buyer));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(permissionSignerPk, digest);

        Sale.Permission memory perm = Sale.Permission({minter: buyer, v: v, r: r, s: s});

        assertEq(nft.totalSupply(), 0, "total supply should be 0 before minting");

        // Expect Purchased event; check buyer (topic1) and data (price), ignore tokenId
        vm.expectEmit(true, false, false, true);
        emit Sale.Purchased(buyer, 0, PRICE);

        vm.prank(buyer);
        uint256 tokenId = sale.buy{value: PRICE}(perm);

        assertEq(nft.totalSupply(), 1, "total supply should be 1 after minting");
        assertEq(nft.ownerOf(tokenId), buyer, "owner should be buyer");

        vm.prank(buyer);
        nft.safeTransferFrom(buyer, receiver, tokenId);
        assertEq(nft.ownerOf(tokenId), receiver, "owner should be receiver after transfer");
        assertEq(nft.balanceOf(buyer), 0, "buyer should no longer own any NFT");
        assertEq(nft.balanceOf(receiver), 1, "receiver should own 1 NFT");
        assertEq(nft.totalSupply(), 1, "total supply should still be 1");
    }
}
