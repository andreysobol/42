// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {NFT42} from "../src/42.sol";
import {MintGuard} from "../src/MintGuard.sol";

contract SignatureTest is Test {
    NFT42 private nft;
    MintGuard private mintGuard;

    address private permissionSigner;
    uint256 private permissionSignerPk;

    address private buyer;

    uint256 private constant PRICE = 0.01 ether;

    function setUp() public {
        permissionSignerPk = 0xA11CE;
        permissionSigner = vm.addr(permissionSignerPk);

        address predictedMintGuard = vm.computeCreateAddress(address(this), vm.getNonce(address(this)) + 1);
        nft = new NFT42("ipfs://base/", predictedMintGuard);
        mintGuard = new MintGuard(nft, PRICE, permissionSigner);

        buyer = makeAddr("buyer");
        vm.deal(buyer, 1 ether);
    }

    function test_signature_verifyPermission_and_buy_success() public {
        bytes32 digest = keccak256(abi.encodePacked(buyer));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(permissionSignerPk, digest);

        MintGuard.Permission memory perm = MintGuard.Permission({minter: buyer, v: v, r: r, s: s});

        vm.prank(buyer);
        uint256 tokenId = mintGuard.buy{value: PRICE}(perm);
        assertEq(nft.ownerOf(tokenId), buyer);
        assertTrue(mintGuard.mint_address(buyer));
    }

    function test_signature_invalidSignature_reverts() public {
        bytes32 digest = keccak256(abi.encodePacked(buyer));
        uint256 wrongPk = 0xB0B;
        (, bytes32 r, bytes32 s) = vm.sign(wrongPk, digest);
        uint8 v = 27;

        MintGuard.Permission memory perm = MintGuard.Permission({minter: buyer, v: v, r: r, s: s});

        vm.prank(buyer);
        vm.expectRevert(MintGuard.IncorrectPermission.selector);
        mintGuard.buy{value: PRICE}(perm);
    }
}
