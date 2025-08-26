// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {NFT42} from "../src/42.sol";
import {MintGuard} from "../src/MintGuard.sol";
import {TransparentUpgradeableProxy} from
    "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract MintAddressMappingTest is Test {
    NFT42 private nft;
    MintGuard private mintGuard;

    address private voucherSigner;
    uint256 private voucherSignerPk;

    address private buyer1;
    address private buyer2;
    address private buyer3;

    uint256 private constant FEE = 0.01 ether;

    function setUp() public {
        voucherSignerPk = 0xA11CE;
        voucherSigner = vm.addr(voucherSignerPk);

        address predictedMintGuard = vm.computeCreateAddress(address(this), vm.getNonce(address(this)) + 2);
        nft = new NFT42("ipfs://base/", predictedMintGuard, 1024);
        mintGuard = MintGuard(payable(new TransparentUpgradeableProxy(
            address(new MintGuard()),
            address(this),
            abi.encodeWithSelector(MintGuard.initialize.selector, nft, FEE, voucherSigner, address(this))
        )));

        buyer1 = makeAddr("buyer1");
        buyer2 = makeAddr("buyer2");
        buyer3 = makeAddr("buyer3");
        vm.deal(buyer1, 2 ether);
        vm.deal(buyer2, 2 ether);
        vm.deal(buyer3, 2 ether);
    }

    function test_mint_address_mapping_visibility() public {
        // Check that address is not minted before purchase
        assertFalse(mintGuard.mint_address(buyer1), "Address should not be minted before purchase");

        bytes32 digest = keccak256(abi.encodePacked(buyer1));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(voucherSignerPk, digest);

        MintGuard.Voucher memory voucher = MintGuard.Voucher({minter: buyer1, v: v, r: r, s: s});

        vm.prank(buyer1);
        mintGuard.mint{value: FEE}(voucher);

        // Check that address is minted after purchase
        assertTrue(mintGuard.mint_address(buyer1), "Address should be minted after purchase");
    }

    function test_multiple_addresses_mint_mapping() public {
        // Check all addresses are not minted initially
        assertFalse(mintGuard.mint_address(buyer1), "Buyer1 should not be minted initially");
        assertFalse(mintGuard.mint_address(buyer2), "Buyer2 should not be minted initially");
        assertFalse(mintGuard.mint_address(buyer3), "Buyer3 should not be minted initially");

        // Purchase with buyer1
        bytes32 digest = keccak256(abi.encodePacked(buyer1));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(voucherSignerPk, digest);

        MintGuard.Voucher memory voucher;
        voucher = MintGuard.Voucher({minter: buyer1, v: v, r: r, s: s});

        vm.prank(buyer1);
        mintGuard.mint{value: FEE}(voucher);

        // Check only buyer1 is minted
        assertTrue(mintGuard.mint_address(buyer1), "Buyer1 should be minted after purchase");
        assertFalse(mintGuard.mint_address(buyer2), "Buyer2 should still not be minted");
        assertFalse(mintGuard.mint_address(buyer3), "Buyer3 should still not be minted");

        // Purchase with buyer2
        digest = keccak256(abi.encodePacked(buyer2));
        (v, r, s) = vm.sign(voucherSignerPk, digest);

        voucher = MintGuard.Voucher({minter: buyer2, v: v, r: r, s: s});

        vm.prank(buyer2);
        mintGuard.mint{value: FEE}(voucher);

        // Check buyer1 and buyer2 are minted, buyer3 is not
        assertTrue(mintGuard.mint_address(buyer1), "Buyer1 should still be minted");
        assertTrue(mintGuard.mint_address(buyer2), "Buyer2 should be minted after purchase");
        assertFalse(mintGuard.mint_address(buyer3), "Buyer3 should still not be minted");
    }
}
