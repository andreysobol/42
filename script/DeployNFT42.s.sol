// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {NFT42} from "../src/42.sol";
import {console} from "forge-std/console.sol";

contract DeployNFT42 is Script {
    string baseMetadataUri = "ipfs://base/";
    uint256 maxTokens = 1024;

    function run() public {
        address mintGuardAddress = vm.envAddress("MINT_GUARD_ADDRESS");
        vm.startBroadcast();
        NFT42 nft = new NFT42{salt: bytes32(0)}(baseMetadataUri, mintGuardAddress, maxTokens);
        console.log("NFT42 deployed at", address(nft));
        vm.stopBroadcast();
    }
}
