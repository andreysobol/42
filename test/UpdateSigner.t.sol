// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {NFT42} from "../src/42.sol";
import {Sale} from "../src/Sale.sol";

contract UpdateSignerTest is Test {
    NFT42 private nft;
    Sale private sale;

    address private permissionSigner;
    uint256 private permissionSignerPk;

    address private newSigner;
    uint256 private newSignerPk;

    address private buyer;

    uint256 private constant PRICE = 0.01 ether;

    function setUp() public {
        permissionSignerPk = 0xA11CE;
        permissionSigner = vm.addr(permissionSignerPk);

        newSignerPk = 0xB0B;
        newSigner = vm.addr(newSignerPk);

        address predictedSale = vm.computeCreateAddress(address(this), vm.getNonce(address(this)) + 1);
        nft = new NFT42("ipfs://base/", predictedSale);
        sale = new Sale(nft, PRICE, permissionSigner);

        buyer = makeAddr("buyer");
        vm.deal(buyer, 2 ether);
    }

    function test_update_permission_signer() public {
        uint32 key = 42;

        // Sign with old signer
        bytes32 digest = keccak256(abi.encodePacked(buyer, key));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(permissionSignerPk, digest);

        Sale.Permission memory perm = Sale.Permission({minter: buyer, key: key, v: v, r: r, s: s});

        // Old signer should work before update
        vm.prank(buyer);
        uint256 tokenId = sale.buy{value: PRICE}(perm);
        assertEq(nft.ownerOf(tokenId), buyer, "Old signer should work before update");

        // Update permission signer
        vm.prank(address(this));
        sale.setPermissionSigner(newSigner);

        // Old signer should not work after update
        uint32 key2 = 43;
        digest = keccak256(abi.encodePacked(buyer, key2));
        (v, r, s) = vm.sign(permissionSignerPk, digest);

        perm = Sale.Permission({minter: buyer, key: key2, v: v, r: r, s: s});

        vm.prank(buyer);
        vm.expectRevert(Sale.IncorrectPermission.selector);
        sale.buy{value: PRICE}(perm);

        // New signer should work after update
        uint32 key3 = 44;
        digest = keccak256(abi.encodePacked(buyer, key3));
        (v, r, s) = vm.sign(newSignerPk, digest);

        perm = Sale.Permission({minter: buyer, key: key3, v: v, r: r, s: s});

        vm.prank(buyer);
        tokenId = sale.buy{value: PRICE}(perm);
        assertEq(nft.ownerOf(tokenId), buyer, "New signer should work after update");
    }
}
