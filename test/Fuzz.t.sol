// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {NFT42} from "../src/42.sol";
import {MintGuard} from "../src/MintGuard.sol";

contract FuzzTest is Test {
    NFT42 private nft;
    MintGuard private mintGuard;

    address private voucherSigner;
    uint256 private voucherSignerPk;

    address private buyer;

    uint256 private constant FEE = 0.01 ether;

    function setUp() public {
        voucherSignerPk = 0xA11CE;
        voucherSigner = vm.addr(voucherSignerPk);

        address predictedMintGuard = vm.computeCreateAddress(address(this), vm.getNonce(address(this)) + 1);
        nft = new NFT42("ipfs://base/", predictedMintGuard, 1024);
        mintGuard = new MintGuard(nft, FEE, voucherSigner);

        buyer = makeAddr("buyer");
        vm.deal(buyer, 1000 ether); // Fund for many purchases
    }

    function testFuzz_random_addresses_uniqueness(address minter) public {
        // Skip if minter is zero address
        vm.assume(minter != address(0));
        vm.assume(minter.code.length == 0); // Skip contract addresses

        bytes32 digest = keccak256(abi.encodePacked(minter));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(voucherSignerPk, digest);

        MintGuard.Voucher memory voucher = MintGuard.Voucher({minter: minter, v: v, r: r, s: s});

        // Fund the minter
        vm.deal(minter, FEE);

        // First purchase should succeed
        vm.prank(minter);
        uint256 tokenId = mintGuard.mint{value: FEE}(voucher);
        assertEq(nft.ownerOf(tokenId), minter, "Owner should be minter");
        assertTrue(mintGuard.mint_address(minter), "Address should be marked as minted");

        // Second purchase with same address should fail
        vm.deal(minter, FEE);
        vm.prank(minter);
        vm.expectRevert(MintGuard.AlreadyMinted.selector);
        mintGuard.mint{value: FEE}(voucher);
    }

    function testFuzz_multiple_random_addresses(address[5] memory minters) public {
        for (uint256 i = 0; i < minters.length; i++) {
            address minter = minters[i];
            vm.assume(minter != address(0)); // Skip zero addresses
            vm.assume(minter.code.length == 0); // Skip contract addresses

            // Skip if address was already used in this test
            if (mintGuard.mint_address(minter)) continue;

            bytes32 digest = keccak256(abi.encodePacked(minter));
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(voucherSignerPk, digest);

            MintGuard.Voucher memory voucher = MintGuard.Voucher({minter: minter, v: v, r: r, s: s});

            // Fund the minter
            vm.deal(minter, FEE);

            // Purchase should succeed for unique addresses
            vm.prank(minter);
            uint256 tokenId = mintGuard.mint{value: FEE}(voucher);
            assertEq(nft.ownerOf(tokenId), minter, "Owner should be minter");
            assertTrue(mintGuard.mint_address(minter), "Address should be marked as minted");
        }
    }

    function testFuzz_random_minter(address minter) public {
        vm.assume(minter != address(0));
        vm.assume(minter.code.length == 0); // Skip contract addresses

        bytes32 digest = keccak256(abi.encodePacked(minter));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(voucherSignerPk, digest);

        MintGuard.Voucher memory voucher = MintGuard.Voucher({minter: minter, v: v, r: r, s: s});

        vm.deal(minter, FEE);
        vm.prank(minter);
        uint256 tokenId = mintGuard.mint{value: FEE}(voucher);
        assertEq(nft.ownerOf(tokenId), minter, "Owner should be minter");
        assertTrue(mintGuard.mint_address(minter), "Address should be marked as minted");
    }
}
