// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {NFT42} from "../src/42.sol";
import {Sale} from "../src/Sale.sol";

contract InvalidTest is Test {
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

    function test_invalid_signature_wrong_private_key() public {
        uint32 key = 7;
        bytes32 digest = keccak256(abi.encodePacked(buyer, key));

        // Sign with the wrong private key
        uint256 wrongPk = 0xB0B;
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(wrongPk, digest);

        Sale.Permission memory perm = Sale.Permission({minter: buyer, key: key, v: v, r: r, s: s});

        vm.prank(buyer);
        vm.expectRevert(Sale.IncorrectPermission.selector);
        sale.buy{value: PRICE}(perm);
    }

    function test_wrong_signer_configured() public {
        uint32 key = 42;
        bytes32 digest = keccak256(abi.encodePacked(buyer, key));

        // Sign with the original permission signer
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(permissionSignerPk, digest);

        Sale.Permission memory perm = Sale.Permission({minter: buyer, key: key, v: v, r: r, s: s});

        // Change the permission signer to a new one
        address newSigner = makeAddr("newSigner");
        vm.prank(address(this));
        sale.setPermissionSigner(newSigner);

        // Try to use the old signer's signature - should fail
        vm.prank(buyer);
        vm.expectRevert(Sale.IncorrectPermission.selector);
        sale.buy{value: PRICE}(perm);
    }
}
