# Strike Finance Perpetuals Smart Contract

## Table of Contents

- [What are Perpetuals](#introduction)
- [Technical High-Level Overview](#technical-high-level-overview)
- [Smart Contract Implementation](#smart-contract-implementation)
  - [Batcher](#batcher)
  - [Enter Position](#enter-position)
  - [Cancel Enter Position](#enter-position)
  - [Pay Hourly Interest](#pay-hourly-interest)
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
```
pub type OrdersDatum {
  owner_address_hash: AddressHash,
  entered_at_price: Int,
  underlying_asset: Asset,
  position_amount: Int,
  leverage_factor: Int,
  positions_validator_hash: ScriptHash,
  positions_asset: Asset,
  orders_validator_hash: ScriptHash,
  stop_loss_amount: Int,
  side: PositionSide,
  action: OrderAction,
  liquidity_asset: Asset,
  liquidity_amount: Int,
  order_submission_time: POSIXTime,
  collateral_asset: Asset,
  collateral_amount: Int,
}
```
The batcher grabs all transactions sitting at the `orders.ak` and performs validations based on the action type. The validation is performed with a withdrawal script. This transaction will have the pool UTxO present. 

```
pub type OrderAction {
  OpenPosition
  ClosePosition
  ContributeLiquidity
  WithdrawLiquidity
}
```
Each individual UTxO will have a validation perform on them based on the action type, ie for closing position the trader is getting the correct amount of collateral and profit/loss back. 

The final validation will be looping through all the inputs and calculate the expected output pool UTxO has the correct datum and contains the correct amount of assets. 

### Enter Position
To enter a position you first mint assets from the `enter_position_mint.ak` file. The minting policy checks for the following things 
* A UTxO is send to the orders validator
* The UTxO contains the correct amount of collateral lock up, and the minted asset
* The amount of assets minted = total position value = position size * leverage
* All information in the datum to the orders validator is valid

Once it is in the orders validator and an off-chain batcher will pick it up
* A UTxO is send to the positions validator
* The UTxO contains the correct amount of minted assets and collateral
* The positions datum is valid
```
pub type PositionDatum {
  owner_address_hash: AddressHash,
  entered_at_price: Int,
  underlying_asset: Asset,
  position_amount: Int,
  leverage_factor: Int,
  stop_loss_amount: Int,
  positions_asset: Asset,
  side: PositionSide,
  entry_time: POSIXTime,
  collateral_asset: Asset,
  collateral_amount: Int,
}
```

### Pay Hourly Interest

### Cancel Enter Position
Users are able to cancel their orders. 
* Transaction is signed by the owner
* The position assets are burnt 

### Close Position
Once the UTxO is at the positions validator, traders can close their position.
* UTxO is sent to the orders validator for processing
* Position assets in the the position UTxO are all sent to the orders validator
* The datum in the order UTxO is valid
* The transaction is sent to the owner

### Cancel Close Position
Traders can cancel their close position order.
* UTxO is sent to the positions validator
* The UTxO has the correct datum
* The UTxO contains correct amount of minted asset and collateral

### Stop Loss
An off-chain bot will be looking for 

### Take Profit

### Provide Liquidity

### Cancel Provide Liquidity

### Withdraw Liquidity

### Cancel Withdraw Liquidity



