# Strike Finance Perpetuals Smart Contract

## Table of Contents

- [Introduction](#introduction)
- [How the Platform Works](#how-the-platform-works)
- [Example Scenario](#example-scenario)
- [Comparison with Holding the Asset](#comparison-with-holding-the-asset)
- [Key Points](#key-points)


## Introduction
Perpetuals on STRIKE are less risky than traditional perpetual futures while keeping the same benefits. Users will still be able to gain profits in perpetuity whilst utilizing leverage to amplify their gains. There are no mark prices, funding rates, and no margin requirements. 

Every 4 hour there the price of the underlying asset will be recorded. After 4 hour the price of the asset is compared. If during this 4 hour period the asset has moved up in price, the long side wins, if the asset has moved down in price, the short side wins. No positions can be entered or closed within 30 minutes of the current funding period ending.

You are able to exit your position for a profit if more people enters the same position as you after the funding period starts. Your position will potentially be at a loss if people exited the position after the funding period starts. This does not affect the funding period payout, only the price of your current positions.

Since there are no margin requirements. Your position will simply close once it reaches 0. 

## How the Platform Works

### Key Features

1. **Leverage Factor λ**: Amplify your exposure to price movements without committing the full notional amount. Leverage magnifies both gains and losses.

2. **Notional Value**: The total value of your position, calculated as the initial margin (your invested capital) multiplied by the leverage factor.

3. **Percentage Price Change (ΔP / P₀)**: The change in the asset's price over the trading period, expressed as a percentage.

4. **Fixed Minimum Fee (20%)**: An additional fee that the losing side pays to the winning side in each funding round, ensuring significant payouts even during low volatility.

5. **Locked Last 30 Minutes**: To prevent people from gaming the system and closing their positions right before the funding period ends. No positions can be entered or closed within the last 30 minutes of the funding period ends. Traders will be able to place their positions for the next funding period during this 30 minutes lockdown. 


### Payout Calculation Components
- **Matched Exposure *(E)***: The portion of positions that can be directly offset between longs and shorts.
```math
E = \min(\text{Total Long Positions}, \text{Total Short Positions})
```
<br>

- **Funding Rate Payout**: Reflects gains or losses based on price movements and leverage.

```math
\text{Funding Payout} = E \times \left| \frac{\Delta P}{P_0} \right|
```
<br>

- **Fixed 20% Fee**: Ensures significant payouts each funding round.

```math
\text{Fixed Fee} = E \times 20\%
```
<br>

- **Total Payout**: Total payout from losing position to winning position
```math
\text{Total Payout} = \text{Funding Payout} + \text{Fixed Fee}
```

<br>

- **Individual Contributor Payout**: Individual payout is calculated as follows:
<br>

 ```math
\text{Individual Gain/Loss} = \left( \frac{\text{Participant's Notional Value}}{\text{Total Winning/Losing Notional Value}} \right) \times \text{Total Payout}
 ```
<br>
  
## Example Scenario

### Setup

**Asset**: ADA <br>
**Initial Price (P₀)**: \$1,000  
**Leverage Factor λ**: 5x

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

**Matched Exposure *(E)***:
```math
E = \min(\$80,000, \$20,000) = \$20,000
```
<br>

### Price Increase Scenario Calculations

**Price at End (P₁)**: \$1,050 (5% increase)

1. **Percentage Price Change**:
```math
   \frac{\Delta P}{P_0} = \frac{\$1,050 - \$1,000}{\$1,000} = 5\%
```
<br>

3. **Funding Rate Payout**:
```math
   \text{Funding Payout} = \$20,000 \times 5\% = \$1,000
```
<br>

4. **Fixed 20% Fee**:
```math
   \text{Fixed Fee} = \$20,000 \times 20\% = \$4,000
```
<br>

5. **Total Payout**:
```math
   \text{Total Payout} = \$1,000 + \$4,000 = \$5,000
```
<br>

#### Allocation of Gains and Losses

##### Long Side (Winning Side)

- **Alice's Gain**:
```math
  \text{Alice's Matched Position} = \left( \frac{\$50,000}{\$80,000} \right) \times \$5,000 = \$3,125 
```
<br>

- **Bob's Total Gain**:
```math
  \text{Bob's Gain} = \left( \frac{\$30,000}{\$80,000} \right) \times \$5,000 = \$1,875
```
<br>

##### Short Side (Losing Side)

- **Charlie's Loss**:
```math
  \text{Charlie's Loss} = \left( \frac{\$15,000}{\$20,000} \right) \times \$5,000 = \$3,750
```
<br>

- **Dave's Loss**:
```math
  \text{Dave's Loss} = \left( \frac{\$5,000}{\$20,000} \right) \times \$5,000 = \$1,250
```
<br>

**Comparison Table**

| Participant | Platform Gain/Loss | Holding Gain/Loss | Difference   | Platform ROI | Holding ROI |
| ----------- | ------------------ | ----------------- | ------------ | ------------ | ----------- |
| **Alice**   | +\$3,125           | +\$500            | **+\$2,625** | 31.25%        | 5%          |
| **Bob**     | +\$1,875           | +\$300            | **+\$1,575** | 31.25%        | 5%          |
## Key Points

1. **Amplified Return And Loses**: The platform offers higher potential returns due to leverage and the fixed 20% fee, resulting in higher ROIs compared to simply holding the asset. Losses are also greater on the platform when the market moves against a trader's position.

2. **Fixed Fee Impact**: The 20% fixed fee ensures significant payouts each funding round, enhancing both gains and losses.

3. **Frequent Funding Periods**: With a funding period happening every 1 hour, traders will be able to gain rewards consistently.



