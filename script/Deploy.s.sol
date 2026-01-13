// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {ITaker} from "./interfaces/ITaker.sol";

import "forge-std/Script.sol";

// ---- Usage ----

// deploy:
// forge script script/Deploy.s.sol:Deploy --verify --slow --etherscan-api-key $KEY --rpc-url $RPC_URL --broadcast

// verify:
// vyper -f solc_json src/price_feed.vy > out/build-info/verify.json
// vyper -f solc_json --path src/periphery --path src src/leverage_zapper.vy > out/build-info/verify.json

// constructor args:
// cast abi-encode "constructor(address)" 0xbACBBefda6fD1FbF5a2d6A79916F4B6124eD2D49

contract Deploy is Script {

    bool public isTest;
    address public deployer;

    address public keeper = address(420_69);

    ITaker public taker;

    function run() public {
        uint256 _pk = isTest ? 555 : vm.envUint("DEPLOYER_PRIVATE_KEY");

        // Derive deployer address from private key
        deployer = vm.addr(_pk);

        if (!isTest) {
            require(deployer == address(0x285E3b1E82f74A99D07D2aD25e159E75382bB43B), "!johnnyonline.eth");
            console.log("Deployer address: %s", deployer);
        }

        vm.startBroadcast(_pk);

        taker = ITaker(deployCode("yvweth2_usdc_taker"));

        if (isTest) {
            vm.label({account: address(taker), newLabel: "Taker"});
        } else {
            console.log("---------------------------------");
            console.log("Taker: ", address(taker));
            console.log("---------------------------------");
        }

        vm.stopBroadcast();
    }
}
