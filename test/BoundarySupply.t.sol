// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {NFT42} from "../src/42.sol";
import {Sale} from "../src/Sale.sol";

contract BoundarySupplyTest is Test {
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
        vm.deal(buyer, 2000 ether); // Fund for many purchases
    }

    function test_boundary_token_supply() public {
        // Mint up to 1023 tokens (0 to 1023 = 1024 total)
        for (uint32 i = 0; i < 1024; i++) {
            bytes32 digest = keccak256(abi.encodePacked(buyer, i));
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(permissionSignerPk, digest);

            Sale.Permission memory perm = Sale.Permission({minter: buyer, key: i, v: v, r: r, s: s});

            vm.prank(buyer);
            uint256 tokenId = sale.buy{value: PRICE}(perm);
            assertEq(tokenId, i, "Token ID should match key");
        }

        // Next buy should fail due to supply cap
        uint32 key = 1024;
        bytes32 digest = keccak256(abi.encodePacked(buyer, key));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(permissionSignerPk, digest);

        Sale.Permission memory perm = Sale.Permission({minter: buyer, key: key, v: v, r: r, s: s});

        vm.prank(buyer);
        vm.expectRevert("Maximum tokens (1024) already minted");
        sale.buy{value: PRICE}(perm);
    }
}
