// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {NFT42} from "../src/42.sol";
import {Sale} from "../src/Sale.sol";

contract SaleTest is Test {
    NFT42 private nft;
    Sale private sale;

    address private permissionSigner;
    uint256 private permissionSignerPk;

    address private buyer;

    uint256 private constant PRICE = 0.01 ether;

    function setUp() public {
        // Setup signer keypair
        permissionSignerPk = 0xA11CE;
        permissionSigner = vm.addr(permissionSignerPk);

        // Predict the Sale address (next deployment by this contract)
        address predictedSale = vm.computeCreateAddress(address(this), vm.getNonce(address(this)) + 1);

        // Deploy NFT42 with the predicted sale address so only that address can mint
        nft = new NFT42("ipfs://base/", predictedSale);

        // Deploy Sale with the actual NFT address and signer
        sale = new Sale(nft, PRICE, permissionSigner);

        // Fund a buyer address
        buyer = makeAddr("buyer");
        vm.deal(buyer, 1 ether);
    }

    function test_verifyPermission_and_buy_success() public {
        // Prepare permission for the buyer with a unique key
        uint32 key = 42;
        bytes32 digest = keccak256(abi.encodePacked(buyer, key));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(permissionSignerPk, digest);

        // Build Permission struct
        // struct Permission { address minter; uint32 key; uint8 v; bytes32 r; bytes32 s; }
        Sale.Permission memory perm = Sale.Permission({minter: buyer, key: key, v: v, r: r, s: s});

        // Execute buy
        vm.prank(buyer);
        uint256 tokenId = sale.buy{value: PRICE}(perm);

        // Assertions
        assertEq(nft.ownerOf(tokenId), buyer, "owner should be buyer");
        assertTrue(sale.redeemed_key(key), "key should be marked redeemed");
    }

    function test_verifyPermission_invalidSignature_reverts() public {
        uint32 key = 7;
        bytes32 digest = keccak256(abi.encodePacked(buyer, key));

        // Sign with the wrong keypair
        uint256 wrongPk = 0xB0B;
        (, bytes32 r, bytes32 s) = vm.sign(wrongPk, digest);
        // Force a v that won't match signer (27 here is fine; r,s are wrong)
        uint8 v = 27;

        Sale.Permission memory perm = Sale.Permission({minter: buyer, key: key, v: v, r: r, s: s});

        vm.prank(buyer);
        vm.expectRevert(Sale.IncorrectPermission.selector);
        sale.buy{value: PRICE}(perm);
    }
}
