// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {NFT42} from "../src/42.sol";
import {MintGuard} from "../src/MintGuard.sol";
import {TransparentUpgradeableProxy} from
    "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract BoundarySupplyTest is Test {
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
                    abi.encodeWithSelector(MintGuard.initialize.selector, nft, FEE, voucherSigner, address(this))
                )
            )
        );

        buyer = makeAddr("buyer");
        vm.deal(buyer, 2000 ether); // Fund for many purchases
    }

    function test_boundary_token_supply() public {
        // Mint up to 1023 tokens (0 to 1023 = 1024 total)
        for (uint32 i = 0; i < 1024; i++) {
            address currentBuyer = address(uint160(uint160(buyer) + i)); // Create unique buyer addresses
            vm.deal(currentBuyer, 2 ether); // Fund each buyer

            bytes32 digest = keccak256(abi.encodePacked(currentBuyer));
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(voucherSignerPk, digest);

            MintGuard.Voucher memory voucher = MintGuard.Voucher({minter: currentBuyer, v: v, r: r, s: s});

            vm.prank(currentBuyer);
            uint256 tokenId = mintGuard.mint{value: FEE}(voucher);
            assertEq(tokenId, i + 1, "Token ID should match iteration");
        }

        // Next buy should fail due to supply cap
        address nextBuyer = address(uint160(uint160(buyer) + 1024));
        vm.deal(nextBuyer, 2 ether);

        bytes32 nextDigest = keccak256(abi.encodePacked(nextBuyer));
        (uint8 nextV, bytes32 nextR, bytes32 nextS) = vm.sign(voucherSignerPk, nextDigest);

        MintGuard.Voucher memory nextVoucher = MintGuard.Voucher({minter: nextBuyer, v: nextV, r: nextR, s: nextS});

        vm.prank(nextBuyer);
        vm.expectRevert("Maximum tokens already minted");
        mintGuard.mint{value: FEE}(nextVoucher);
    }
}
