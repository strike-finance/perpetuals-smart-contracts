# Strike Finance Perpetuals Smart Contract

## Table of Contents
- [Introduction](#introduction)
- [Perpetuals on Strike Finance](#perpetuals-on-strike-finance)
- [Technical High-Level Overview](#technical-high-level-overview)
- [Smart Contract Implementation](#smart-contract-implementation)
  - [Enter Position](#enter-position)
  - [Close Position](#close-position)
  - [Stop Loss](#stop-loss)
  - [Liquidation](#liquidation)
  - [Collect Losses](#collect-losses)
  - [Distribute Gains](#distribute-gains)
- [Links](#links)
- [Disclaimers](#disclaimers)

## Introduction
We are introducing a simplified version of traditional perpetual contracts that is easier for newcomers to use and less risky, while retaining the same benefits:

1) Traders can hold positions indefinitely, earning regular gains if their positions align with current market conditions.
2) Traders can use leverage to potentially increase their profits.

## Perpetuals on Strike Finance 
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
To enter a position, the trader must mint tokens from the minting script and send them to the perpetual validator script address alongside their position in a single UTxO.

Below is the datum for a perpetual UTxO:
```
pub type PerpetualDatum {
  owner_address_hash: AddressHash,
  owner_bech32_address: String,
  total_ratio_feed: PolicyId,
  orcfax_price_feed: PolicyId,
  entry_price: Int,
  entry_time: POSIXTime,
  redeem_asset: AssetClass,
  position_asset: AssetClass,
  position_asset_amount: Int,
  position_code: Int,
  stop_loss: Int,
  leverage_amount: Int,
  distribute_time: POSIXTime,
}
```

The minting script will validate if the position is valid.

**Minting Script Validations**
* The amount of asset minted is the same as the amount specified in `position`
* The entry time is within the transaction interval
* The redeem assets are the assets minted from the script

### Close Position
Traders have the ability to close their positions within a certain timeframe. They cannot exit their position 1 hour before the funding round is going to end.

**Validation Logic**
* The assets locked up must be sent back to the trader
* The redeem assets are burnt
* The time interval is 1 hour before the funding round is going to end

### Stop Loss 
A trader can set a value in `stop_loss` to close their position once it falls below a certain value. An off-chain bot will be used to constantly monitor each trader's position and close the position when necessary.

**Validation Logic**
* The assets are being sent back to the trader
* The redeem assets must be burnt
* The time interval is 1 hour before the funding round is going to end
* Redeem assets are burnt 

### Liquidation
Strike Finance allows users to leverage their positions with an initial margin requirement of 25% and a minimum maintenance margin of 15%. For example, a trader with 100 ADA as collateral can borrow up to 300 ADA, creating a total position of 400 ADA. At the outset, the trader's equity (the difference between the position value and the loan) is 100 ADA, which meets the initial 25% margin requirement.

**Equity = Current Value of Assets − Loan Amount**

If after the funding round ends, the total value of the position drops 20% to 320 ADA, the new equity would be 20 ADA.

**20 ADA = 320 ADA - 300 ADA**

A minimum of 15% equity is required to maintain the position, which in this case is 48 ADA. Since the current equity (20 ADA) is below this threshold, the trader's position will be liquidated. The liquidated funds will automatically be sent to the distribute validator.

**Validations**
* The position falls below the margin requirement
* The funds are sent to the distribute validator
* Redeem assets are burnt

### Collect Losses 
An off-chain bot will collect losses from the losing positions during a cooldown interval between the old funding round ending and the new funding round starting. An oracle price feed will be fed into the script to determine how much the losing position will be sending to the distribute script address. The redeem assets will be sent along with the distribute. 

**Validation Logic**
* UTxOs consumed from the perpetual script will only give up the percentage change of the underlying asset's movement during the 4-hour interval into the distribute script address
* All UTxOs consumed are returned to the perpetual script with the same owner, position, leverage, and stop loss specified in the datum
* Can only be executed 4 hours after the start of the funding round
* The same amount of redeem asset is sent as the underlying position asset to the distribute script address
* Only collect from the losing position
* A valid oracle feed from Orcfax specified in the `orcfax_price_feed` needs to be fed to the script

### Distribute Gains
An off-chain bot will distribute the gains locked in the distribute script address and send them to the UTxOs of the winning traders that are locked in the perpetual script. An oracle total positions feed will be fed to the distribute validator to determine how much the winning side will gain. UTxOs will be consumed from the perpetuals script and sent back to it containing the gains.

**Validation Logic**
* Only the winning positions can receive assets from the distribute 
* Can only be executed 4 hours after the start of the funding round
* A valid oracle feed specified in the `total_ratio_feed` needs to be fed to the script
* The UTxOs consumed from the perpetual script will be sent back with the correct amount of winnings and datum values are not corrupted

## Links
- [Website](https://www.strikefinance.org/perpetuals)
- [Documentation](https://docs.strikefinance.org/)

## Disclaimers
This smart contract is subject to significant changes as testing is conducted. More features are to be added. As we conduct further market research, we might decide to pivot this current version of the perpetual contract into a more traditional perpetual contract similar to those seen on centralized exchanges.
