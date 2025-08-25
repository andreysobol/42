// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {NFT42} from "../src/42.sol";
import {MintGuard} from "../src/Sale.sol";

contract FuzzTest is Test {
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
        vm.deal(buyer, 1000 ether); // Fund for many purchases
    }

    function testFuzz_random_addresses_uniqueness(address minter) public {
        // Skip if minter is zero address
        vm.assume(minter != address(0));
        vm.assume(minter.code.length == 0); // Skip contract addresses

        bytes32 digest = keccak256(abi.encodePacked(minter));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(permissionSignerPk, digest);

        MintGuard.Permission memory perm = MintGuard.Permission({minter: minter, v: v, r: r, s: s});

        // Fund the minter
        vm.deal(minter, PRICE);

        // First purchase should succeed
        vm.prank(minter);
        uint256 tokenId = sale.buy{value: PRICE}(perm);
        assertEq(nft.ownerOf(tokenId), minter, "Owner should be minter");
        assertTrue(sale.mint_address(minter), "Address should be marked as minted");

        // Second purchase with same address should fail
        vm.deal(minter, PRICE);
        vm.prank(minter);
        vm.expectRevert(MintGuard.AlreadyMinted.selector);
        sale.buy{value: PRICE}(perm);
    }

    function testFuzz_multiple_random_addresses(address[5] memory minters) public {
        for (uint256 i = 0; i < minters.length; i++) {
            address minter = minters[i];
            vm.assume(minter != address(0)); // Skip zero addresses
            vm.assume(minter.code.length == 0); // Skip contract addresses

            // Skip if address was already used in this test
            if (sale.mint_address(minter)) continue;

            bytes32 digest = keccak256(abi.encodePacked(minter));
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(permissionSignerPk, digest);

            MintGuard.Permission memory perm = MintGuard.Permission({minter: minter, v: v, r: r, s: s});

            // Fund the minter
            vm.deal(minter, PRICE);

            // Purchase should succeed for unique addresses
            vm.prank(minter);
            uint256 tokenId = sale.buy{value: PRICE}(perm);
            assertEq(nft.ownerOf(tokenId), minter, "Owner should be minter");
            assertTrue(sale.mint_address(minter), "Address should be marked as minted");
        }
    }

    function testFuzz_random_minter(address minter) public {
        vm.assume(minter != address(0));
        vm.assume(minter.code.length == 0); // Skip contract addresses

        bytes32 digest = keccak256(abi.encodePacked(minter));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(permissionSignerPk, digest);

        MintGuard.Permission memory perm = MintGuard.Permission({minter: minter, v: v, r: r, s: s});

        vm.deal(minter, PRICE);
        vm.prank(minter);
        uint256 tokenId = sale.buy{value: PRICE}(perm);
        assertEq(nft.ownerOf(tokenId), minter, "Owner should be minter");
        assertTrue(sale.mint_address(minter), "Address should be marked as minted");
    }
}
