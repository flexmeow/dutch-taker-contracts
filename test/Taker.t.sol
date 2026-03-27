// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "../script/Deploy.s.sol";

import "forge-std/Test.sol";

interface IAuction {
    function sell_token() external view returns (address);
    function buy_token() external view returns (address);
    function get_available_amount(uint256 auction_id) external view returns (uint256);
    function get_needed_amount(uint256 auction_id, uint256 amount) external view returns (uint256);
    function is_active(uint256 auction_id) external view returns (bool);
}

contract TestTaker is Deploy, Test {
    address constant USDC = address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IAuction constant AUCTION = IAuction(0x7d066Db446eC745ccC4454730a64446c3e03E659);

    function setUp() public {
        // notify deployment script that this is a test
        isTest = true;

        // // create fork at latest block (needed for DEX aggregator routes)
        // vm.selectFork(vm.createFork(vm.envString("ETH_RPC_URL")));
        uint256 _blockNumber = 24_743_461; // cache state for faster tests
        vm.selectFork(vm.createFork(vm.envString("ETH_RPC_URL"), _blockNumber));

        // deploy and initialize contracts
        run();
    }

    function test_take() public {
        address _collateral = AUCTION.sell_token();
        uint256 _available = AUCTION.get_available_amount(0);

        // Get swap route from DEX aggregator
        (address _router, bytes memory _swapData) = _getSwapRoute(1, _collateral, USDC, _available, address(taker));

        // Check that keeper has no ETH before
        assertEq(address(keeper).balance, 0);

        // Take the auction
        taker.take(address(AUCTION), 0, _collateral, _router, _swapData, 0, keeper);

        // Check that keeper received profit
        assertGt(address(keeper).balance, 0);
    }

    /// @dev Returns (router, calldata) from the Enso API response.
    ///      The shell script outputs abi.encodePacked(to, data) — first 20 bytes are the router address.
    function _getSwapRoute(uint256 chainId, address inputToken, address outputToken, uint256 amount, address sender)
        internal
        returns (address router, bytes memory data)
    {
        string[] memory cmd = new string[](7);
        cmd[0] = "bash";
        cmd[1] = "script/get_enso_route.sh";
        cmd[2] = vm.toString(chainId);
        cmd[3] = vm.toString(inputToken);
        cmd[4] = vm.toString(outputToken);
        cmd[5] = vm.toString(amount);
        cmd[6] = vm.toString(sender);
        bytes memory _raw = vm.ffi(cmd);

        // First 20 bytes = router address, rest = calldata
        assembly {
            router := shr(96, mload(add(_raw, 32)))
            let dataLen := sub(mload(_raw), 20)
            data := mload(0x40)
            mstore(data, dataLen)
            mstore(0x40, add(add(data, 32), dataLen))
        }
        for (uint256 i = 0; i < data.length; i++) {
            data[i] = _raw[i + 20];
        }
    }
}
