// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {ITaker} from "./interfaces/ITaker.sol";

import "forge-std/Script.sol";

// ---- Usage ----

// deploy:
// forge script script/Deploy.s.sol:Deploy --verify --slow -g 250 --etherscan-api-key $KEY --rpc-url $RPC_URL --broadcast

// verify:
// vyper -f solc_json src/usdc_taker.vy > out/build-info/verify.json
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
            require(deployer == address(0x000005281a2b04A182085D37cC9E6dD552795caa), "!johnny.flexmeow.eth");
            console.log("Deployer address: %s", deployer);
        }

        vm.startBroadcast(_pk);

        taker = ITaker(deployCode("usdc_taker"));

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
