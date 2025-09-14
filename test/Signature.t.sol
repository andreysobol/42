// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {NFT42} from "../src/42.sol";
import {MintGuard} from "../src/MintGuard.sol";
import {TransparentUpgradeableProxy} from
    "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract SignatureTest is Test {
    NFT42 private nft;
    MintGuard private mintGuard;

    address private voucherSigner;
    uint256 private voucherSignerPk;

    address private buyer;

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
        mintGuard.start(address(0), 0); // Start minting without admin minting

        buyer = makeAddr("buyer");
        vm.deal(buyer, 1 ether);
    }

    function test_signature_verifyVoucher_and_buy_success() public {
        bytes32 digest = keccak256(abi.encodePacked(buyer));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(voucherSignerPk, digest);

        MintGuard.Voucher memory voucher = MintGuard.Voucher({minter: buyer, v: v, r: r, s: s});

        vm.prank(buyer);
        uint256 tokenId = mintGuard.mint{value: FEE}(voucher);
        assertEq(nft.ownerOf(tokenId), buyer);
        assertTrue(mintGuard.mintAddress(buyer));
    }

    function test_signature_invalidSignature_reverts() public {
        bytes32 digest = keccak256(abi.encodePacked(buyer));
        uint256 wrongPk = 0xB0B;
        (, bytes32 r, bytes32 s) = vm.sign(wrongPk, digest);
        uint8 v = 27;

        MintGuard.Voucher memory voucher = MintGuard.Voucher({minter: buyer, v: v, r: r, s: s});

        vm.prank(buyer);
        vm.expectRevert(MintGuard.InvalidSignature.selector);
        mintGuard.mint{value: FEE}(voucher);
    }
}
