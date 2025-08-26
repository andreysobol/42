// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {NFT42} from "../src/42.sol";
import {MintGuard} from "../src/MintGuard.sol";

contract OnlyMintGuardMintTest is Test {
    NFT42 private nft;
    MintGuard private mintGuard;

    address private voucherSigner;
    uint256 private voucherSignerPk;

    address private buyer;
    address private nonMintGuardAddress;

    uint256 private constant FEE = 0.01 ether;

    function setUp() public {
        voucherSignerPk = 0xA11CE;
        voucherSigner = vm.addr(voucherSignerPk);

        address predictedMintGuard = vm.computeCreateAddress(address(this), vm.getNonce(address(this)) + 1);
        nft = new NFT42("ipfs://base/", predictedMintGuard, 1024);
        mintGuard = new MintGuard(nft, FEE, voucherSigner);

        buyer = makeAddr("buyer");
        nonMintGuardAddress = makeAddr("nonMintGuardAddress");
        vm.deal(buyer, 2 ether);
    }

    function test_only_mint_guard_can_mint() public {
        // Try to mint directly from non-mintGuard address
        vm.prank(nonMintGuardAddress);
        vm.expectRevert(NFT42.NotMintGuard.selector);
        nft.mint(buyer);
    }

    function test_mint_guard_can_mint() public {
        // MintGuard should be able to mint
        vm.prank(address(mintGuard));
        uint256 tokenId = nft.mint(buyer);
        assertEq(nft.ownerOf(tokenId), buyer, "Owner should be buyer");
    }
}
