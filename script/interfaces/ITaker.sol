// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

interface ITaker {
    function take(uint256 auction_id, address profit_receiver) external;
}