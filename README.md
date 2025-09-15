# Strike Finance Perpetuals Smart Contract

## Structure

- Main contracts:
  - [Liquidity Validators](/validators/liquidity_mint.ak)
  - [Orders Validator](/validators/orders.ak)
  - [Positions Validator](/validators/pool.ak)
  - [Pool Validator](/validators/position_mint.ak)

### Prerequisites

- Install [npm](https://docs.npmjs.com/downloading-and-installing-node-js-and-npm)
- Install [Aiken](https://aiken-lang.org/installation-instructions)

#### Installing Aiken

1. Install aikup (Aiken version manager):
   ```bash
   brew install aiken-lang/tap/aikup
   ```

2. Use aikup to install Aiken:
   ```bash
   aikup install
   ```

3. Add Aiken to your PATH by adding this line to your shell configuration file (`~/.zshrc` for zsh or `~/.bashrc` for bash):
   ```bash
   export PATH="$HOME/.aiken/bin:$PATH"
   ```

4. Reload your shell configuration:
   ```bash
   source ~/.zshrc  # for zsh
   # or
   source ~/.bashrc  # for bash
   ```

5. Verify the installation:
   ```bash
   aiken --version
   ```


## Testing
- Run `aiken check` to run all unit tests of the contract

## What are Perpetuals

Perpetual futures are a type of derivative contract that allows traders to speculate on the continuous price movement of an underlying asset without an expiration date, enabling positions to be held indefinitely. These contracts typically offer leverage, meaning traders can control larger positions with a relatively small amount of capital by essentially borrowing, which amplifies both potential gains and losses. To manage the increased risk associated with leveraged trading, perpetual futures require maintenance margins—minimum account balances that must be maintained to keep positions open.

There are two positions that a trader can take: a long and a short. Traders will open a long position when they think the underlying asset will go up in value and a short position when they think it will go down in value. When they close their position, they will be able to keep all the profits plus the collateral back. Any losses that occurred will be deducted from their collateral.

## Perpetuals on Strike

Opening a position does not involve buying or selling of the underlying asset. Instead, our Liquidity Providers (LPs) serve as the counterparty to every trader's position; when a trader profits, the funds are paid from the liquidity pool, and when they incur losses, those funds are absorbed back into the pool. There are also no funding rate mechanism common in perpetual futures. Traders compensate LPs for enabling these synthetic positions by paying a hourly borrow rate. 100% of liquidated funds goes back to lps. Over a long period horizon liquidity providers will earn a profit over the traders due to things like opening fee, closing fee, liquidations, and borrow fees.

## Product Requirements

### Trading

1. Traders can open a long or short positions perpetual contract with leverage on an asset. When the asset goes up in value, the long side takes a profit. When the asset goes down in value, the short side takes a profit.
2. Leverage is borrowing money from our liquidity pool to hold a larger position.
3. Collateral is required when using leverage. Collateral will be used to cover up any losses incurred during trading. If the collateral reaches a percentage(configured by a settings utxo) of it's original value, the position gets liquidated
4. STRIKE token holders will be able to use higher leverage than non STRIKE token holders by using STRIKE as additional collateral. STRIKE can not be used as the sole collateral, only additional collateral. Main collateral will either be the underlying asset or stablecoin. STRIKE will be burnt if liquidated
5. Traders can set a stop loss or take profit, and we will automically closes their position when the asset reaches that price.
6. When using leverage, traders will need to pay an hourly borrow rate.
7. All profits are given out in the underlying asset + the traders initally put up

### Liquidity Pool Providers

1. Anyone can provide liquidity
2. Liquidity providers will keep 100% of the hourly borrow rate
3. When positions get liquidated they also keep 100% of the collateral
4. They will keep 100% of the on-chain fee.
5. They can withdraw their position anytime they want
6. They only get the fees generated from when they deposited liquidity

## References

1. [Parameters](https://docs.strikefinance.org/perpetuals/parameters)
2. [Formula](https://docs.strikefinance.org/perpetuals/position-settlement#calculation-formula)
