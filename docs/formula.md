- [Formulas](#calculations)
  - [User Profits And Loss](#user-profits-and-loss)
  - [Hourly Borrowed Rate](#hourly-borrowed-rate)
  - [Liquidity Provider Earned Fees](#liquidity-provider-earned-fees)

## Formulas

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

### Liquidity Provider Earned Fees

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
