# Strike Finance Perpetuals Smart Contract

## What are Perpetuals

Perpetual futures are a type of derivative contract that allows traders to speculate on the continuous price movement of an underlying asset without an expiration date, enabling positions to be held indefinitely. These contracts typically offer leverage, meaning traders can control larger positions with a relatively small amount of capital by essentially borrowing, which amplifies both potential gains and losses. To manage the increased risk associated with leveraged trading, perpetual futures require maintenance margins—minimum account balances that must be maintained to keep positions open.

There are two positions that a trader can take: a long and a short. Traders will open a long position when they think the underlying asset will go up in value and a short position when they think it will go down in value. To open a position, the trader will need to deposit USDM as collateral for opening short positions and the underlying asset for opening long positions. When they close their position, they will be able to keep all the profits plus the collateral back. Any losses that occurred will be deducted from their collateral.

## Product Requirements

### Trading

1. Traders can open a long or short positions perpetual contract with leverage on an asset. When the asset goes up in value, the long side takes a profit. Whent the asset goes down in value, the short side takes a profit.
2. Leverage is borrowing money from our liquidity pool to hold a larger position.
3. Collateral is required when using leverage. Collateral will be used to cover up any losses incurred during trading. If the collateral reaches 2.5% of it's original value, the position gets liquidated
4. Long positions need to put the underlying asset as collateral and short positions need to put a stable coin as collateral
5. STRIKE token holders will be able to use higher leverage than non STRIKE token holders by using STRIKE as additional collateral. STRIKE can not be used as the sole collateral, only additional collateral. Main collateral will either be the underlying asset or stablecoin. STRIKE will be burnt if liquidated
6. Traders can set a stop loss or take profit, and we will automically closes their position when the asset reaches that price.
7. When using leverage, traders will need to pay an hourly borrow rate.
8. All profits are given out in the underlying asset + the traders initally put up

### Liquidity Pool Providers

1. Anyone can provide liquidity
2. Liquidity providers will keep 100% of the hourly borrow rate
3. When positions get liquidated they also keep 100% of the collateral
4. They will keep 100% of the on-chain fee.
5. They can withdraw their position anytime they want
6. They only get the fees generated from when they deposited liquidity

## References

1. [Specification](/docs/specs.md)
2. [Formula](/docs/formula.md)
