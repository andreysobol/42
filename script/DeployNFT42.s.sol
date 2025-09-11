// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {NFT42} from "../src/42.sol";
import {console} from "forge-std/console.sol";

contract DeployNFT42 is Script {
    function run() public {
        string memory baseMetadataUri = vm.envString("BASE_METADATA_URI");
        uint256 maxTokens = vm.envUint("MAX_TOKENS");
        address mintGuardAddress = vm.envAddress("MINT_GUARD_ADDRESS");
        vm.startBroadcast();
        NFT42 nft = new NFT42{salt: bytes32(0)}(baseMetadataUri, mintGuardAddress, maxTokens);
        console.log("NFT42 deployed at", address(nft));
        vm.stopBroadcast();
    }
}
