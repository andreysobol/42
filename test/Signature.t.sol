// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {NFT42} from "../src/42.sol";
import {Sale} from "../src/Sale.sol";

contract SignatureTest is Test {
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

    function test_signature_verifyPermission_and_buy_success() public {
        bytes32 digest = keccak256(abi.encodePacked(buyer));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(permissionSignerPk, digest);

        Sale.Permission memory perm = Sale.Permission({minter: buyer, v: v, r: r, s: s});

        vm.prank(buyer);
        uint256 tokenId = sale.buy{value: PRICE}(perm);
        assertEq(nft.ownerOf(tokenId), buyer);
        assertTrue(sale.mint_address(buyer));
    }

    function test_signature_invalidSignature_reverts() public {
        bytes32 digest = keccak256(abi.encodePacked(buyer));
        uint256 wrongPk = 0xB0B;
        (, bytes32 r, bytes32 s) = vm.sign(wrongPk, digest);
        uint8 v = 27;

        Sale.Permission memory perm = Sale.Permission({minter: buyer, v: v, r: r, s: s});

        vm.prank(buyer);
        vm.expectRevert(Sale.IncorrectPermission.selector);
        sale.buy{value: PRICE}(perm);
    }
}
