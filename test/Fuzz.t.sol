// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {NFT42} from "../src/42.sol";
import {Sale} from "../src/Sale.sol";

contract FuzzTest is Test {
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
        vm.deal(buyer, 1000 ether); // Fund for many purchases
    }

    function testFuzz_random_keys_uniqueness(uint32 key) public {
        // Skip if key is 0 to avoid potential issues
        vm.assume(key != 0);

        bytes32 digest = keccak256(abi.encodePacked(buyer, key));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(permissionSignerPk, digest);

        Sale.Permission memory perm = Sale.Permission({minter: buyer, key: key, v: v, r: r, s: s});

        // First purchase should succeed
        vm.prank(buyer);
        uint256 tokenId = sale.buy{value: PRICE}(perm);
        assertEq(nft.ownerOf(tokenId), buyer, "Owner should be buyer");
        assertTrue(sale.redeemed_key(key), "Key should be marked redeemed");

        // Second purchase with same key should fail
        vm.prank(buyer);
        vm.expectRevert(Sale.KeyAlreadyRedeemed.selector);
        sale.buy{value: PRICE}(perm);
    }

    function testFuzz_multiple_random_keys(uint32[5] memory keys) public {
        for (uint256 i = 0; i < keys.length; i++) {
            uint32 key = keys[i];
            vm.assume(key != 0); // Skip zero keys

            // Skip if key was already used in this test
            if (sale.redeemed_key(key)) continue;

            bytes32 digest = keccak256(abi.encodePacked(buyer, key));
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(permissionSignerPk, digest);

            Sale.Permission memory perm = Sale.Permission({minter: buyer, key: key, v: v, r: r, s: s});

            // Purchase should succeed for unique keys
            vm.prank(buyer);
            uint256 tokenId = sale.buy{value: PRICE}(perm);
            assertEq(nft.ownerOf(tokenId), buyer, "Owner should be buyer");
            assertTrue(sale.redeemed_key(key), "Key should be marked redeemed");
        }
    }

    function testFuzz_random_minter_and_key(address minter, uint32 key) public {
        vm.assume(minter != address(0));
        vm.assume(key != 0);
        vm.assume(minter.code.length == 0); // Skip contract addresses

        bytes32 digest = keccak256(abi.encodePacked(minter, key));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(permissionSignerPk, digest);

        Sale.Permission memory perm = Sale.Permission({minter: minter, key: key, v: v, r: r, s: s});

        vm.deal(minter, PRICE);
        vm.prank(minter);
        uint256 tokenId = sale.buy{value: PRICE}(perm);
        assertEq(nft.ownerOf(tokenId), minter, "Owner should be minter");
        assertTrue(sale.redeemed_key(key), "Key should be marked redeemed");
    }
}
