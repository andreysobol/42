// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {MintGuard} from "../src/MintGuard.sol";
import {NFT42} from "../src/42.sol";
import {TransparentUpgradeableProxy} from
    "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {console} from "forge-std/console.sol";

contract DeployMintGuard is Script {
    uint256 fee = vm.envUint("FEE");
    address voucherSigner = vm.envAddress("VOUCHER_SIGNER");
    address proxyOwner = vm.envAddress("PROXY_OWNER");
    address mintGuardOwner = vm.envAddress("MINT_GUARD_OWNER");

    function run() public {
        vm.startBroadcast();
        MintGuard mintGuard = new MintGuard{salt: bytes32(0)}();
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy{salt: bytes32(0)}(
            address(mintGuard), proxyOwner, abi.encodeCall(MintGuard.initialize, (fee, voucherSigner, mintGuardOwner))
        );
        console.log("MintGuard deployed at", address(proxy));
        vm.stopBroadcast();
    }
}
