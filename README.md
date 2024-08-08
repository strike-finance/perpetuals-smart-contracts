# Strike Finance Perpetuals Smart Contract


## Table of Contents
- [Introduction](#introduction)
- [Perpetuals On Strike Finance](#perpetuals-on-strike-finance)
- [Technical High-Level Overview](#technical-high-level-overview)
- [Smart Contract Implementation](#smart-contract-implementation)
  - [Enter Position](#enter-position)
  - [Close Position](#close-position)
  - [Stop Loss](#stop-lose)
  - [Liquidation](#liquidation)
  - [Distribue Gains](#distribute-gains)
- [Links](#links)
- [Disclaimers](#disclaimers)

## Introduction
We are introducing a simpler version of traditional perpetual contracts that is easier for newcomers to use and less risky, while retaining the same benefits:

1) Traders can hold positions indefinitely, earning regular gains if their positions align with current market conditions.
3) Traders can use leverage to potentially increase their profits.

## Perpetuals On Strike Finance 
On Strike Finance, there are no perpetual contract prices, only entry prices. Funding periods occur every 4 hours. At the beginning and end of each funding period, the underlying asset's price is recorded.

If the asset's price increases during the 4-hour period, long positions win. If it decreases, short positions win.
The losing side pays the winning side based on the percentage change in the asset's price during the 4-hour interval. Winning traders receive gains proportional to their position size relative to the total winning pool.

### Setup
- Trader A: 100 ADA short
- Traders B and C: 100 ADA long each
- Start of funding round: ADA price = $1
- End of funding round: ADA price = $1.10 (10% increase)

### Result
- Trader A (short) loses and pays 10 ADA (10% of 100 ADA)
- Traders B and C (long) win and split the 10 ADA equally, receiving 5 ADA each

## Technical High-Level Overview
Two types of oracle feeds will be used: one for the price of the underlying asset and another for the total long/short positions. Each person's position is stored in a UTxO with relevant information about the current funding round, entry price, leverage, and stop loss.

The system employs three scripts: a perpetual validator script that handles closing positions and collecting losses, a distribute validator script that manages the distribution of gains to the winning side, and a minting script to validate traders' positions. Closing positions will involve burning tokens, while earning gains will result in the movement of assets between UTxOs.

An off-chain bot will be responsible for collecting losses, distributing gains, handling liquidations, and closing positions, including stop losses.

## Smart Contract Implementation
### Enter Position

### Close Position

### Stop Loss 

### Liquidation

### Distribute Gains

## Disclaimers
This smart contract is subject to heavy changes as testing is conducted. More features are to be added. As we conduct more market research, we might decide to go pivot this current version of the perpetual contract into a more traditional perpetual contract we see on centralized exchanges.
