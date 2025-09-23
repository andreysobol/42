// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {NFT42} from "../src/42.sol";
import {MintGuard} from "../src/MintGuard.sol";
import {TransparentUpgradeableProxy} from
    "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract EventsTest is Test {
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
        vm.deal(buyer, 2 ether);
    }

    function test_minted_event_logs_correct_data() public {
        bytes32 digest = keccak256(abi.encodePacked(buyer));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(voucherSignerPk, digest);

        MintGuard.Voucher memory voucher = MintGuard.Voucher({minter: buyer, v: v, r: r, s: s});

        // Expect Minted event with correct buyer and tokenId
        vm.expectEmit(true, true, true, false);
        emit MintGuard.Minted(buyer, buyer, 1);

        vm.prank(buyer);
        mintGuard.mint{value: FEE}(voucher);
    }

    function test_fee_updated_event() public {
        uint256 newFee = 0.02 ether;

        vm.expectEmit(false, false, false, true);
        emit MintGuard.FeeUpdated(FEE, newFee);

        mintGuard.setFee(newFee);
    }

    function test_voucher_signer_updated_event() public {
        address newSigner = makeAddr("newSigner");

        vm.expectEmit(true, true, false, false);
        emit MintGuard.VoucherSignerUpdated(voucherSigner, newSigner);

        mintGuard.setVoucherSigner(newSigner);
    }
}
