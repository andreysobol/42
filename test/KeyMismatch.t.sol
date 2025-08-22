// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {NFT42} from "../src/42.sol";
import {Sale} from "../src/Sale.sol";

contract KeyMismatchTest is Test {
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

    function test_signature_over_different_key() public {
        uint32 keyA = 42;
        uint32 keyB = 7;

        // Sign for keyA but try to use keyB
        bytes32 digest = keccak256(abi.encodePacked(buyer, keyA));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(permissionSignerPk, digest);

        Sale.Permission memory perm = Sale.Permission({
            minter: buyer,
            key: keyB, // Different from what was signed (keyA)
            v: v,
            r: r,
            s: s
        });

        vm.prank(buyer);
        vm.expectRevert(Sale.IncorrectPermission.selector);
        sale.buy{value: PRICE}(perm);
    }
}
