// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {NFT42} from "../src/42.sol";
import {MintGuard} from "../src/MintGuard.sol";

contract OnlyMintGuardMintTest is Test {
    NFT42 private nft;
    MintGuard private sale;

    address private permissionSigner;
    uint256 private permissionSignerPk;

    address private buyer;
    address private nonMintGuardAddress;

    uint256 private constant PRICE = 0.01 ether;

    function setUp() public {
        permissionSignerPk = 0xA11CE;
        permissionSigner = vm.addr(permissionSignerPk);

        address predictedSale = vm.computeCreateAddress(address(this), vm.getNonce(address(this)) + 1);
        nft = new NFT42("ipfs://base/", predictedSale);
        sale = new MintGuard(nft, PRICE, permissionSigner);

        buyer = makeAddr("buyer");
        nonMintGuardAddress = makeAddr("nonMintGuardAddress");
        vm.deal(buyer, 1 ether);
    }

    function test_only_mint_guard_can_mint() public {
        // Try to mint directly from non-mintGuard address
        vm.prank(nonMintGuardAddress);
        vm.expectRevert("Not mintGuard");
        nft.mint(buyer);
    }

    function test_mint_guard_can_mint() public {
        // Sale (mintGuard) should be able to mint
        vm.prank(address(sale));
        uint256 tokenId = nft.mint(buyer);
        assertEq(nft.ownerOf(tokenId), buyer, "Owner should be buyer");
    }
}
