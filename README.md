# Strike Finance Perpetuals Smart Contract

## Table of Contents

- [What are Perpetuals](#what-are-perpetuals)
- [Technical High-Level Overview](#technical-high-level-overview)
- [Calculations](#calculations)
  - [User Profits And Loss](#user-profits-and-loss)
  - [Hourly Borrowed Rate](#hourly-borrowed-rate)
  - [Liquidity Provider Earned Fees](#liquidity-provider-earned-fees)
- [Smart Contract Implementation](#smart-contract-implementation)
  - [Batcher](#batcher)
  - [Enter Position](#enter-position)
  - [Cancel Enter Position](#cancel-enter-position)
  - [Close Position](#close-position)
  - [Cancel Close Position](#cancel-close-position)
  - [Provide Liquidity](#provide-liquidity)
  - [Cancel Provide Liquidity](#cancel-provide-liquidity)
  - [Withdraw Liquidity](#withdraw-liquidity)
  - [Cancel Withdraw Liquidity](#cancel-withdraw-liquidity)
  - [Pay Hourly Interest](#pay-hourly-interest)
  - [Take Profit](#take-profit)
  - [Stop Loss](#stop-loss)
  - [Liquidate](#liquidate)

## What are Perpetuals

Perpetual futures are a type of derivative contract that allows traders to speculate on the continuous price movement of an underlying asset without an expiration date, enabling positions to be held indefinitely. These contracts typically offer leverage, meaning traders can control larger positions with a relatively small amount of capital by essentially borrowing, which amplifies both potential gains and losses. To manage the increased risk associated with leveraged trading, perpetual futures require maintenance margins—minimum account balances that must be maintained to keep positions open.

There are two positions that a trader can take: a long and a short. Traders will open a long position when they think the underlying asset will go up in value and a short position when they think it will go down in value. To open a position, the trader will need to deposit USDM as collateral for opening short positions and the underlying asset for opening long positions. When they close their position, they will be able to keep all the profits plus the collateral back. Any losses that occurred will be deducted from their collateral.

## Technical High-Level Overview

There are 3 Minting Scripts and 3 Validator Scripts used. We also use a batcher. All liquidity users will be used to borrow and take profits from will be in a singular UTxO.

The `orders.ak` script is a script that holds all pending transactions. All actions on the platform will have to go through the `orders.ak` script.

The `pools.ak` file is a multivalidator that has a minting script and a spending script. The minting script validates that the singular UTxO that contains the liquidity is a valid UTxO and created by us. The `pools.ak` script is parameterized by the staking credential of the `orders.ak` script. The only way to consume anything from the `pools.ak` script is if the withdrawal script in `orders.ak` is called.

The `enter_position_mint.ak` script handles minting of assets that validates the trader's position is valid. If their position is valid, i.e., the trader deposited the correct amount of collateral, the datum values are correct, and the UTxO is being sent to the `orders.ak` script.

The `position.ak` script handles logic for stop loss, take profit, and interest payment for borrowing funds. Stop loss and take profits are things the traders can set to close their position once it reaches a certain value automatically.

The `liquidity_mint.ak` script mints assets that liquidity providers will hold in their wallet. To withdraw their liquidity, they simply send their assets to the `orders.ak` script, and the batcher will burn the minted assets and send the liquidity assets as well as the fees earned for providing liquidity back to them.

## Calculations

### Trader Profit And Loss

**Long Position**

- Collateral: 100 USD worth of ADA
- Leverage: 10x
- Total Position: 1000 USD worth of ADA
- ADA Percentage USD Change: +10%
- Profits: 100 _ 10 _ 0.1 = 100

When the trader closes their position, they will keep the $100 profit + their original collateral of 100 USD worth of ADA back.

**Short Position**

- Collateral: 100 USDM
- Leverage: 10x
- Total Position: 1000 USD worth of ADA
- ADA Percentage USD Change: -10%
- Profits: 100 _ 10 _ -(-.1) = 100

When the trader closes their position, they will keep the $100 profit + their original collateral of 100 USDM back.

### Hourly Borrowed Rate

When traders use leverage, they will need to pay interest on the amount borrowed hourly. The formula for calculating borrowed hourly is as follows:

```
Amount Of Tokens Borrowed From Liquidity Pool / All Tokens In Liquidity Pool * Borrow Rate * Size Of Position
```

The trader's final profit/loss from exiting their position will be:

```
Final Position Value - Initial Position Value - (Hourly Borrowed Rate * Hours Borrowed)
```

Certainly! Below is the updated version of your document, incorporating the **Reward Debt** method to address the flaw in the original Earnings Per Share (EPS) calculation. This method ensures that liquidity providers only earn from the point they start providing liquidity, preventing new providers from benefiting from past earnings.

---

### **Liquidity Provider Earned Fees (Updated with Reward Debt Method)**

Liquidity providers will keep profits earned from the perpetual protocol.

#### **Pool-Level Variables:**

- **Total Liquidity (`TotalFunds`):** Total amount of liquidity in the pool.
- **Accumulated Earnings Per Share for Assets (`AccEPS_Assets`):** Cumulative assets earnings distributed per unit of liquidity.
- **Accumulated Earnings Per Share for Collateral (`AccEPS_Collateral`):** Cumulative collateral earnings distributed per unit of liquidity.

#### **User-Level Variables:**

- **User Liquidity (`UserLiquidity`):** Amount of liquidity provided by the user.
- **User Reward Debt for Assets (`UserRewardDebt_Assets`):** The portion of assets earnings per share the user is not yet entitled to claim.
- **User Reward Debt for Collateral (`UserRewardDebt_Collateral`):** The portion of collateral earnings per share the user is not yet entitled to claim.

---

### **Mechanism Overview**

1. **Updating Accumulated EPS When Earnings Are Added:**

   - **For Assets:**

     ```math
     \Delta AccEPS_{\text{Assets}} = \frac{\text{Assets Earned}}{\text{TotalFunds}}
     ```

     ```math
     AccEPS_{\text{Assets, new}} = AccEPS_{\text{Assets, old}} + \Delta AccEPS_{\text{Assets}}
     ```

   - **For Collateral:**

     ```math
     \Delta AccEPS_{\text{Collateral}} = \frac{\text{Collateral Earned}}{\text{TotalFunds}}
     ```

     ```math
     AccEPS_{\text{Collateral, new}} = AccEPS_{\text{Collateral, old}} + \Delta AccEPS_{\text{Collateral}}
     ```

2. **When a User Provides Liquidity:**

   - **Update Total Funds:**

     ```math
     \text{TotalFunds}_{\text{new}} = \text{TotalFunds}_{\text{old}} + \text{UserLiquidity}
     ```

   - **Calculate User's Reward Debt:**

     - **For Assets:**

       ```math
       \text{UserRewardDebt}_{\text{Assets}} = \text{UserLiquidity} \times AccEPS_{\text{Assets}}
       ```

     - **For Collateral:**

       ```math
       \text{UserRewardDebt}_{\text{Collateral}} = \text{UserLiquidity} \times AccEPS_{\text{Collateral}}
       ```

3. **When a User Withdraws Liquidity:**

   - **Calculate User's Earnings:**

     - **For Assets:**

       ```math
       \text{User's Assets Earnings} = (\text{UserLiquidity} \times AccEPS_{\text{Assets}}) - \text{UserRewardDebt}_{\text{Assets}}
       ```

     - **For Collateral:**

       ```math
       \text{User's Collateral Earnings} = (\text{UserLiquidity} \times AccEPS_{\text{Collateral}}) - \text{UserRewardDebt}_{\text{Collateral}}
       ```

   - **Update User's Liquidity and Reward Debt:**

     - **Adjust User's Liquidity:**

       ```math
       \text{UserLiquidity}_{\text{new}} = \text{UserLiquidity}_{\text{old}} - \text{Withdrawn Amount}
       ```

     - **Update User's Reward Debt:**

       - **For Assets:**

         ```math
         \text{UserRewardDebt}_{\text{Assets, new}} = \text{UserLiquidity}_{\text{new}} \times AccEPS_{\text{Assets}}
         ```

       - **For Collateral:**

         ```math
         \text{UserRewardDebt}_{\text{Collateral, new}} = \text{UserLiquidity}_{\text{new}} \times AccEPS_{\text{Collateral}}
         ```

   - **Update Total Funds:**

     ```math
     \text{TotalFunds}_{\text{new}} = \text{TotalFunds}_{\text{old}} - \text{Withdrawn Amount}
     ```

---

### **Example Calculation Using the Reward Debt Method**

Let's consider both assets and collateral earnings in this example.

#### **Initial State**

- **Total Liquidity:**

  ```math
  \text{TotalFunds} = 1,000 \text{ units}
  ```

- **Accumulated Earnings Per Share:**

  ```math
  AccEPS_{\text{Assets}} = 0
  ```

  ```math
  AccEPS_{\text{Collateral}} = 0
  ```

---

#### **User A Provides Liquidity**

- **User A's Liquidity:**

  ```math
  \text{UserLiquidity}_A = 100 \text{ units}
  ```

- **Update Total Funds:**

  ```math
  \text{TotalFunds} = 1,000 + 100 = 1,100 \text{ units}
  ```

- **Calculate User A's Reward Debt:**

  - **For Assets:**

    ```math
    \text{UserRewardDebt}_{\text{Assets, A}} = 100 \times 0 = 0
    ```

  - **For Collateral:**

    ```math
    \text{UserRewardDebt}_{\text{Collateral, A}} = 100 \times 0 = 0
    ```

---

#### **Pool Earns 200 Units of Assets and 100 Units of Collateral**

- **Update Accumulated EPS for Assets:**

  ```math
  \Delta AccEPS_{\text{Assets}} = \frac{200}{1,100} \approx 0.1818
  ```

  ```math
  AccEPS_{\text{Assets}} = 0 + 0.1818 = 0.1818
  ```

- **Update Accumulated EPS for Collateral:**

  ```math
  \Delta AccEPS_{\text{Collateral}} = \frac{100}{1,100} \approx 0.0909
  ```

  ```math
  AccEPS_{\text{Collateral}} = 0 + 0.0909 = 0.0909
  ```

---

#### **User B Provides Liquidity**

- **User B's Liquidity:**

  ```math
  \text{UserLiquidity}_B = 300 \text{ units}
  ```

- **Update Total Funds:**

  ```math
  \text{TotalFunds} = 1,100 + 300 = 1,400 \text{ units}
  ```

- **Calculate User B's Reward Debt:**

  - **For Assets:**

    ```math
    \text{UserRewardDebt}_{\text{Assets, B}} = 300 \times 0.1818 = 54.54
    ```

  - **For Collateral:**

    ```math
    \text{UserRewardDebt}_{\text{Collateral, B}} = 300 \times 0.0909 = 27.27
    ```

---

#### **Pool Earns Another 140 Units of Assets and 70 Units of Collateral**

- **Update Accumulated EPS for Assets:**

  ```math
  \Delta AccEPS_{\text{Assets}} = \frac{140}{1,400} = 0.1
  ```

  ```math
  AccEPS_{\text{Assets}} = 0.1818 + 0.1 = 0.2818
  ```

- **Update Accumulated EPS for Collateral:**

  ```math
  \Delta AccEPS_{\text{Collateral}} = \frac{70}{1,400} = 0.05
  ```

  ```math
  AccEPS_{\text{Collateral}} = 0.0909 + 0.05 = 0.1409
  ```

---

#### **User A Withdraws Liquidity**

- **Calculate User A's Earnings:**

  - **For Assets:**

    ```math
    \text{User's Assets Earnings}_A = (100 \times 0.2818) - 0 = 28.18 \text{ units}
    ```

  - **For Collateral:**

    ```math
    \text{User's Collateral Earnings}_A = (100 \times 0.1409) - 0 = 14.09 \text{ units}
    ```

- **Update User A's Liquidity and Reward Debt:**

  - **User A withdraws all liquidity:**

    ```math
    \text{UserLiquidity}_A = 100 - 100 = 0 \text{ units}
    ```

  - **Update User A's Reward Debt:**

    - **For Assets:**

      ```math
      \text{UserRewardDebt}_{\text{Assets, A}} = 0 \times 0.2818 = 0
      ```

    - **For Collateral:**

      ```math
      \text{UserRewardDebt}_{\text{Collateral, A}} = 0 \times 0.1409 = 0
      ```

- **Update Total Funds:**

  ```math
  \text{TotalFunds} = 1,400 - 100 = 1,300 \text{ units}
  ```

---

#### **User B Withdraws Liquidity Later**

- **Assuming No Further Earnings, Accumulated EPS Remains:**

  ```math
  AccEPS_{\text{Assets}} = 0.2818
  ```

  ```math
  AccEPS_{\text{Collateral}} = 0.1409
  ```

- **Calculate User B's Earnings:**

  - **For Assets:**

    ```math
    \text{User's Assets Earnings}_B = (300 \times 0.2818) - 54.54 = 84.54 - 54.54 = 30 \text{ units}
    ```

  - **For Collateral:**

    ```math
    \text{User's Collateral Earnings}_B = (300 \times 0.1409) - 27.27 = 42.27 - 27.27 = 15 \text{ units}
    ```

- **Update User B's Liquidity and Reward Debt:**

  - **User B withdraws all liquidity:**

    ```math
    \text{UserLiquidity}_B = 300 - 300 = 0 \text{ units}
    ```

  - **Update User B's Reward Debt:**

    - **For Assets:**

      ```math
      \text{UserRewardDebt}_{\text{Assets, B}} = 0 \times 0.2818 = 0
      ```

    - **For Collateral:**

      ```math
      \text{UserRewardDebt}_{\text{Collateral, B}} = 0 \times 0.1409 = 0
      ```

- **Update Total Funds:**

  ```math
  \text{TotalFunds} = 1,300 - 300 = 1,000 \text{ units}
  ```

---

### **Summary with Reward Debt Method**

- **User A:**

  - **Initial Liquidity:** 100 units
  - **Assets Earnings:** 28.18 units
  - **Collateral Earnings:** 14.09 units
  - **Total Return:** 100 (Liquidity) + 28.18 (Assets) + 14.09 (Collateral) = **142.27 units**

- **User B:**

  - **Initial Liquidity:** 300 units
  - **Assets Earnings:** 30 units
  - **Collateral Earnings:** 15 units
  - **Total Return:** 300 (Liquidity) + 30 (Assets) + 15 (Collateral) = **345 units**

---

### **Explanation**

#### **User A's Earnings Calculation:**

- **Assets Earnings:**

  ```math
  \text{User's Assets Earnings}_A = (100 \times 0.2818) - 0 = 28.18 \text{ units}
  ```

- **Collateral Earnings:**

  ```math
  \text{User's Collateral Earnings}_A = (100 \times 0.1409) - 0 = 14.09 \text{ units}
  ```

- **Total Return for User A:**

  ```math
  \text{Total Return}_A = 100 + 28.18 + 14.09 = 142.27 \text{ units}
  ```

#### **User B's Earnings Calculation:**

- **Assets Earnings:**

  ```math
  \text{User's Assets Earnings}_B = (300 \times 0.2818) - 54.54 = 84.54 - 54.54 = 30 \text{ units}
  ```

- **Collateral Earnings:**

  ```math
  \text{User's Collateral Earnings}_B = (300 \times 0.1409) - 27.27 = 42.27 - 27.27 = 15 \text{ units}
  ```

- **Total Return for User B:**

  ```math
  \text{Total Return}_B = 300 + 30 + 15 = 345 \text{ units}
  ```

---

### **Key Points**

- **Fair Distribution of Earnings:**

  - **User A** earns from both earnings periods since they were providing liquidity during both.
  - **User B** earns only from the second earnings period since their Reward Debt accounts for the Accumulated EPS at the time they joined.

- **Reward Debt Mechanism:**

  - **Prevents New Users from Earning Past Earnings:**

    - By calculating Reward Debt when a user provides liquidity, we ensure they don't receive earnings accrued before they joined.

- **AccEPS Remains Unchanged During Liquidity Changes:**

  - **AccEPS** is updated only when the pool earns new fees, not when users add or remove liquidity.

- **Total Funds Impact on Future Earnings:**

  - When users withdraw liquidity, **TotalFunds** decreases, affecting future increments of AccEPS.

```
pub type OrdersDatum {
  owner_address_hash: AddressHash,
  entered_at_price: Int,
  underlying_asset: Asset,
  underlying_amount: Int,
  leverage_factor: Int,
  orders_script_hash: ScriptHash,
  positions_validator_hash: ScriptHash,
  positions_asset: Asset,
  positions_asset_amount: Int,
  liquidity_asset: Asset,
  liquidity_asset_amount: Int,
  stable_collateral_asset: Asset,
  stable_collateral_asset_amount: Int,
  strike_collateral_asset: Asset,
  strike_collateral_amount: Int,
  entered_earnings_per_share: Int,
  entered_collateral_earnings_per_share: Int,
  stop_loss_amount: Int,
  take_profit_amount: Int,
  order_submission_time: POSIXTime,
  validate_pool_ref: OutputReference,
  action: OrderAction,
  side: PositionSide,
}

pub type PositionDatum {
  owner_address_hash: AddressHash,
  entered_at_price: Int,
  underlying_asset: Asset,
  leverage_factor: Int,
  positions_asset: Asset,
  positions_asset_amount: Int,
  collateral_asset: Asset,
  collateral_amount: Int,
  stop_loss_amount: Int,
  take_profit_amount: Int,
  last_pay_lend_time: POSIXTime,
  entered_earnings_per_share: Int,
  entered_collateral_earnings_per_share: Int,
  validate_pool_ref: OutputReference,
  side: PositionSide,
}

pub type PoolDatum {
  pool_asset: Asset,
  pool_asset_amount: Int,
  pool_asset_lended_amount: Int,
  pooled_interest_rate: Int,
  collateral_asset: Asset,
  max_leverage_factor: Int,
  max_strike_holder_leverage_factor: Int,
  maintain_margin_amount: Int,
  liquidity_asset: Asset,
  earnings_per_share: Int,
  collateral_earnings_per_share: Int,
}

pub type LiquidityPositionDatum {
  owner_address_hash: AddressHash,
  entered_earnings_per_share: Int,
  entered_collateral_earnings_per_share: Int,
}
```

### Batcher

The batcher grabs all transactions sitting at the `orders.ak` and performs validations based on the action type. The validation is performed with a withdrawal script. This transaction will have the pool UTxO present.

```aiken
pub type OrderAction {
  OpenPosition
  ClosePosition
  ProvideLiquidity
  WithdrawLiquidity
}
```

Each individual UTxO will have a validation performed on them based on the action type, e.g., for closing position, the trader is getting the correct amount of collateral and profit/loss back.

The final validation will be looping through all the inputs and calculating the expected output pool UTxO has the correct datum and contains the correct amount of assets.

### Enter Position

To enter a position, you first mint assets from the `enter_position_mint.ak` file. The minting policy checks for the following things:

- A UTxO is sent to the orders validator
- The UTxO contains the correct amount of collateral lock up, and the minted asset
- The amount of assets minted = total size of position, Example, 1000ADA position = 1000 minted position asset.
- All information in the datum to the orders validator is valid
- The leverage opened is not higher than what is specified in the liquidity datum

Once it is in the orders validator and an off-chain batcher will pick it up:

- A UTxO is sent to the positions validator
- The UTxO contains the correct amount of minted assets and collateral
- The positions datum is valid

### Cancel Enter Position

Users are able to cancel their orders.

- Transaction is signed by the owner
- The position assets are burnt

### Close Position

Once the UTxO is at the positions validator, traders can close their position.

- UTxO is sent to the orders validator for processing
- Position assets in the position UTxO are all sent to the orders validator
- The datum in the order UTxO is valid
- The transaction is sent to the owner

Once it reaches the order validator, the validator will perform the following checks:

- The correct amount of underlying asset is being sent to the owner
- The collateral is sent back to the owner
- The position assets are burnt

To calculate how much the user will get back, we calculate the current value of the user's position which will be `current price * leverage * position amount` then subtract it with the amount of position asset in the UTxO for long Positions. For short positions it will be the inverse where you are subtracting the position asset in the UTxO by `current price * leverage * position amount`

### Cancel Close Position

Traders can cancel their close position order.

- UTxO is sent back to the positions validator
- The UTxO has the correct datum
- The UTxO contains the correct amount of minted asset and collateral

### Provide Liquidity

To provide liquidity, the users will mint assets from the liquidity_mint script and send a UTxO to the orders validator. The minting script will check for the following things:

- The datum is valid, i.e., the datum specifies the correct amount of liquidity provided
- The amount of asset minted is 1:1 of the liquidity provided
- The UTxO is being sent to the orders validator

Once it reaches the order validator, the validator will not perform any checks. The orders validator, aside from validating each order type, will also loop through all the orders in the input and calculate the expected output of the liquidity UTxO.

### Cancel Provide Liquidity

Traders can cancel their provide liquidity order.

- The liquidity assets are burnt

### Withdraw Liquidity

If the users want to withdraw their liquidity, they will send the liquidity asset to be processed in the orders validator. The tokens rewarded from provided liquidity will be the same tokens that they used to supply the liquidity

Once it reaches the order validator, the validator will perform the following checks:

- The liquidity asset must be burnt
- The amount of liquidity withdrawn is valid
- The liquidity is sent to the owner

### Cancel Withdraw Liquidity

Traders can cancel their withdraw liquidity order.

- Assets are sent back to the owner
- The owner signed the transaction

### Pay Hourly Interest

An off-chain bot will be keeping track of these positions every hour. Once an hour has passed, they will consume the positions UTxO and burn some amount of the minted asset.

- The Position UTxO is sent back to the validator
- After calculating the hourly borrow rate, they will pay back interest by burning the minted assets in the positions UTxO
- The datum has not changed

### Stop Loss

Traders are able to set a Stop Loss, which closes their position once the price of the underlying asset reaches a certain amount. An off-chain bot will be monitoring all transactions on the blockchain and execute the Stop Loss action once the criteria has been met.

- Checks that the stop loss in the datum has been reached
- Sends UTxO to the orders validator with all the minted asset
- The UTxO contains a valid datum, i.e., has not been changed from the positions UTxO

Once it reaches the order validator, the validator will perform the following checks:

- The collateral is being returned to the owner
- The position assets are burnt
- The correct amount of underlying asset is being sent to the owner

### Take Profit

Traders are able to set a Take Profit, which closes their position once the price of the underlying asset reaches a certain amount. An off-chain bot will be monitoring all transactions on the blockchain and execute the Take Profit action once the criteria has been met.

- Checks that the Take Profit in the datum has been reached
- Sends UTxO to the orders validator with all the minted asset
- The UTxO contains a valid datum, i.e., has not been changed from the positions UTxO

Once it reaches the order validator, the validator will perform the following checks:

- The collateral is being returned to the owner
- The position assets are burnt
- The correct amount of underlying asset is being sent to the owner

### Liquidate

In long positions, when the price drops below the liquidation price, the trader's position will be liquidated. In short positions, when the price rises higher than the liquidation price, the trader's position will be liquidated. Losses will be covered by the trader's collateral. Once the collateral reaches 2.5% of its original value, the position will be liquidated. An off-chain bot will be monitoring transactions and liquidate once liquidation criteria is met.

- The collaterals are sent to the orders validator to be processed
- The liquidation price has been met
  - Since each hour the borrowed fee is deducted from the user, the smart contract will get the current value of the position which will be `current price * position size amount` then subtract it by the amount of positions assets in the UTxO. Then we will subtract the initial collateral amount with that value. The final value will be compared to see if it is less than 2.5% of the original collateral amount

Once it reaches the orders validator it will perform the following checks:

- The collaterals are sent to the liquidity UTxO
- The positions assets are burnt
