// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {NFT42} from "../src/42.sol";
import {MintGuard} from "../src/MintGuard.sol";

contract EventsTest is Test {
    NFT42 private nft;
    MintGuard private mintGuard;

    address private permissionSigner;
    uint256 private permissionSignerPk;

    address private buyer;

    uint256 private constant FEE = 0.01 ether;

    function setUp() public {
        permissionSignerPk = 0xA11CE;
        permissionSigner = vm.addr(permissionSignerPk);

        address predictedMintGuard = vm.computeCreateAddress(address(this), vm.getNonce(address(this)) + 1);
        nft = new NFT42("ipfs://base/", predictedMintGuard, 1024);
        mintGuard = new MintGuard(nft, FEE, permissionSigner);

        buyer = makeAddr("buyer");
        vm.deal(buyer, 2 ether);
    }

    function test_minted_event_logs_correct_data() public {
        bytes32 digest = keccak256(abi.encodePacked(buyer));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(permissionSignerPk, digest);

        MintGuard.Permission memory perm = MintGuard.Permission({minter: buyer, v: v, r: r, s: s});

        // Expect Minted event with correct buyer, tokenId, and price
        vm.expectEmit(true, true, false, true);
        emit MintGuard.Minted(buyer, 1, FEE);

        vm.prank(buyer);
        mintGuard.mint{value: FEE}(perm);
    }

    function test_fee_updated_event() public {
        uint256 newFee = 0.02 ether;

        vm.expectEmit(false, false, false, true);
        emit MintGuard.FeeUpdated(FEE, newFee);

        mintGuard.setFee(newFee);
    }

    function test_permission_signer_updated_event() public {
        address newSigner = makeAddr("newSigner");

        vm.expectEmit(true, true, false, false);
        emit MintGuard.PermissionSignerUpdated(permissionSigner, newSigner);

        mintGuard.setPermissionSigner(newSigner);
    }
}
