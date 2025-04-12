- [Overview](#overview)
- [Architecture](#architecture)
- [Positions Validator](#positions-validator)
- [Liquidity Validator](#liquidity-validator)
- [Pool Validator](#pool-validator)
- [Orders Validator](orders-validator)
- [Prices](#prices)

## Overview

- Settings UTxO that keeps information such as max leverage, max borrow amount, interest rate, maintaince margin etc..
- A pool UTxO that contains assets liquidity providers will provide and lended out to traders.
- A position UTxO that determines the traders current position

## Architecture

There a 8 total contracts that are used.

- **position_mint.ak**: This is the inital validator when the user has to mint a token from when opening a position. To close a position the asset from this script must be burnt.

- **manage_positions.ak**: This validator handles the validation of user's positions mangement after opening a position such as updating take profit/stop loss, closing and liquidating position, and adding collateral.

- **orders.ak**: This validator handles all interactions with the pool, such as borrowing assets, returning assets, providing liquidity, and withdrawing liquidity.

- **liquidity_mint.ak**: This validator handles the validation of minting and burning of liquidity tokens. When you provide liquidity you get these in return and when you withdraw liquidity you need to burn these.

- **protocol_auth.ak** This is minted once. The asset minted from this script gives the righ to change the config of the settings.

- **settings.ak** Contains the settings UTxO.

- **batcher_license.ak** Mints token that allow them to run order batches.

- **pools.ak** Contains all the funds the liquidity providers deposited.

## Tokens

- **Positions Token**: Consitutes a valid transaction. Must be burnt when closing a transaction. Only minted once per transaction.
- **Liquidity Tokens**: Tokens liquidity provders recieve when providing liquidity.
- **Batcher License**: Only holder of this license token can batch orders.
- **Settings NFT**: This asset can be used to update configs in settings.

## High Level Flow For All Actions

All possible actions of the contracts are here
//TODO

- **Open Position**: Mints a token, send to orders validator. Order validator will send to the manage_positions.ak. The UTxO at the manage_positions.ak contains no assets. Collateral user put up is put into pool.
- **Close Position While Pending**: While it's at the orders validator pending to be batched, if it took the batcher long time and still haven't batched(for some reason...) the trader can close the position as if it has been batched. When they close the position the datum will be updated, the batcher will eventually pick it up, and the trader can get their assets back + profits.
- **Cancel Position While Pending**: This is similar to close position while pending, but in this case it is cancelling the position. The trader will simply get all their assets back.
- **Open Limit Order**: The same token is minted from the same script as opening position. Then send to the orders validator. The off-chain will simply ignore this limit order until it has been met and add it to the batcher
- **Cancel Limit Order**: Can cancel the limit order at anytime
- **Close Position**: When they close the position, they consume the assets that they will recieve from this position. Trader will send a close position request to the batcher. The batcher will then send the assets to the trader.
- **Update Take Profit and Stop Loss**: Consume UTxO at manage_positions.ak, send back with no assets consumed and only the datum field updated.
- **Take Profit and Stop Loss Tx**: Off-chain will monitor for this, once price has been reach send assets to the owner and the rest back to order.ak
- **Add Collateral**: Consume UTxO at manage_positions.ak, send back with additional collateral
- **Liquidate Collateral**: Send all assets to order.ak
- **Provide Liquidity**: Deposit liquidity assets into order.ak. Btacher will then mint and send lp tokens to the liquidity provider. They will recieve based on their current ratio of deposted funds to total funds \_ total lp tokens minted so far.
- **Withdraw Liquidity**: Deposit the tokens they recieved from providing liquidity. Batcher will burn those tokens and send the underlying assets back to them.They will recieve their current ratio of lp tokens to total lp tokens \_ total funds in pool.
- **Update Settings**: Must hold auth asset in tx. Consume from settings.ak,consume no assets, update datum, send back to script.

## position_mint.ak

This is a minting policy validator that handles the minting and burning of position tokens. When traders open a position, they mint a token from this validator. To close a position, the token must be burnt.

#### Params

- orders_script_hash: The script hash of the orders validator to ensure the UTxO is sent there
- pool_nft_policy_id: The policy ID of the pool NFT
- pool_nft_asset_name: The asset name of the pool NFT
- settings_nft_policy_id: The policy ID of the settings NFT
- settings_nft_asset_name: The asset name of the settings NFT

#### Redeemer

```
pub type PositionMintRedeemer {
  OpenPosition { current_usd_price: Int, pool_index: Int, setting_index: Int }
  ClosePosition { burn_amount: Int }
}
```

#### Actions

- **Open Position**

  - The validator mints exactly one position token and ensures it's sent to the orders validator
  - It verifies the current USD price matches the entered price in the position datum
  - It checks that the collateral amount meets the leverage requirements (different requirements for strike holders)
  - It validates the hourly USD borrow fee is at least the estimated fee
  - The transaction must include references to both the pool and settings UTxOs
  - The pool reference is used to verify the pool's underlying asset and calculate borrow fees
  - The settings reference is used to get the max leverage factors and interest rate

- **Close Position**

  - The validator simply checks that the correct amount of position tokens are being burned
  - The batcher might close or liquidate multiple positions at once, so it verifies the burn amount matches what's in the mint field

#### Key Validations

- **Leverage Check**: Position holders with strike collateral can use a higher leverage factor (max_strike_holder_leverage_factor) than regular position holders (max_leverage_factor)
- **Borrow Fee Calculation**: The hourly USD borrow fee is calculated based on the position size, lended amount, current price, pool size, and interest rate
- **Collateral Verification**: The validator ensures the correct amount of collateral is locked, with special handling for lovelace (ADA) to account for the batcher fee
- **Time Validation**: The transaction validity range's lower bound must be at least the entered position time

## manage_positions.ak

This is a spending validator that handles the management of positions after they have been created. It allows traders to close positions, add collateral, update stop loss and take profit levels, and handles liquidations.

#### Params

- orders_script_hash: The script hash of the orders validator to ensure UTxOs are sent there

#### Redeemer

```
pub type ManagePositionRedeemer {
  Close { close_price: Int, close_type: CloseType, output_to_user_index: Int }
  AddCollateral
  PositionUpdate { stop_loss: Int, take_profit: Int }
  LiquidateClose { current_usd_price: Int }
}
```

#### Datum

```
pub type PositionDatum {
  // Owner of the order
  owner_pkh: AddressHash,
  // Stake key if present
  owner_stake_key: Option<AddressHash>,
  // The amount of leverage used for the position. 1 = 1x inital collateral value. 10 = 10x inital collateral value
  leverage_factor: Int,
  // The time the order was submitted
  entered_position_time: POSIXTime,
  // The price at which the order was submitted
  entered_at_usd_price: Int,
  // The script hash for the positions script that holds all the positions of the trader
  position_hash: ScriptHash,
  // Collateral asset
  collateral_asset: Asset,
  // The margin required to liquidate the pool. Once the collateral falls below the maintain_margin_amount of the pool, their position gets liquidated. Example: 5 = 5%
  maintain_margin_amount: Int,
  // Total amount of USD value to pay for borrow each hour
  hourly_usd_borrow_fee: Int,
  // Stop loss price where the position will be closed
  stop_loss_usd_price: Int,
  // Take profit price where the position will be closed
  take_profit_usd_price: Int,
  // Amount of collateral asset in the position
  collateral_asset_amount: Int,
  // Amount of position asset in the position
  position_asset_amount: Int,
  // Long or short position
  side: PositionSide,
}
```

#### Actions

- **Close Position**

  - Validates that the position token is being burned
  - Calculates the position's current value based on entry price, current price, and accumulated interest fees
  - Ensures the correct amount of assets are being sent to the user and back to the pool
  - For trader-initiated closes, verifies the owner's signature is present
  - For stop loss and take profit closes, verifies the price conditions are met
  - Creates an order datum with the profit/loss information for the pool

- **Liquidate Position**

  - Verifies that the position has reached its liquidation price
  - The liquidation price is calculated based on the position side, size, entry price, maintenance margin, and accumulated interest fees
  - All assets are sent to the orders validator with a LiquidatePositionOrder action
  - The profit gained from liquidation is recorded in the order datum

- **Add Collateral**

  - Allows the position owner to add more collateral to their position
  - Verifies the owner's signature is present
  - Ensures the position datum remains unchanged
  - Checks that the output value is greater than or equal to the input value (additional collateral added)

- **Update Position**

  - Allows the position owner to update stop loss and take profit levels
  - Verifies the owner's signature is present
  - Ensures only the stop_loss_usd_price and take_profit_usd_price fields are modified in the datum
  - Checks that no assets are consumed in the process

#### Key Validations

- **Ownership Verification**: Most actions require the owner's signature to be present in the transaction
- **Price Validation**: For stop loss, take profit, and liquidation, the current price is checked against the relevant thresholds
- **Asset Accounting**: Ensures the correct amount of assets are transferred between the position, orders validator, and user
- **Interest Calculation**: Accumulated interest fees are calculated based on the time elapsed since position opening

## orders.ak

This is a multivalidator with a spending and withdrawal script. Traders can cancel their transactions sitting here before the batcher picks it up. The batcher utilizes a multi-utxo indexer to make sure the transactions are applied correctly, i.e., the input has the correct corresponding output.

#### Params

pool_nft_policy_id: The policy ID of the pool NFT
pool_nft_asset_name: The asset name of the pool NFT

#### Redeemer

```
pub type OrdersRedeemer {
  // Process all orders which includes providing and withdrawing liquidity
  ProcessOrders
  // Users placed limit order, can cancel anytime. Cancel open orders that has been sitting idle and havent been picked up by batcher
  CancelLimitOrder
  // A regular that has been placed, but havent been processed by batcher, and user wants to close it
  CloseOrderWhilePending(Int)
}

pub type OrdersWithdrawRedeemer {
  indexer: List<(Int, Int)>,
  pool_utxo_index: (Int, Int),
  batcher_license_utxo_index: Int,
}
```

#### Datum

```
pub type OrderDatum {
  action: OrderAction,
}

pub type OrderAction {
  // When opening position, all borrowed assets are taken from pool and sent to position UTxO
  OpenPositionOrder {
    position_datum: PositionDatum,
    open_position_type: OpenPositionType,
  }
  // Regular close position, where users personally closed their position and all funds are returned to pool
  ClosePositionOrder {
    send_asset_amount: Int,
    return_pool_asset_amount: Int,
    strike_collateral_amount: Int,
    owner_pkh: AddressHash,
    owner_stake_key: Option<AddressHash>,
    send_asset: Asset,
    pool_asset_profit_loss: Int,
  }
  LiquidatePositionOrder {
    profit: Int,
  }
  ProvideLiquidityOrder {
    owner_pkh: AddressHash,
    owner_stake_key: Option<AddressHash>,
    liquidity_asset: Asset,
  }
  WithdrawLiquidityOrder {
    owner_pkh: AddressHash,
    owner_stake_key: Option<AddressHash>,
  }
}

pub type PositionSide {
  Long
  Short
}

pub type OpenPositionType {
  MarketOrder
  LimitOrder
}

pub type PositionDatum {
  // Owner of the order
  owner_pkh: AddressHash,
  // Stake key if present
  owner_stake_key: Option<AddressHash>,
  // The amount of leverage used for the position. 1 = 1x inital collateral value. 10 = 10x inital collateral value
  leverage_factor: Int,
  // The time the order was submitted
  entered_position_time: POSIXTime,
  // The price at which the order was submitted
  entered_at_usd_price: Int,
  // The script hash for the positions script that holds all the positions of the trader
  position_hash: ScriptHash,
  // Collateral asset
  collateral_asset: Asset,
  // The margin required to liquidate the pool. Once the collateral falls below the maintain_margin_amount of the pool, their position gets liquidated. Example: 5 = 5%
  maintain_margin_amount: Int,
  // Total amount of USD value to pay for borrow each hour
  hourly_usd_borrow_fee: Int,
  // Stop loss price where the position will be closed
  stop_loss_usd_price: Int,
  // Take profit price where the position will be closed
  take_profit_usd_price: Int,
  // Amount of collateral asset in the position
  collateral_asset_amount: Int,
  // Amount of position asset in the position
  position_asset_amount: Int,
  // Long or short position
  side: PositionSide,
}

pub type CloseType {
  TraderClose
  StopLossClose
  TakeProfitClose
}
```

#### Actions

A Multi-UTxO indexer is used to match the input to the output.
** Batching Orders and Their Individual Validations **

- **Cancel Order**

  - Allows users to cancel their order if it hasn't been processed by the batcher yet
  - For market orders, cancellation is only allowed if the order has been sitting idle for more than 3 minutes (180,000 milliseconds)
  - Limit orders can be cancelled at any time
  - The transaction must be signed by the position owner
  - The position token must be burned (position_hash, position_asset_name with value -1)
  - Only one validator input is allowed in the transaction

- **Close Order While Pending**

  - Allows a user to close their position even if it has not been picked up by the batcher
  - The transaction must be signed by the position owner
  - The position token must be burned (position_hash, position_asset_name with value -1)
  - Calculates the position's USD value based on current price, entry price, and position side
  - Determines the amount of assets to return to the user
  - Ensures only one script input is present in the transaction
  - Verifies that the correct assets are returned to the positions validator
  - Creates an AutomatedClosePositionOrder in the output datum with the calculated asset amounts

- **Process Orders**

- **Final validation**

  - After processing through all those orders. The validator will be looping through all the inputs and outputs through a reduce method and throw an exception when any of the above validation fails. The validator checks that the output pool UTxO has the correct amount of assets, and that the datum values are updated correctly. It will also check that the correct amount of assets are burnt. Example if 2 people closed their position, the validator will check that all the positions assets are burnt. If someone provided liquidity, it will check that the pool increased in assets.
  - The batcher license must be present in the transaction so we know that the batcher initiated the transaction
  - **Order Validation Types**:
    - **Open Position Order**: The validator ensures the output script hash matches the position hash from the datum. It verifies the borrowed assets are properly moved from the pool and sent to the position UTxO. The pool value is updated to reflect the deduction of the lended amount.
    - **Close Position Order**: The validator verifies that the pool asset profit or loss value is correctly applied to the pool. The pool datum's total gains/losses field is updated according to whether there was a profit or loss on the position. Sends the expected assets to the user
    - **Liquidate Position Order**: The validator verifies the asset amount returned to the pool from the liquidation. The pool datum's total gains/losses field is updated with the profit incurred from the liquidation.
    - **Provide Liquidity Order**: The validator ensures liquidity is added correctly to the pool. It checks that the LP tokens sent to the owner are proportionate to the liquidity provided. The pool datum's total LP minted and total asset amount fields are increased accordingly.
    - **Withdraw Liquidity Order**: The validator verifies that assets are correctly withdrawn from the pool based on the LP tokens deposited. The pool datum's total LP minted and total asset amount fields are decreased to reflect the withdrawal.

## protocol_auth.ak

Protocol authentication validator that controls the minting of protocol tokens. This validator is used first in the setup process and can only mint tokens once.

#### Params

seed: OutputReference - The transaction output reference used as a seed to ensure the policy can only be used once

#### Redeemer

```
// The protocol_auth validator uses Data as its redeemer type
// No specific redeemer structure is needed as the validation
// is based on checking the transaction's mint field
```

#### Overview:

- Mints three essential protocol tokens:
  - `PROTOCOL_MANAGER_NFT`: Used to authenticate protocol management operations
  - `PROTOCOL_POOL_NFT`: Used to identify and authenticate pool operations
  - `PROTOCOL_SETTINGS_NFT`: Used to identify and authenticate settings operations

#### Validation Logic:

- Ensures the mint transaction includes the seed output reference
- Validates that exactly one of each required protocol token is minted:
  - `PROTOCOL_MANAGER_NFT` (amount == 1)
  - `PROTOCOL_POOL_NFT` (amount == 1)
  - `PROTOCOL_SETTINGS_NFT` (amount == 1)
- This validator acts as a one-time authorization mechanism to initialize the protocol

## liquidity_mint.ak

Validator for minting and burning liquidity provider (LP) tokens. This validator doesn't perform detailed validations itself, instead delegating most validation logic to the orders script.

#### Params

orders_script_credential: Credential - The credential of the orders script that is authorized to validate liquidity operations

#### Redeemer

```
pub type LiquidityRedeemer {
  ProvideLiquidity
  BurnLiquidity
}
```

#### Overview:

- Allows two types of operations:
  - `ProvideLiquidity`: Minting LP tokens when liquidity is provided
  - `BurnLiquidity`: Burning LP tokens when liquidity is withdrawn
- Delegates actual calculations and validations to the orders script

#### Validation Logic:

- Ensures that the orders script is involved in the transaction by checking for its credential in the withdrawals
- Performs no other validation on the amount of tokens minted or burned, as this is handled by the orders validator
- The orders validator manages all calculations for determining how many LP tokens should be minted or burned

## settings.ak

Validator that controls access to protocol settings. It ensures that only authorized entities with the protocol manager token can modify protocol settings.

#### Params

manager_policy_id: PolicyId - The policy ID of the protocol manager token
manager_asset_name: AssetName - The asset name of the protocol manager token

#### Redeemer

```
pub type SettingRedeemer {
  pmanager_in_idx: Int,
}
```

#### Overview:

- Protects the settings UTxO from unauthorized modifications
- Requires the protocol manager token to be present in the transaction

#### Validation Logic:

- Accepts a `SettingRedeemer` that specifies which input contains the protocol manager token
- Verifies that the specified input contains exactly one protocol manager token (from the specified policy ID and asset name)
- All other validations regarding the specific settings changes are delegated to the transaction logic

## batcher_license.ak

Validator for minting batcher license tokens that authorize batchers to process orders within the protocol.

#### Params

auth_policy_id: PolicyId - The policy ID of the protocol manager token
auth_asset_name: AssetName - The asset name of the protocol manager token

#### Redeemer

```
pub type LicenseRedeemer {
  deadline: ByteArray,
  protocol_manager_in_idx: Int,
}
```

#### Overview:

- Controls the minting of batcher license tokens
- Requires the protocol manager token to authorize minting
- Includes a deadline in the minted token name to enforce time limitations

#### Validation Logic:

- Accepts a `LicenseRedeemer` containing:
  - A deadline bytearray to be used as the token name
  - The input index where the protocol manager token can be found
- Verifies that the specified input contains exactly one protocol manager token
- Ensures that exactly one batcher license token is minted with the specified deadline as its name

## pool.ak

Validator for managing pool UTxOs that contain the liquidity for trading operations. Like the liquidity validator, it delegates most validation logic to the orders script.

#### Params

orders_stake_cred: Credential - The stake credential of the orders script that is authorized to validate pool operations

#### Redeemer

```
// The pool validator uses Int as its redeemer type
// No specific redeemer structure is needed as validation
// is delegated to the orders script
```

#### Overview:

- Controls access to the pool's assets
- Delegates all validation logic to the orders script
- Ensures that pool assets can only be manipulated through properly validated transactions

#### Validation Logic:

- Verifies that the orders script is involved in the transaction by checking for its credential in the withdrawals
- Performs no other direct validation on pool operations
- The orders script is responsible for:
  - Validating position openings and closings
  - Enforcing proper asset transfers to and from the pool
  - Updating pool datum values correctly based on operations
