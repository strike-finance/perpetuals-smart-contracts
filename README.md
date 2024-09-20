# Strike Finance Perpetuals Smart Contract

## Table of Contents

- [Introduction](#introduction)
- [How the Platform Works](#how-the-platform-works)
- [Example Scenario](#example-scenario)
- [Comparison with Holding the Asset](#comparison-with-holding-the-asset)
- [Key Observations](#key-observations)
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

---

## Introduction

Our perpetual futures trading platform offers a unique opportunity for traders to amplify their profits through leverage while maintaining a balance between risk and reward. Whether you're a seasoned trader or new to futures trading, our platform provides the tools and mechanisms to maximize your trading potential.

---

## How the Platform Works

### Key Features

1. **Leverage Factor (\( \lambda \))**: Amplify your exposure to price movements without committing the full notional amount. Leverage magnifies both gains and losses.

2. **Notional Value**: The total value of your position, calculated as the initial margin (your invested capital) multiplied by the leverage factor.

3. **Percentage Price Change (\( \Delta P / P_0 \))**: The change in the asset's price over the trading period, expressed as a percentage.

4. **Fixed Minimum Fee (5%)**: An additional fee that the losing side pays to the winning side in each funding round, ensuring significant payouts even during low volatility.

### Payout Calculation Components

- **Matched Exposure (\( E \))**:
  \[
  E = \min(\text{Total Long Positions}, \text{Total Short Positions})
  \]
  The portion of positions that can be directly offset between longs and shorts.

- **Funding Rate Payout**:
  \[
  \text{Funding Payout} = E \times \lambda \times \left| \frac{\Delta P}{P_0} \right|
  \]
  Reflects gains or losses based on price movements and leverage.

- **Fixed 5% Fee**:
  \[
  \text{Fixed Fee} = E \times 5\%
  \]
  Ensures significant payouts each funding round.

- **Total Payout**:
  \[
  \text{Total Payout} = \text{Funding Payout} + \text{Fixed Fee}
  \]

### Important Notes

- **Leverage Amplifies Outcomes**: Both gains and losses are magnified by the leverage factor.

- **Unmatched Positions**: Positions exceeding the matched exposure do not earn gains or incur losses from price movements or the fixed fee in that funding round.

- **Risk Management**: Effective risk management is essential due to the amplified effects of leverage and the fixed fee.

---

## Example Scenario

### Setup

**Asset**: Cryptocurrency XYZ  
**Initial Price (\( P_0 \))**: \$1,000  
**Leverage Factor (\( \lambda \))**: 5x

**Participants and Positions**

#### Long Side (Total Notional Positions: \$80,000)

1. **Alice**

   - Initial Margin: \$10,000
   - Notional Position: \$10,000 × 5 = \$50,000

2. **Bob**
   - Initial Margin: \$6,000
   - Notional Position: \$6,000 × 5 = \$30,000

#### Short Side (Total Notional Positions: \$20,000)

1. **Charlie**

   - Initial Margin: \$3,000
   - Notional Position: \$3,000 × 5 = \$15,000

2. **Dave**
   - Initial Margin: \$1,000
   - Notional Position: \$1,000 × 5 = \$5,000

**Matched Exposure (\( E \))**:
\[
E = \min(\$80,000, \$20,000) = \$20,000
\]

**Unmatched Long Positions**:
\[
\text{Unmatched Longs} = \$80,000 - \$20,000 = \$60,000
\]

---

### Price Increase Scenario

**Price at End (\( P_1 \))**: \$1,050 (5% increase)

#### Calculations

1. **Percentage Price Change**:
   \[
   \frac{\Delta P}{P_0} = \frac{\$1,050 - \$1,000}{\$1,000} = 5\%
   \]

2. **Funding Rate Payout**:
   \[
   \text{Funding Payout} = \$20,000 \times 5 \times 5\% = \$5,000
   \]

3. **Fixed 5% Fee**:
   \[
   \text{Fixed Fee} = \$20,000 \times 5\% = \$1,000
   \]

4. **Total Payout**:
   \[
   \text{Total Payout} = \$5,000 + \$1,000 = \$6,000
   \]

#### Allocation of Gains and Losses

##### Long Side (Winning Side)

- **Alice's Matched Position**:
  \[
  \text{Alice's Matched Position} = \left( \frac{\$50,000}{\$80,000} \right) \times \$20,000 = \$12,500
  \]

- **Alice's Total Gain**:
  \[
  \text{Alice's Gain} = \left( \frac{\$12,500}{\$20,000} \right) \times \$6,000 = \$3,750
  \]

- **Bob's Matched Position**:
  \[
  \text{Bob's Matched Position} = \$20,000 - \$12,500 = \$7,500
  \]

- **Bob's Total Gain**:
  \[
  \text{Bob's Gain} = \left( \frac{\$7,500}{\$20,000} \right) \times \$6,000 = \$2,250
  \]

##### Short Side (Losing Side)

- **Charlie's Loss**:
  \[
  \text{Charlie's Loss} = \left( \frac{\$15,000}{\$20,000} \right) \times \$6,000 = \$4,500
  \]

- **Dave's Loss**:
  \[
  \text{Dave's Loss} = \$6,000 - \$4,500 = \$1,500
  \]

#### Unmatched Positions

- **Unmatched Long Positions**: Do not earn gains or incur losses in this round.

---

### Price Decrease Scenario

**Price at End (\( P_1 \))**: \$950 (5% decrease)

#### Calculations

1. **Percentage Price Change**:
   \[
   \frac{\Delta P}{P_0} = \frac{\$950 - \$1,000}{\$1,000} = -5\%
   \]

2. **Funding Rate Payout**:
   \[
   \text{Funding Payout} = \$20,000 \times 5 \times 5\% = \$5,000
   \]

3. **Fixed 5% Fee**:
   \[
   \text{Fixed Fee} = \$20,000 \times 5\% = \$1,000
   \]

4. **Total Payout**:
   \[
   \text{Total Payout} = \$5,000 + \$1,000 = \$6,000
   \]

#### Allocation of Gains and Losses

##### Short Side (Winning Side)

- **Charlie's Gain**:
  \[
  \text{Charlie's Gain} = \left( \frac{\$15,000}{\$20,000} \right) \times \$6,000 = \$4,500
  \]

- **Dave's Gain**:
  \[
  \text{Dave's Gain} = \$6,000 - \$4,500 = \$1,500
  \]

##### Long Side (Losing Side)

- **Alice's Loss**:
  \[
  \text{Alice's Loss} = \left( \frac{\$12,500}{\$20,000} \right) \times \$6,000 = \$3,750
  \]

- **Bob's Loss**:
  \[
  \text{Bob's Loss} = \$6,000 - \$3,750 = \$2,250
  \]

#### Unmatched Positions

- **Unmatched Long Positions**: Do not incur losses in this round.

---

## Comparison with Holding the Asset

### Price Increase Scenario

**Participant Gains from Holding the Asset**

- **Alice**:
  \[
  \text{Alice's Gain} = \$50,000 \times 5\% = \$2,500
  \]
- **Bob**:
  \[
  \text{Bob's Gain} = \$30,000 \times 5\% = \$1,500
  \]

**Comparison Table**

| Participant | Platform Gain | Holding Gain | Difference   | Platform ROI | Holding ROI |
| ----------- | ------------- | ------------ | ------------ | ------------ | ----------- |
| **Alice**   | \$3,750       | \$2,500      | **+\$1,250** | 37.5%        | 5%          |
| **Bob**     | \$2,250       | \$1,500      | **+\$750**   | 37.5%        | 5%          |

### Price Decrease Scenario

**Participant Losses from Holding the Asset**

- **Alice**:
  \[
  \text{Alice's Loss} = \$50,000 \times 5\% = -\$2,500
  \]
- **Bob**:
  \[
  \text{Bob's Loss} = \$30,000 \times 5\% = -\$1,500
  \]

**Comparison Table**

| Participant | Platform Loss | Holding Loss | Difference   | Platform ROI | Holding ROI |
| ----------- | ------------- | ------------ | ------------ | ------------ | ----------- |
| **Alice**   | -\$3,750      | -\$2,500     | **-\$1,250** | -37.5%       | -5%         |
| **Bob**     | -\$2,250      | -\$1,500     | **-\$750**   | -37.5%       | -5%         |

---

## Key Observations

1. **Amplified Returns**: The platform offers higher potential returns due to leverage and the fixed 5% fee, resulting in higher ROIs compared to simply holding the asset.

2. **Amplified Losses**: Losses are also greater on the platform when the market moves against a trader's position.

3. **Fixed Fee Impact**: The 5% fixed fee ensures significant payouts each funding round, enhancing both gains and losses.

4. **Unmatched Positions**: Traders with unmatched positions do not earn gains or incur losses in that funding round, which can result in missed opportunities.

5. **Risk Management**: Effective risk management is crucial due to the amplified effects of leverage and the fixed fee.

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

- The amount of asset minted is the same as the amount specified in `position`
- The entry time is within the transaction interval
- The redeem assets are the assets minted from the script

### Close Position

Traders have the ability to close their positions within a certain timeframe. They cannot exit their position 1 hour before the funding round is going to end.

**Validation Logic**

- The assets locked up must be sent back to the trader
- The redeem assets are burnt
- The time interval is 1 hour before the funding round is going to end

### Stop Loss

A trader can set a value in `stop_loss` to close their position once it falls below a certain value. An off-chain bot will be used to constantly monitor each trader's position and close the position when necessary.

**Validation Logic**

- The assets are being sent back to the trader
- The redeem assets must be burnt
- The time interval is 1 hour before the funding round is going to end
- Redeem assets are burnt

### Liquidation

Strike Finance allows users to leverage their positions with an initial margin requirement of 25% and a minimum maintenance margin of 15%. For example, a trader with 100 ADA as collateral can borrow up to 300 ADA, creating a total position of 400 ADA. At the outset, the trader's equity (the difference between the position value and the loan) is 100 ADA, which meets the initial 25% margin requirement.

**Equity = Current Value of Assets − Loan Amount**

If after the funding round ends, the total value of the position drops 20% to 320 ADA, the new equity would be 20 ADA.

**20 ADA = 320 ADA - 300 ADA**

A minimum of 15% equity is required to maintain the position, which in this case is 48 ADA. Since the current equity (20 ADA) is below this threshold, the trader's position will be liquidated. The liquidated funds will automatically be sent to the distribute validator.

**Validations**

- The position falls below the margin requirement
- The funds are sent to the distribute validator
- Redeem assets are burnt

### Collect Losses

An off-chain bot will collect losses from the losing positions during a cooldown interval between the old funding round ending and the new funding round starting. An oracle price feed will be fed into the script to determine how much the losing position will be sending to the distribute script address. The redeem assets will be sent along with the distribute.

**Validation Logic**

- UTxOs consumed from the perpetual script will only give up the percentage change of the underlying asset's movement during the 4-hour interval into the distribute script address
- All UTxOs consumed are returned to the perpetual script with the same owner, position, leverage, and stop loss specified in the datum
- Can only be executed 4 hours after the start of the funding round
- The same amount of redeem asset is sent as the underlying position asset to the distribute script address
- Only collect from the losing position
- A valid oracle feed from Orcfax specified in the `orcfax_price_feed` needs to be fed to the script

### Distribute Gains

An off-chain bot will distribute the gains locked in the distribute script address and send them to the UTxOs of the winning traders that are locked in the perpetual script. An oracle total positions feed will be fed to the distribute validator to determine how much the winning side will gain. UTxOs will be consumed from the perpetuals script and sent back to it containing the gains.

**Validation Logic**

- Only the winning positions can receive assets from the distribute
- Can only be executed 4 hours after the start of the funding round
- A valid oracle feed specified in the `total_ratio_feed` needs to be fed to the script
- The UTxOs consumed from the perpetual script will be sent back with the correct amount of winnings and datum values are not corrupted

## Links

- [Website](https://www.strikefinance.org/perpetuals)
- [Documentation](https://docs.strikefinance.org/)

## Disclaimers

This smart contract is subject to significant changes as testing is conducted. More features are to be added. As we conduct further market research, we might decide to pivot this current version of the perpetual contract into a more traditional perpetual contract similar to those seen on centralized exchanges.
