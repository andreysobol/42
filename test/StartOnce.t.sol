// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {NFT42} from "../src/42.sol";
import {MintGuard} from "../src/MintGuard.sol";
import {TransparentUpgradeableProxy} from
    "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract StartOnceTest is Test {
    NFT42 private nft;
    MintGuard private mintGuard;

    address private voucherSigner;
    uint256 private voucherSignerPk;

    address private buyer;
    address private adminReceiver;

    uint256 private constant FEE = 0.01 ether;

    function setUp() public {
        voucherSignerPk = 0xA11CE;
        voucherSigner = vm.addr(voucherSignerPk);

        address predictedMintGuard = vm.computeCreateAddress(address(this), vm.getNonce(address(this)) + 2);
        nft = new NFT42("ipfs://base/", predictedMintGuard, 1024);
        mintGuard = MintGuard(
            payable(
                new TransparentUpgradeableProxy(
                    address(new MintGuard()),
                    address(this),
                    abi.encodeWithSelector(MintGuard.initialize.selector, FEE, voucherSigner, address(this))
                )
            )
        );
        mintGuard.setNft(nft);

        buyer = makeAddr("buyer");
        adminReceiver = makeAddr("adminReceiver");
        vm.deal(buyer, 1 ether);
    }

    function test_start_function_can_only_be_called_once() public {
        // First call to start should succeed and mint NFTs to adminReceiver
        uint256 initialSupply = nft.totalSupply();
        assertEq(initialSupply, 0, "Initial supply should be 0");

        // Expect MintStarted event
        vm.expectEmit(false, false, false, true);
        emit MintGuard.MintStarted();

        // Expect Minted events for admin minting
        vm.expectEmit(true, true, false, false);
        emit MintGuard.Minted(adminReceiver, 1);
        vm.expectEmit(true, true, false, false);
        emit MintGuard.Minted(adminReceiver, 2);

        // First call to start should succeed
        mintGuard.start(adminReceiver, 2);

        // Verify minting was successful
        assertEq(nft.totalSupply(), 2, "Total supply should be 2 after admin minting");
        assertEq(nft.balanceOf(adminReceiver), 2, "Admin receiver should have 2 NFTs");
        assertTrue(mintGuard.mintStarted(), "Mint should be started");

        // Second call to start should fail
        vm.expectRevert(MintGuard.MintingAlreadyStarted.selector);
        mintGuard.start(adminReceiver, 1);

        // Verify no additional NFTs were minted
        assertEq(nft.totalSupply(), 2, "Total supply should still be 2");
        assertEq(nft.balanceOf(adminReceiver), 2, "Admin receiver should still have 2 NFTs");
    }

    function test_start_function_can_only_be_called_once_without_admin_minting() public {
        // First call to start should succeed without admin minting
        uint256 initialSupply = nft.totalSupply();
        assertEq(initialSupply, 0, "Initial supply should be 0");

        // Expect MintStarted event
        vm.expectEmit(false, false, false, true);
        emit MintGuard.MintStarted();

        // First call to start should succeed (no admin minting)
        mintGuard.start(address(0), 0);

        // Verify minting is started but no NFTs were minted
        assertEq(nft.totalSupply(), 0, "Total supply should still be 0");
        assertTrue(mintGuard.mintStarted(), "Mint should be started");

        // Second call to start should fail
        vm.expectRevert(MintGuard.MintingAlreadyStarted.selector);
        mintGuard.start(address(0), 0);

        // Verify no NFTs were minted
        assertEq(nft.totalSupply(), 0, "Total supply should still be 0");
    }

    function test_public_minting_works_after_start() public {
        // Start minting first
        mintGuard.start(address(0), 0);

        // Now public minting should work
        bytes32 digest = keccak256(abi.encodePacked(buyer));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(voucherSignerPk, digest);

        MintGuard.Voucher memory voucher = MintGuard.Voucher({minter: buyer, v: v, r: r, s: s});

        uint256 initialSupply = nft.totalSupply();
        assertEq(initialSupply, 0, "Initial supply should be 0");

        // Expect Minted event
        vm.expectEmit(true, true, false, false);
        emit MintGuard.Minted(buyer, 1);

        vm.prank(buyer);
        uint256 tokenId = mintGuard.mint{value: FEE}(voucher);

        // Verify public minting was successful
        assertEq(nft.totalSupply(), 1, "Total supply should be 1 after public minting");
        assertEq(nft.ownerOf(tokenId), buyer, "Owner should be buyer");
        assertEq(nft.balanceOf(buyer), 1, "Buyer should have 1 NFT");
    }
}
