# Strike Finance Perpetuals Smart Contract

## Table of Contents

- [What are Perpetuals](#introduction)
- [Technical High-Level Overview](#technical-high-level-overview)
- [Smart Contract Implementation](#smart-contract-implementation)
  - [Batcher](#batcher)
  - [Enter Position](#enter-position)
  - [Close Position](#close-position)
  - [Stop Loss](#stop-loss)
  - [Liquidate](#liquidate)
  - [Take Profit](#take-profit)
  - [Provide Liquidity](#provide-liquidity)
  - [Withdraw Liquidity](#withdraw-liquidity)

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

## Smart Contract Implementation

### Batcher

### Enter Position

### Close Position

### Stop Loss

### Take Profit

### Provide Liquidity

### Withdraw Liquidity
