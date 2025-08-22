// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {NFT42} from "../src/42.sol";
import {Sale} from "../src/Sale.sol";

contract OnlySaleMintTest is Test {
    NFT42 private nft;
    Sale private sale;

    address private permissionSigner;
    uint256 private permissionSignerPk;

    address private buyer;
    address private nonSaleAddress;

    uint256 private constant PRICE = 0.01 ether;

    function setUp() public {
        permissionSignerPk = 0xA11CE;
        permissionSigner = vm.addr(permissionSignerPk);

        address predictedSale = vm.computeCreateAddress(address(this), vm.getNonce(address(this)) + 1);
        nft = new NFT42("ipfs://base/", predictedSale);
        sale = new Sale(nft, PRICE, permissionSigner);

        buyer = makeAddr("buyer");
        nonSaleAddress = makeAddr("nonSaleAddress");
        vm.deal(buyer, 1 ether);
    }

    function test_only_sale_can_mint() public {
        // Try to mint directly from non-sale address
        vm.prank(nonSaleAddress);
        vm.expectRevert("Not sale");
        nft.mint(buyer);
    }

    function test_sale_can_mint() public {
        // Sale should be able to mint
        vm.prank(address(sale));
        uint256 tokenId = nft.mint(buyer);
        assertEq(nft.ownerOf(tokenId), buyer, "Owner should be buyer");
    }
}
