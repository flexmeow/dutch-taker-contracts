// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

interface ITaker {
    function take(
        address auction,
        uint256 auction_id,
        address collateral,
        address router,
        bytes calldata swap_data,
        uint256 min_profit,
        address profit_receiver
    ) external;
}
