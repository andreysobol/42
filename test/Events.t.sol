// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {NFT42} from "../src/42.sol";
import {MintGuard} from "../src/Sale.sol";

contract EventsTest is Test {
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
        vm.deal(buyer, 2 ether);
    }

    function test_purchased_event_logs_correct_data() public {
        bytes32 digest = keccak256(abi.encodePacked(buyer));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(permissionSignerPk, digest);

        MintGuard.Permission memory perm = MintGuard.Permission({minter: buyer, v: v, r: r, s: s});

        // Expect Purchased event with correct buyer, tokenId, and price
        vm.expectEmit(true, true, false, true);
        emit MintGuard.Purchased(buyer, 0, PRICE);

        vm.prank(buyer);
        sale.buy{value: PRICE}(perm);
    }

    function test_price_updated_event() public {
        uint256 newPrice = 0.02 ether;

        vm.expectEmit(false, false, false, true);
        emit MintGuard.PriceUpdated(PRICE, newPrice);

        sale.setPrice(newPrice);
    }

    function test_permission_signer_updated_event() public {
        address newSigner = makeAddr("newSigner");

        vm.expectEmit(true, true, false, false);
        emit MintGuard.PermissionSignerUpdated(permissionSigner, newSigner);

        sale.setPermissionSigner(newSigner);
    }
}
