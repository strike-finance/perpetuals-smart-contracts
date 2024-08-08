# Strike Finance Perpetuals Smart Contract


## Table of Contents
- [Introduction](#introduction)
- [Perpetuals On Strike Finance](#perpetuals-on-strike-finance)
- [Technical High-Level Overview](#technical-high-level-overview)
- [Oracles](#oracles)
- [Smart Contract Implementation](#smart-contract-implementation)
  - [Enter Position](#enter-position)
  - [Close Position](#close-position)
  - [Stop Loss](#stop-lose)
  - [Liquidation](#liquidation)
  - [Distribue Rewards](#distribute-rewards)
- [Links](#links)
- [Disclaimers](#disclaimers)

## Introduction
We are introducing a simpler version of traditional perpetual contracts that is easier for newcomers to use and less risky, while retaining the same benefits:

1) Traders can hold positions indefinitely, earning regular rewards if their positions align with current market conditions.
3) Traders can use leverage to potentially increase their profits.

## Perpetuals On Strike Finance 
On Strike Finance, there are no perpetual contract prices, only entry prices. Funding periods occur every 4 hours. At the beginning and end of each funding period, the underlying asset's price is recorded.

If the asset's price increases during the 4-hour period, long positions win. If it decreases, short positions win.
The losing side pays the winning side based on the percentage change in the asset's price during the 4-hour interval. Winning traders receive rewards proportional to their position size relative to the total winning pool.

### Setup
- Trader A: 100 ADA short
- Traders B and C: 100 ADA long each
- Start of funding round: ADA price = $1
- End of funding round: ADA price = $1.10 (10% increase)

### Result
- Trader A (short) loses and pays 10 ADA (10% of 100 ADA)
- Traders B and C (long) win and split the 10 ADA equally, receiving 5 ADA each

## Technical High-Level Overview

## Disclaimers
This smart contract is subject to heavy changes as testing is conducted. More features are to be added. As we conduct more market research, we might decide to go pivot this current version of the perpetual contract into a more traditional perpetual contract we see on centralized exchanges.
