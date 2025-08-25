// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {NFT42} from "../src/42.sol";
import {MintGuard} from "../src/MintGuard.sol";

contract BoundarySupplyTest is Test {
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
        vm.deal(buyer, 2000 ether); // Fund for many purchases
    }

    function test_boundary_token_supply() public {
        // Mint up to 1023 tokens (0 to 1023 = 1024 total)
        for (uint32 i = 0; i < 1024; i++) {
            address currentBuyer = address(uint160(uint160(buyer) + i)); // Create unique buyer addresses
            vm.deal(currentBuyer, 2 ether); // Fund each buyer

            bytes32 digest = keccak256(abi.encodePacked(currentBuyer));
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(permissionSignerPk, digest);

            MintGuard.Permission memory perm = MintGuard.Permission({minter: currentBuyer, v: v, r: r, s: s});

            vm.prank(currentBuyer);
            uint256 tokenId = mintGuard.mint{value: PRICE}(perm);
            assertEq(tokenId, i, "Token ID should match iteration");
        }

        // Next buy should fail due to supply cap
        address nextBuyer = address(uint160(uint160(buyer) + 1024));
        vm.deal(nextBuyer, 2 ether);

        bytes32 digest = keccak256(abi.encodePacked(nextBuyer));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(permissionSignerPk, digest);

        MintGuard.Permission memory perm = MintGuard.Permission({minter: nextBuyer, v: v, r: r, s: s});

        vm.prank(nextBuyer);
        vm.expectRevert("Maximum tokens (1024) already minted");
        mintGuard.mint{value: PRICE}(perm);
    }
}
