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

    uint256 private constant PRICE = 0.01 ether;

    function setUp() public {
        permissionSignerPk = 0xA11CE;
        permissionSigner = vm.addr(permissionSignerPk);

        address predictedSale = vm.computeCreateAddress(address(this), vm.getNonce(address(this)) + 1);
        nft = new NFT42("ipfs://base/", predictedSale);
        sale = new Sale(nft, PRICE, permissionSigner);

        buyer = makeAddr("buyer");
        vm.deal(buyer, 1 ether);
    }

    function test_successful_buy_with_valid_signature() public {
        uint32 key = 42;
        bytes32 digest = keccak256(abi.encodePacked(buyer, key));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(permissionSignerPk, digest);

        Sale.Permission memory perm = Sale.Permission({minter: buyer, key: key, v: v, r: r, s: s});

        // Expect Purchased event; check buyer (topic1) and data (price), ignore tokenId
        vm.expectEmit(true, false, false, true);
        emit Sale.Purchased(buyer, 0, PRICE);

        vm.prank(buyer);
        uint256 tokenId = sale.buy{value: PRICE}(perm);

        assertEq(nft.ownerOf(tokenId), buyer, "owner should be buyer");
        assertTrue(sale.redeemed_key(key), "key should be marked redeemed");
    }
}
