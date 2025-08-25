// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {NFT42} from "../src/42.sol";
import {MintGuard} from "../src/Sale.sol";

contract MinterMismatchTest is Test {
    NFT42 private nft;
    MintGuard private sale;

    address private permissionSigner;
    uint256 private permissionSignerPk;

    address private buyer;
    address private other;

    uint256 private constant PRICE = 0.01 ether;

    function setUp() public {
        permissionSignerPk = 0xA11CE;
        permissionSigner = vm.addr(permissionSignerPk);

        address predictedSale = vm.computeCreateAddress(address(this), vm.getNonce(address(this)) + 1);
        nft = new NFT42("ipfs://base/", predictedSale);
        sale = new MintGuard(nft, PRICE, permissionSigner);

        buyer = makeAddr("buyer");
        other = makeAddr("other");
        vm.deal(buyer, 1 ether);
        vm.deal(other, 1 ether);
    }

    function test_signature_over_different_minter() public {
        // Sign for 'other' address but try to use for 'buyer'
        bytes32 digest = keccak256(abi.encodePacked(other));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(permissionSignerPk, digest);

        MintGuard.Permission memory perm = MintGuard.Permission({
            minter: buyer, // Different from what was signed (other)
            v: v,
            r: r,
            s: s
        });

        vm.prank(buyer);
        vm.expectRevert(MintGuard.IncorrectPermission.selector);
        sale.buy{value: PRICE}(perm);
    }
}
