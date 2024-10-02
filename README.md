# Strike Finance Perpetuals Smart Contract

## Table of Contents

- [What are Perpetuals](#introduction)
- [Technical High-Level Overview](#technical-high-level-overview)
- [Smart Contract Implementation](#smart-contract-implementation)
  - [Batcher](#batcher)
  - [Enter Position](#enter-position)
  - [Cancel Enter Position](#enter-position)
  - [Close Position](#close-position)
  - [Cancel Close Position](#close-position)
  - [Stop Loss](#stop-loss)
  - [Liquidate](#liquidate)
  - [Take Profit](#take-profit)
  - [Provide Liquidity](#provide-liquidity)
  - [Cancel Provide Liquidity](#cancel-provide-liquidity)
  - [Withdraw Liquidity](#withdraw-liquidity)
  - [Cancel Withdraw Liquidity](#cancel-withdraw-liquidity)

## What are Perpetuals
Perpetual futures are a type of derivative contract that allows traders to speculate on the continuous price movement of an underlying asset without an expiration date, enabling positions to be held indefinitely. These contracts typically offer leverage, meaning traders can control larger positions with a relatively small amount of capital by essentially borrowing, which amplifies both potential gains and losses. To manage the increased risk associated with leveraged trading, perpetual futures require maintenance margins—minimum account balances that must be maintained to keep positions open. 

There are two positions that a trader can take, a long and a short. Traders will open a long position when they think the underlying asset will up in value and a short position when they think it will go down in value. To open a position, the trader will need to deposit USDM as collateral for opening short positions and the underlying asset for opening long positions. When they close their position they will be able to keep all the profits + the collateral back. Any losses that occured will be deducted from their collateral

**Scenario**
**Long Position**
Collateral: 100 USD worth of ADA
Leverage: 10x 
Total Position: 1000 USD worth of ada
ADA Percentage USD Change: +10% 
Profits: 100 * 10 * .1 = 100

When the trader closes their position they will be keep the $100 profit + their original collateral of 100 USD worth of ADA back.

**Short Position** 
Collateral: 100 USDM 
Leverage: 10x 
Total Position: 1000 USD worth of ADA
ADA Percentage USD Change: -10% 
Profits: 100 * 10 * -(-.1) = 100

When the trader closes their position they will be keep the $100 profit + their original collateral of 100 USDM back


When traders use leverage, they will need to pay interest on the amount borrowed hourly. The formula for calculating borrowed hourly is as follows.
```Amount Of Tokens Borrowed From Liquidity Pool/All Tokens In Liquidity Pool * Borrow Rate * Size Of Position```

The traders final profit/loss from exiting their position will be 
```Final Position Value - Inital Position Value - (Hourly Borrowed Rate * Hours Borrowed)```

## Technical High-Level Overview
There are 3 Minting Scripts and 3 Validator Scripts used. We also use a batcher. All liquidity users will be used to borrow and take profits from will be in the singular UTxO. 

The `orders.ak` script is a script that holds all pending transactions. All actions on the platform will have to go through the `orders.ak` script. 

The `pools.ak` file is a multivalidator with that has a minting script an a spending script. The minting script validates that the singular UTxO that contains the liquidity is a valid UTxO and created by us. The `pools.ak` script is parameterized by the staking credential of the `orders.ak` script. The only way to consume anything from the `pools.ak` script is if the withdrawal script in `orders.ak` is called. 

The `enter_position_mint.ak` script handles minting of assets that validates the traders position is valid. If their position is valid, ie the trader deposited the correct amount of collateral, the datum values are correct, and the UTxO is being sent to the `orders.ak` script.  

The `position.ak` script handles logic for stop loss, take profit, and interest payment for borrowing funds. Stop loss and take profits are things the traders can set to close their position once it reaches a certain value automatically. 

The `liquidity_mint.ak` script mints assets that liquidity providers will hold in their wallet. To withdraw their liquidity they simply send their assets to the `orders.ak` script, and the batcher will burn the minted assets and send the liquidity assets as well as the fees earned for providing liquidity back to them. 


## Smart Contract Implementation
### Batcher
The batcher grabs all transactions sitting at the `orders.ak`

### Enter Position

### Cancel Enter Position

### Close Position

### Cancel Close Position

### Stop Loss

### Take Profit

### Provide Liquidity

### Cancel Provide Liquidity

### Withdraw Liquidity

### Cancel Withdraw Liquidity

### Pay Hourly Interest


