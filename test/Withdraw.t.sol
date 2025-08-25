// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {NFT42} from "../src/42.sol";
import {Sale} from "../src/Sale.sol";

contract WithdrawTest is Test {
    NFT42 private nft;
    Sale private sale;

    address private permissionSigner;
    uint256 private permissionSignerPk;

    address private buyer;
    address private owner;

    uint256 private constant PRICE = 0.01 ether;

    function setUp() public {
        permissionSignerPk = 0xA11CE;
        permissionSigner = vm.addr(permissionSignerPk);

        address predictedSale = vm.computeCreateAddress(address(this), vm.getNonce(address(this)) + 1);
        nft = new NFT42("ipfs://base/", predictedSale);
        sale = new Sale(nft, PRICE, permissionSigner);

        buyer = makeAddr("buyer");
        owner = makeAddr("owner");
        vm.deal(buyer, 2 ether);
        vm.deal(owner, 1 ether);
    }

    function test_withdraw_after_purchases() public {
        // Make a purchase to add balance to sale contract
        bytes32 digest = keccak256(abi.encodePacked(buyer));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(permissionSignerPk, digest);

        Sale.Permission memory perm = Sale.Permission({minter: buyer, v: v, r: r, s: s});

        uint256 testContractBalanceBefore = address(this).balance;
        uint256 saleBalanceBefore = address(sale).balance;

        vm.prank(buyer);
        sale.buy{value: PRICE}(perm);

        // Verify sale contract has the payment
        assertEq(address(sale).balance, saleBalanceBefore + PRICE, "Sale should have received payment");

        // Owner withdraws (test contract is the owner)
        sale.withdraw();

        // Verify balance transferred to owner
        assertEq(address(this).balance, testContractBalanceBefore + PRICE, "Test contract should receive payment");
        assertEq(address(sale).balance, 0, "Sale balance should be zero");
    }

    function test_non_owner_cannot_withdraw() public {
        address nonOwner = makeAddr("nonOwner");

        vm.prank(nonOwner);
        vm.expectRevert(Sale.NotOwner.selector);
        sale.withdraw();
    }

    // Allow test contract to receive ETH
    receive() external payable {}
}
