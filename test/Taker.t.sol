// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "../script/Deploy.s.sol";

import "forge-std/Test.sol";

contract TestTaker is Deploy, Test {

    function setUp() public {
        // notify deplyment script that this is a test
        isTest = true;

        // create fork
        uint256 _blockNumber = 24_227_113; // cache state for faster tests
        vm.selectFork(vm.createFork(vm.envString("ETH_RPC_URL"), _blockNumber));

        // deploy and initialize contracts
        run();
    }

    function test_sanity() public {
        // ID of the auction to take
        uint256 _auctionId = 0;

        // Auction still not profitable
        vm.expectRevert("!profit");
        taker.take(_auctionId, keeper);

        // Skip enough time to make auction profitable
        skip(2.1 hours);

        // Check that keeper receives profit
        assertEq(address(keeper).balance, 0);

        // Take the auction
        taker.take(_auctionId, keeper);

        // Check that keeper received profit
        assertGt(address(keeper).balance, 0);
    }
}