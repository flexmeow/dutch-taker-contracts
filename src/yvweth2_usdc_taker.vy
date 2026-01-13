# @version 0.4.3

"""
@title yvWETH-2/USDC Dutch Taker
@license MIT
@notice Takes yvWETH-2/USDC dutch auctions profitably
"""

from ethereum.ercs import IERC20
from ethereum.ercs import IERC4626

from interfaces import IWETH
from interfaces import IAuction
from interfaces import ICurveTricryptoPool as ICurvePool

# ============================================================================================
# Constants
# ============================================================================================


# Contracts
AUCTION: public(constant(IAuction)) = IAuction(0x6E988D3A79Cc4daeDFDC7cef2F76160F81C8f945)
CURVE_POOL: public(constant(ICurvePool)) = ICurvePool(0x7F86Bf177Dd4F3494b841a37e810A34dD56c829B)

# Tokens
YVWETH2: public(constant(IERC4626)) = IERC4626(0xAc37729B76db6438CE62042AE1270ee574CA7571)
WETH: public(constant(IERC20)) = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2)
USDC: public(constant(IERC20)) = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48)

# Curve pool indices
_CURVE_USDC_INDEX: constant(uint256) = 0
_CURVE_WETH_INDEX: constant(uint256) = 2

# Parameters
_MIN_PROFIT: constant(uint256) = 10 ** 8  # 0.1 gwei in wei

# Internal constants
_MAX_CALLBACK_DATA_SIZE: constant(uint256) = 10 ** 5


# ============================================================================================
# Constructor
# ============================================================================================


@deploy
def __init__():
    """
    @notice Initialize the contract
    """
    assert extcall WETH.approve(CURVE_POOL.address, max_value(uint256), default_return_value=True)
    assert extcall USDC.approve(CURVE_POOL.address, max_value(uint256), default_return_value=True)
    assert extcall USDC.approve(AUCTION.address, max_value(uint256), default_return_value=True)


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
def take(auction_id: uint256, profit_receiver: address = msg.sender):
    """
    @notice Take an auction, redeem yvWETH-2 for WETH, swap to USDC, pay auction, profit in ETH
    @param auction_id The auction to take
    @param profit_receiver The address that receives the ETH profit
    """
    # Cache ETH balance before
    eth_before: uint256 = self.balance

    # Take all yvWETH-2
    extcall AUCTION.take(auction_id, max_value(uint256), self, b"42069")

    # Calculate profit
    profit: uint256 = self.balance - eth_before

    # Make sure we made enough profit
    assert profit >= _MIN_PROFIT, "!MIN_PROFIT"

    # Send ETH profit to receiver
    send(profit_receiver, profit)


# ============================================================================================
# Callback
# ============================================================================================


@external
def auctionTakeCallback(
    auction_id: uint256,
    sender: address,
    take_amount: uint256,
    needed_amount: uint256,
    data: Bytes[_MAX_CALLBACK_DATA_SIZE],
):
    """
    @notice Callback from auction contract after receiving yvWETH-2
    @dev Only callable by the auction contract
    @param auction_id The auction id
    @param sender The original caller of take
    @param take_amount Amount of yvWETH-2 received
    @param needed_amount Amount of USDC needed to pay
    @param data Encoded data (unused)
    """
    # Make sure caller is the auction contract
    assert msg.sender == AUCTION.address, "!auction"

    # Make sure sender is this contract
    assert sender == self, "!sender"

    # Redeem yvWETH-2 shares for WETH
    weth_received: uint256 = extcall YVWETH2.redeem(take_amount, self, self)

    # WETH --> USDC
    usdc_received: uint256 = extcall CURVE_POOL.exchange(_CURVE_WETH_INDEX, _CURVE_USDC_INDEX, weth_received, 0)

    # Make sure we have profit
    assert usdc_received > needed_amount, "!profit"

    # USDC (profit) --> WETH
    extcall CURVE_POOL.exchange(_CURVE_USDC_INDEX, _CURVE_WETH_INDEX, usdc_received - needed_amount, 0)

    # WETH --> ETH
    extcall IWETH(WETH.address).withdraw(staticcall WETH.balanceOf(self))