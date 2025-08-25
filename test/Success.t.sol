// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {NFT42} from "../src/42.sol";
import {MintGuard} from "../src/MintGuard.sol";

contract SuccessTest is Test {
    NFT42 private nft;
    MintGuard private mintGuard;

    address private permissionSigner;
    uint256 private permissionSignerPk;

    address private buyer;
    address private receiver;

    uint256 private constant FEE = 0.01 ether;

    function setUp() public {
        permissionSignerPk = 0xA11CE;
        permissionSigner = vm.addr(permissionSignerPk);

        address predictedMintGuard = vm.computeCreateAddress(address(this), vm.getNonce(address(this)) + 1);
        nft = new NFT42("ipfs://base/", predictedMintGuard, 1024);
        mintGuard = new MintGuard(nft, FEE, permissionSigner);

        buyer = makeAddr("buyer");
        receiver = makeAddr("receiver");
        vm.deal(buyer, 1 ether);
    }

    function test_successful_buy_and_transfer() public {
        bytes32 digest = keccak256(abi.encodePacked(buyer));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(permissionSignerPk, digest);

        MintGuard.Permission memory perm = MintGuard.Permission({minter: buyer, v: v, r: r, s: s});

        assertEq(nft.totalSupply(), 0, "total supply should be 0 before minting");

        // Expect Minted event; check buyer (topic1) and data (fee), ignore tokenId
        vm.expectEmit(true, false, false, true);
        emit MintGuard.Minted(buyer, 1, FEE);

        vm.prank(buyer);
        uint256 tokenId = mintGuard.mint{value: FEE}(perm);

        assertEq(nft.totalSupply(), 1, "total supply should be 1 after minting");
        assertEq(nft.ownerOf(tokenId), buyer, "owner should be buyer");

        vm.prank(buyer);
        nft.safeTransferFrom(buyer, receiver, tokenId);
        assertEq(nft.ownerOf(tokenId), receiver, "owner should be receiver after transfer");
        assertEq(nft.balanceOf(buyer), 0, "buyer should no longer own any NFT");
        assertEq(nft.balanceOf(receiver), 1, "receiver should own 1 NFT");
        assertEq(nft.totalSupply(), 1, "total supply should still be 1");
    }
}
