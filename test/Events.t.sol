// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {NFT42} from "../src/42.sol";
import {Sale} from "../src/Sale.sol";

contract EventsTest is Test {
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

    function test_purchased_event_logs_correct_data() public {
        uint32 key = 42;
        bytes32 digest = keccak256(abi.encodePacked(buyer, key));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(permissionSignerPk, digest);

        Sale.Permission memory perm = Sale.Permission({minter: buyer, key: key, v: v, r: r, s: s});

        // Expect Purchased event with correct buyer, tokenId, and price
        vm.expectEmit(true, true, false, true);
        emit Sale.Purchased(buyer, 0, PRICE);

        vm.prank(buyer);
        sale.buy{value: PRICE}(perm);
    }

    function test_price_updated_event() public {
        uint256 newPrice = 0.02 ether;

        vm.expectEmit(false, false, false, true);
        emit Sale.PriceUpdated(PRICE, newPrice);

        sale.setPrice(newPrice);
    }

    function test_permission_signer_updated_event() public {
        address newSigner = makeAddr("newSigner");

        vm.expectEmit(true, true, false, false);
        emit Sale.PermissionSignerUpdated(permissionSigner, newSigner);

        sale.setPermissionSigner(newSigner);
    }
}
