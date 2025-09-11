// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {NFT42} from "../src/42.sol";
import {MintGuard} from "../src/MintGuard.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {TransparentUpgradeableProxy} from
    "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract WithdrawTest is Test {
    NFT42 private nft;
    MintGuard private mintGuard;

    address private voucherSigner;
    uint256 private voucherSignerPk;

    address private buyer;
    address private owner;

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
        owner = makeAddr("owner");
        vm.deal(buyer, 2 ether);
        vm.deal(owner, 1 ether);
    }

    function test_withdraw_after_purchases() public {
        // Make a purchase to add balance to mintGuard contract
        bytes32 digest = keccak256(abi.encodePacked(buyer));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(voucherSignerPk, digest);

        MintGuard.Voucher memory voucher = MintGuard.Voucher({minter: buyer, v: v, r: r, s: s});

        uint256 testContractBalanceBefore = address(this).balance;
        uint256 mintGuardBalanceBefore = address(mintGuard).balance;

        vm.prank(buyer);
        mintGuard.mint{value: FEE}(voucher);

        // Verify mintGuard contract has the payment
        assertEq(address(mintGuard).balance, mintGuardBalanceBefore + FEE, "MintGuard should have received payment");

        // Owner withdraws (test contract is the owner)
        mintGuard.withdraw();

        // Verify balance transferred to owner
        assertEq(address(this).balance, testContractBalanceBefore + FEE, "Test contract should receive payment");
        assertEq(address(mintGuard).balance, 0, "MintGuard balance should be zero");
    }

    function test_non_owner_cannot_withdraw() public {
        address nonOwner = makeAddr("nonOwner");

        vm.prank(nonOwner);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, nonOwner));
        mintGuard.withdraw();
    }

    // Allow test contract to receive ETH
    receive() external payable {}
}
