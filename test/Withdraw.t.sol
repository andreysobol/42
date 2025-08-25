// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {NFT42} from "../src/42.sol";
import {MintGuard} from "../src/MintGuard.sol";

contract WithdrawTest is Test {
    NFT42 private nft;
    MintGuard private mintGuard;

    address private permissionSigner;
    uint256 private permissionSignerPk;

    address private buyer;
    address private owner;

    uint256 private constant PRICE = 0.01 ether;

    function setUp() public {
        permissionSignerPk = 0xA11CE;
        permissionSigner = vm.addr(permissionSignerPk);

        address predictedMintGuard = vm.computeCreateAddress(address(this), vm.getNonce(address(this)) + 1);
        nft = new NFT42("ipfs://base/", predictedMintGuard);
        mintGuard = new MintGuard(nft, PRICE, permissionSigner);

        buyer = makeAddr("buyer");
        owner = makeAddr("owner");
        vm.deal(buyer, 2 ether);
        vm.deal(owner, 1 ether);
    }

    function test_withdraw_after_purchases() public {
        // Make a purchase to add balance to mintGuard contract
        bytes32 digest = keccak256(abi.encodePacked(buyer));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(permissionSignerPk, digest);

        MintGuard.Permission memory perm = MintGuard.Permission({minter: buyer, v: v, r: r, s: s});

        uint256 testContractBalanceBefore = address(this).balance;
        uint256 mintGuardBalanceBefore = address(mintGuard).balance;

        vm.prank(buyer);
        mintGuard.mint{value: PRICE}(perm);

        // Verify mintGuard contract has the payment
        assertEq(address(mintGuard).balance, mintGuardBalanceBefore + PRICE, "MintGuard should have received payment");

        // Owner withdraws (test contract is the owner)
        mintGuard.withdraw();

        // Verify balance transferred to owner
        assertEq(address(this).balance, testContractBalanceBefore + PRICE, "Test contract should receive payment");
        assertEq(address(mintGuard).balance, 0, "MintGuard balance should be zero");
    }

    function test_non_owner_cannot_withdraw() public {
        address nonOwner = makeAddr("nonOwner");

        vm.prank(nonOwner);
        vm.expectRevert(MintGuard.NotOwner.selector);
        mintGuard.withdraw();
    }

    // Allow test contract to receive ETH
    receive() external payable {}
}
