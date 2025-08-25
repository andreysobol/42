// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {NFT42} from "../src/42.sol";
import {MintGuard} from "../src/MintGuard.sol";

contract PriceMismatchTest is Test {
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

    function test_price_mismatch_send_less() public {
        bytes32 digest = keccak256(abi.encodePacked(buyer));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(permissionSignerPk, digest);

        MintGuard.Permission memory perm = MintGuard.Permission({minter: buyer, v: v, r: r, s: s});

        vm.prank(buyer);
        vm.expectRevert(abi.encodeWithSelector(MintGuard.IncorrectPayment.selector, PRICE, PRICE - 0.001 ether));
        mintGuard.mint{value: PRICE - 0.001 ether}(perm);
    }

    function test_price_mismatch_send_more() public {
        bytes32 digest = keccak256(abi.encodePacked(buyer));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(permissionSignerPk, digest);

        MintGuard.Permission memory perm = MintGuard.Permission({minter: buyer, v: v, r: r, s: s});

        vm.prank(buyer);
        vm.expectRevert(abi.encodeWithSelector(MintGuard.IncorrectPayment.selector, PRICE, PRICE + 0.001 ether));
        mintGuard.mint{value: PRICE + 0.001 ether}(perm);
    }
}
