# Strike Finance Perpetuals Smart Contract

## Table of Contents

- [Introduction](#introduction)
- [How the Platform Works](#how-the-platform-works)
- [Example Scenario](#example-scenario)
- [Key Points](#key-points)

## Introduction

Perpetuals on STRIKE are a bit different than traditional perpetual futures while retaining the same benefits. Users will still be able to gain profits in perpetuity whilst utilizing leverage to amplify their gains.

During each funding period the price of the underlying asset will be recorded. After 1 hour the price of the asset is compared. If during this 1 hour period the asset has moved up in price, the long side wins, if the asset has moved down in price, the short side wins. No positions can be entered or closed within 10 minutes of the current funding period ending. The payout of this will be one of the main profits for traders aside from the price of their perpetual contract.

Traders are free to exit their position before the funding period ends for a profit. The price of their perpetual contract is determined by the price of the underlying asset.

All positions will be entered, bought, collateralized, and payed out in USDM.

## How the Platform Works

### Key Features

1. **Leverage Factor λ**: Amplify your exposure to price movements without committing the full notional amount. Leverage magnifies both gains and losses.

2. **Notional Value**: The total value of your position, calculated as the initial margin (your invested capital) multiplied by the leverage factor.

3. **Percentage Price Change (ΔP / P₀)**: The change in the asset's price over the trading period, expressed as a percentage.

4. **Fixed Minimum Fee (20%)**: An additional fee that the losing side pays to the winning side in each funding round, ensuring significant payouts even during low volatility.

5. **Locked Last 10 Minutes**: To prevent people from gaming the system and closing their positions right before the funding period ends. No positions can be entered or closed within the last 10 minutes of the funding period ends. Traders will still be able to place their positions for the next funding period during this 10 minutes lockdown, but can not enter their positions for the current funding period.

6. **Contract PNL** Traders can exit their position prematurely potentially for a profit without waiting for the funding period to end. The value of their contract will be the price of the `underlying asset x inital contract size x leverage`.

### Example PNL Calculation

**Scenario:**

- Trader: Eve
- Asset: ADA
- Entry Asset Price ($P_e$): $1,000
- Initial Contract Size ($S$): 10 ADA
- Leverage ($\lambda$): 5x
- Current Asset Price ($P_c$): $1,100

**Calculation:**

1. Contract Value at Entry:

   ```math
   \text{Entry Value} = P_e \times S \times \lambda = \$1,000 \times 10 \times 5 = \$50,000
   ```

2. Current Contract Value:

   ```math
   \text{Current Value} = P_c \times S \times \lambda = \$1,100 \times 10 \times 5 = \$55,000
   ```

3. PNL:
   ```math
   \begin{align*}
   \text{PNL} &= \text{Current Value} - \text{Entry Value} \\
               &= \$55,000 - \$50,000 = \$5,000
   \end{align*}
   ```

### Payout Calculation Components

- **Matched Exposure _(E)_**:
  The portion of positions that can be directly offset between longs and shorts.

```math
E = \min(\text{Total Long Positions}, \text{Total Short Positions})
```

<br>

- **Funding Rate Payout**:
  Reflects gains or losses based on price movements and leverage.

```math
\text{Funding Payout} = E \times \left| \frac{\Delta P}{P_0} \right|
```

<br>

- **Fixed 20% Fee**:
  Ensures significant payouts each funding round.

```math
\text{Fixed Fee} = E \times 20\%
```

<br>

- **Total Payout**:
  Total payout from losing position to winning position

```math
\text{Total Payout} = \text{Funding Payout} + \text{Fixed Fee}
```

<br>

- **Individual Contributor Payout**:

  Individual payout is calculated as follows:
  <br>

```math
\text{Individual Gain/Loss} = \left( \frac{\text{Participant's Notional Value}}{\text{Total Winning Notional Value}} \right) \times \text{Total Payout}
```

<br>
  
  **Example**:
  
  If a participant has a notional position of \$10,000, and the total notional position is \$20,000 and the total payout is \$6,000, their individual gain or loss would be:
```math
  \text{Individual Gain/Loss} = \left( \frac{\$10,000}{\$20,000} \right) \times \$6,000 = \$3,000
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

**Matched Exposure _(E)_**:

```math
E = \min(\$80,000, \$20,000) = \$20,000
```

<br>

**Unmatched Long Positions**:

```math
\text{Unmatched Longs} = \$80,000 - \$20,000 = \$60,000
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
  \text{Alice's Matched Position} = \left( \frac{\$50,000}{\$80,000} \right) \times \$5,000 = \$3,750
```

<br>

- **Bob's Total Gain**:

```math
  \text{Bob's Gain} = \left( \frac{\$30,000}{\$80,000} \right) \times \$6,000 = \$2,250
```

<br>

##### Short Side (Losing Side)

- **Charlie's Loss**:

```math
  \text{Charlie's Loss} = \left( \frac{\$15,000}{\$20,000} \right) \times \$6,000 = \$4,500
```

<br>

- **Dave's Loss**:

```math
  \text{Dave's Loss} = \left( \frac{\$5,000}{\$20,000} \right) \times \$6,000 = \$1,500
```

<br>

**Comparison Table**

| Participant | Platform Gain/Loss | Holding Gain/Loss | Difference   | Platform ROI | Holding ROI |
| ----------- | ------------------ | ----------------- | ------------ | ------------ | ----------- |
| **Alice**   | +\$3,750           | +\$500            | **+\$3,250** | 37.5%        | 5%          |
| **Bob**     | +\$2,250           | +\$300            | **+\$1,950** | 37.5%        | 5%          |
| **Charlie** | -\$4,500           | -\$150            | **-\$4,350** | -150%        | -5%         |
| **Dave**    | -\$1,500           | -\$50             | **-\$1,450** | -150%        | -5%         |
