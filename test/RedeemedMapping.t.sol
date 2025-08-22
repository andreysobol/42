// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {NFT42} from "../src/42.sol";
import {Sale} from "../src/Sale.sol";

contract RedeemedMappingTest is Test {
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
        vm.deal(buyer, 2 ether);
    }

    function test_redeemed_mapping_visibility() public {
        uint32 key = 42;

        // Check that key is not redeemed before purchase
        assertFalse(sale.redeemed_key(key), "Key should not be redeemed before purchase");

        bytes32 digest = keccak256(abi.encodePacked(buyer, key));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(permissionSignerPk, digest);

        Sale.Permission memory perm = Sale.Permission({minter: buyer, key: key, v: v, r: r, s: s});

        vm.prank(buyer);
        sale.buy{value: PRICE}(perm);

        // Check that key is redeemed after purchase
        assertTrue(sale.redeemed_key(key), "Key should be redeemed after purchase");
    }

    function test_multiple_keys_redeemed_mapping() public {
        uint32 key1 = 100;
        uint32 key2 = 200;
        uint32 key3 = 300;

        // Check all keys are not redeemed initially
        assertFalse(sale.redeemed_key(key1), "Key1 should not be redeemed initially");
        assertFalse(sale.redeemed_key(key2), "Key2 should not be redeemed initially");
        assertFalse(sale.redeemed_key(key3), "Key3 should not be redeemed initially");

        // Purchase with key1
        bytes32 digest = keccak256(abi.encodePacked(buyer, key1));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(permissionSignerPk, digest);

        Sale.Permission memory perm = Sale.Permission({minter: buyer, key: key1, v: v, r: r, s: s});

        vm.prank(buyer);
        sale.buy{value: PRICE}(perm);

        // Check only key1 is redeemed
        assertTrue(sale.redeemed_key(key1), "Key1 should be redeemed after purchase");
        assertFalse(sale.redeemed_key(key2), "Key2 should still not be redeemed");
        assertFalse(sale.redeemed_key(key3), "Key3 should still not be redeemed");

        // Purchase with key2
        digest = keccak256(abi.encodePacked(buyer, key2));
        (v, r, s) = vm.sign(permissionSignerPk, digest);

        perm = Sale.Permission({minter: buyer, key: key2, v: v, r: r, s: s});

        vm.prank(buyer);
        sale.buy{value: PRICE}(perm);

        // Check key1 and key2 are redeemed, key3 is not
        assertTrue(sale.redeemed_key(key1), "Key1 should still be redeemed");
        assertTrue(sale.redeemed_key(key2), "Key2 should be redeemed after purchase");
        assertFalse(sale.redeemed_key(key3), "Key3 should still not be redeemed");
    }
}
