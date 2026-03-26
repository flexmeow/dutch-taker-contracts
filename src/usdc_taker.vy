# @version 0.4.3

"""
@title USDC Dutch Taker
@license MIT
@notice Takes dutch auctions profitably using a DEX aggregator for collateral --> USDC and Curve for USDC --> ETH
"""

from ethereum.ercs import IERC20

from interfaces import IWETH
from interfaces import IAuction
from interfaces import ICurveTricryptoPool as ICurvePool

# ============================================================================================
# Constants
# ============================================================================================


# Contracts
CURVE_POOL: public(constant(ICurvePool)) = ICurvePool(0x7F86Bf177Dd4F3494b841a37e810A34dD56c829B)

# Tokens
WETH: public(constant(IERC20)) = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2)
USDC: public(constant(IERC20)) = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48)

# Curve pool indices
_CURVE_USDC_INDEX: constant(uint256) = 0
_CURVE_WETH_INDEX: constant(uint256) = 2

# Internal constants
_MAX_SWAP_DATA_SIZE: constant(uint256) = 5 * 10 ** 4
_MAX_CALLBACK_DATA_SIZE: constant(uint256) = 10 ** 5


# ============================================================================================
# Constructor
# ============================================================================================


@deploy
def __init__():
    """
    @notice Initialize the contract
    """
    assert extcall USDC.approve(CURVE_POOL.address, max_value(uint256), default_return_value=True)


# ============================================================================================
# Fallback
# ============================================================================================


@external
@payable
def __default__():
    """
    @notice Fallback function to receive ETH from WETH contract
    """
    pass


# ============================================================================================
# Take
# ============================================================================================


@external
def take(
    auction: address,
    auction_id: uint256,
    collateral: address,
    router: address,
    swap_data: Bytes[_MAX_SWAP_DATA_SIZE],
    min_profit: uint256,
    profit_receiver: address = msg.sender,
):
    """
    @notice Take an auction, swap collateral to USDC via DEX aggregator, pay auction, profit in ETH
    @param auction The auction contract address
    @param auction_id The auction to take
    @param collateral The collateral token received from the auction
    @param router The swap router address
    @param swap_data The swap calldata (collateral --> USDC)
    @param min_profit Minimum ETH profit required (in wei)
    @param profit_receiver The address that receives the ETH profit
    """
    # Cache ETH balance before
    eth_before: uint256 = self.balance

    # Approve USDC to auction
    assert extcall USDC.approve(auction, max_value(uint256), default_return_value=True)

    # Encode swap params into callback data
    callback_data: Bytes[_MAX_CALLBACK_DATA_SIZE] = abi_encode(collateral, router, swap_data)

    # Take all collateral
    extcall IAuction(auction).take(auction_id, max_value(uint256), self, callback_data)

    # Calculate profit
    profit: uint256 = self.balance - eth_before

    # Make sure we made enough profit
    assert profit >= min_profit, "!MIN_PROFIT"

    # Send ETH profit to receiver
    send(profit_receiver, profit)


# ============================================================================================
# Callback
# ============================================================================================


@external
def takeCallback(
    auction_id: uint256,
    taker: address,
    amount_taken: uint256,
    needed_amount: uint256,
    data: Bytes[_MAX_CALLBACK_DATA_SIZE],
):
    """
    @notice Callback from auction contract after receiving collateral
    @param auction_id The auction id
    @param taker The original caller of take
    @param amount_taken Amount of collateral received
    @param needed_amount Amount of USDC needed to pay
    @param data Encoded swap params (collateral, router, swap_data)
    """
    # Make sure taker is this contract
    assert taker == self, "!taker"

    # Decode swap params
    collateral: address = empty(address)
    router: address = empty(address)
    swap_data: Bytes[_MAX_SWAP_DATA_SIZE] = empty(Bytes[_MAX_SWAP_DATA_SIZE])
    collateral, router, swap_data = abi_decode(
        data, (address, address, Bytes[_MAX_SWAP_DATA_SIZE])
    )

    # Approve collateral to router
    assert extcall IERC20(collateral).approve(router, amount_taken, default_return_value=True)

    # Collateral --> USDC via DEX aggregator
    raw_call(router, swap_data)

    # Check USDC balance
    usdc_balance: uint256 = staticcall USDC.balanceOf(self)

    # Make sure we have profit
    assert usdc_balance > needed_amount, "!profit"

    # USDC (profit) --> WETH via Curve
    extcall CURVE_POOL.exchange(
        _CURVE_USDC_INDEX, _CURVE_WETH_INDEX, usdc_balance - needed_amount, 0
    )

    # WETH --> ETH
    extcall IWETH(WETH.address).withdraw(staticcall WETH.balanceOf(self))
