// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {NFT42} from "../src/42.sol";
import {MintGuard} from "../src/MintGuard.sol";

contract UpdateSignerTest is Test {
    NFT42 private nft;
    MintGuard private mintGuard;

    address private permissionSigner;
    uint256 private permissionSignerPk;

    address private newSigner;
    uint256 private newSignerPk;

    address private buyer;

    uint256 private constant FEE = 0.01 ether;

    function setUp() public {
        permissionSignerPk = 0xA11CE;
        permissionSigner = vm.addr(permissionSignerPk);

        newSignerPk = 0xB0B;
        newSigner = vm.addr(newSignerPk);

        address predictedMintGuard = vm.computeCreateAddress(address(this), vm.getNonce(address(this)) + 1);
        nft = new NFT42("ipfs://base/", predictedMintGuard, 1024);
        mintGuard = new MintGuard(nft, FEE, permissionSigner);

        buyer = makeAddr("buyer");
        vm.deal(buyer, 2 ether);
    }

    function test_update_permission_signer() public {
        // Sign with old signer
        bytes32 digest = keccak256(abi.encodePacked(buyer));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(permissionSignerPk, digest);

        MintGuard.Permission memory perm = MintGuard.Permission({minter: buyer, v: v, r: r, s: s});

        // Old signer should work before update
        vm.prank(buyer);
        uint256 tokenId = mintGuard.mint{value: FEE}(perm);
        assertEq(nft.ownerOf(tokenId), buyer, "Old signer should work before update");

        // Update permission signer
        vm.prank(address(this));
        mintGuard.setPermissionSigner(newSigner);

        // Old signer should not work after update
        address buyer2 = address(uint160(uint160(buyer) + 1));
        vm.deal(buyer2, 2 ether);
        digest = keccak256(abi.encodePacked(buyer2));
        (v, r, s) = vm.sign(permissionSignerPk, digest);

        perm = MintGuard.Permission({minter: buyer2, v: v, r: r, s: s});

        vm.prank(buyer2);
        vm.expectRevert(MintGuard.InvalidSignature.selector);
        mintGuard.mint{value: FEE}(perm);

        // New signer should work after update
        address buyer3 = address(uint160(uint160(buyer) + 2));
        vm.deal(buyer3, 2 ether);
        digest = keccak256(abi.encodePacked(buyer3));
        (v, r, s) = vm.sign(newSignerPk, digest);

        perm = MintGuard.Permission({minter: buyer3, v: v, r: r, s: s});

        vm.prank(buyer3);
        tokenId = mintGuard.mint{value: FEE}(perm);
        assertEq(nft.ownerOf(tokenId), buyer3, "New signer should work after update");
    }
}
