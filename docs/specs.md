- [Overview](#overview)
- [Architecture](#architecture)
- [Positions Validator](#positions-validator)
- [Liquidity Validator](#liquidity-validator)
- [Pool Validator](#pool-validator)
- [Orders Validator](orders-validator)
- [Prices](#prices)

## Overview

- A single UTxO is used to store the liquidity and trader's potential winnings. To solve for concurrency problem, a batcher will be used. All orders will go through the orders smart contract, and the batcher will gather them and apply the nessarry validations. Trader's potential loses will also be in the single utxo.

## Architecture

There a 4 total contracts that are used.

- **Positions Validator**: This validator handles the validation of user's positions mangement such as opening positions, closing positions, and liquidating their positions.

- **Liquidity Validator**: This validator handles the validations of liquidity providers such as providing liquidity and withdrawing liquidity.

- **Pool Validator**: This validator handles the validation of creating a pool and holds all the assets used for trading.

- **Orders Validator**: This script will be validating that the movements of assets are correct, ie when some closes a postion, they get the correct amount of assets back.

## Tokens

- **Positions Token**: Represents the total position value of the trader. This is 1:1 of the the total position size.
- **Liquidity Tokens**: Represent the amount of liquidity the lp has provided. This is 1:1 of the liquidity provided.
- **Batcher License**: Only holder of this license token can batch orders.
- **Pool NFT**: This can only be minted once per asset pool. It will be in the pool UTxO to validate the pool is valid.

## Positions Validator

This is a multivalidator with a spending and minting script. When the traders opens a position, they will first mint assets from the positions validator corresponding to his total position size(inital position size \* leverage). A UTxO will be sent to the orders validator for processing. Once the processing is done, the UTxO will be sent back to the positions validator. The trader will be able to close his position, specify stop loss and take profit by interacting with the UTxO here once it has been send back from the orders validator.

#### Params

- orders_script_hash: The script hash of the orders validator to make sure that UTxO is sent there
- validate_pool_ref: OutputReference: A reference to the Pool UTxO, to make sure that the max leverage have not been exceeded

#### Datum

- _owner_address_hash_: Owner of the position
- _entered_at_price_: Price at which the position was entered
- _underlying_asset_: The underlying asset that the perpetual contract is trading on
- _leverage_factor_: Leverage used for the position
- _positions_mint_asset_: Minted asset to represent the trader total position size
- _positions_mint_asset_amount_: Total position size of the trader, i.e., the initial size of position \* leverage
- _collateral_asset_: Stable collateral asset
- _collateral_asset_amount_: Total stable collateral amount
- _liquidate_usd_price_: Price at which the position will be liquidated
- _stop_loss_usd_price_: Stop loss price where the position will be closed
- _take_profit_usd_price_: Take profit price where the position will be closed
- _last_pay_lend_time_: Last time the hourly lend was paid
- _validate_pool_ref_: Reference to the pool validator
- _side_: Side of the position

#### Redeemer

```
pub type PositionsRedeemer {
  Close
  StopLoss
  UpdateStopLoss
  TakeProfit
  UpdateTakeProfit
  Liquidate
  PayLend
}

pub type PositionsMintRedeemer {
  MintPosition
  BurnPosition
}
```

#### Actions

- **Open positions**

  - When opening a short position, the trader must deposit a stable coin as collateral. When opening a long position, the trader must deposit the underlying asset as collateral.
  - The pool ref will pull in the Pool UTxo, where it's datum sepcifies the largest leverage the trader can use.
  - They will mint the amount of assets of their total position.
  - A UTxO must be sent to the orders validator with the minted assets, collateral, and valid datum values.

- **Close Position**

  - Only the owner of the position can close the positon.
  - To close a position the trader must sent a UTxO to the orders validtor with the minted assets, collateral, and valid datum values.

- **Stop Loss**

  - An off-chain bot will be monitoring all UTxOs at the script, and once the stop loss usd of the position is met, the position will be closed automatically.
  - The bot must sent the a UTxO to the orders validator with the minted assets, collateral, and valid datum values.

- **Update Stop Loss**

  - Traders will be able to update their stop loss amount, only the owner of the position can update it
  - The UTxO must be returned back to the positions validator with the minted assets, collateral, and only the `stop_loss_usd_price` datum is changed

- **Take profit**

  - An off-chain bot will be monitoring all UTxOs at the script, and once the take profit usd of the position is met, the position will be closed automatically
  - The bot must sent the a UTxO to the orders validator with the minted assets, collateral, and valid datum values.

- **Update Take Profit**

  - Traders will be able to update their take profit amount, only the owner of the position can update it
  - The UTxO must be returned back to the positions validator with the minted assets, collateral, and only the `take_profit_usd_price` datum is changed

- **Liquidate**

  - An off-chain bot will be monitoring all UTxOs at the script, and once the `liquidate_usd_price` of the position is met, the position will be closed automatically
  - The bot must sent the a UTxO to the orders validator with the minted assets, collateral, and valid datum values.

- **Pay Lend**

  - An off-chain bot will and see for all positions that has a datum value of `last_pay_lend_time` that was over 1 hour ago
  - The bot will burn the amount of minted tokens that represents the amount that the trader will pay
  - The UTxO must be returned back to the positions validator with the minted assets, collateral, and only the `last_pay_lend_time` and `liquidate_usd_price` datum is changed

## Liquidity Validator

This is a multivalidator with a spending and minting script. When someone wants to provide liquidity they will first mint the liquidity assets. The liquidity assets are 1:1 of the amount of assets provided. Then it will be sent to the orders validator. The order validator will send back the assets back to the liquidity validator. The UTxO sent back will contain datum values that will be used to calculate how much fees the provider has earned.

#### Params

- orders_script_hash: The script hash of the orders validator to make sure that UTxO is sent there
- asset_name: Asset name of the liquidity asset
- underlying_asset_policy_id: The policy id of the asset provided
- underlying_asset_name: The asset name of the asset provided

#### Datum

- _owner_address_hash_: Only the owner can withdraw liquidity
- _entered_earnings_per_share_: Will be used to compared with the earnings per share of the singular pool UTxO to calculate earnings
- _entered_collateral_earnings_per_share_: Will be used to compared with the collateral per share of the singular pool UTxO to calculate earnings by subtracting

#### Redeemer

```
pub type PositionsMintRedeemer {
  MintLiquididty
  BurnLiquidity
}
```

#### Actions

- **Add Liquidity**

  - To add liquidity, they must mint the amount of assets they will supply and send a UTxO to the orders script that contains all the minted assets amount and the correct datum value

- **Remove Liquidity**
  - To remove liquidity they will consume the UTxO sitting at the liquidity script and send it to be processed at the orders script. The UTxO must contain all the liquidity assets, and the correct datum values

// TODO, not sure if this is the best way. A few problems, what happens when they want to add more liquidity? Do we really need a UTxO that has the datums to calculate how much fees has been earned??

## Pool Validator

This is a multivalidator with a spending and minting script. The pool validator contains the UTxO that traders will consume their profits from, pay their losings and where liquidity providers will deposit liquidity into and withdraw liquidity. The datum in the pool UTxO contains params for perpetual trading such as the hourly pay rate, max leverage etc...

#### Params

- orders_stake_cred: The stake credential of the orders validator. The orders validator handles the logic of consuming / depositing unds of the pool UTxO. Anytime the pool validator is used, it checks if the orders stake validator is called
- admin_pkh: The admin will be able to mint an asset and create the pool UTxO. The admin will also be able to update the parameters of the script.

#### Redeemer

None

#### Datum

_underlying_asset_: The underlying asset that the pool is trading on
_underlying_asset_amount_: Total amount of underlying asset in the pool
_underlying_asset_lended_amount_: Total amount of underlying asset that has been lended out
_underlying_interest_rate_: The interest rate for the underlying asset
_liquidate_margin_: The margin required to liquidate the pool
_stable_collateral_asset_: The stable collateral asset used for the pool
_max_leverage_factor_: The max leverage factor for the pool
_max_strike_holder_leverage_factor_: The max leverage factor for the strike holder
_maintain_margin_amount_: The amount of margin to maintain for the pool
_is_valid_pool_asset_: Asset that determines if the pool is valid
_earnings_per_share_: The earnings per share for the pool, will increase each time the pool earns the underlying asset
_collateral_earnings_per_share_: The earnings per share for the collateral for the pool, will increase each time the pool earns the collateral asset

#### Actions

- Create Pool

  - Only the admin can create a pool, they will mint an asset, specify the datums, and lock the UTxO at the pool validator with the minted asset.

- Utilize Pool

  - To utilize the Pool, it will check if the withdrawal script of the orders validator was called

- Update Pool Params

  - Pool params can be updated only by the admin. The admin must consume the UTxO, consume no assets, return the UTxO back to the pool validator with the updated datum

## Orders Validator

This is a multivalidator with a spending and withdrawal script. Traders can cancel their transactions sitting here before the batcher picks it up. The batcher utilized a multi-utxo indexer to make sure the transactions are applied correctly, ie the input has the correct corressponding output.

#### Params

batcher_license: The license of the batcer. Only batcher holding the license can apply the orders
maximum_deadline_range: The deadline for the batcher license
underlying_asset_policy_id: The underyling policy_id of what the contract is trading on
underlying_asset_name: The underlying

#### Redeemer

```
pub type OrdersRedeemer {
  BatchOrders
  CancelOrders
}

pub type UTxOIndexer =
  List<(Int, Int)>

pub type OrdersWithdrawRedeemer {
  indexer: UTxOIndexer,
  batcher_index: Int,
  current_price: Int,
}
```

#### Datum

- _owner_address_hash_: Owner of the order
- _underlying_asset_: The underlying asset that the perpetual contract is trading on
- _underlying_asset_amount_: Initial size of the position
- _leverage_factor_: Leverage used for the position
- _orders_script_hash_: The script hash for the orders script that handles all the orders
- _positions_script_hash_: The script hash for the positions script that holds all the positions of the trader
- _positions_mint_asset_: Minted asset to represent the trader total position size
- _positions_mint_asset_amount_: Total position size of the trader,
- _liquidity_asset_: Minted asset to represent amount of liquidity that has been provided
- _liquidity_asset_amount_: Total amount of liquidity that has been provided
- _liquidity_positions_script_hash_: Script hash of the liquidity script that holds the providers' liquidity positions
- _collateral_asset_: The collateral asset used for the position
- _collateral_asset_amount_: Total amount of collateral asset used for the position
- _strike_collateral_asset_: The collateral asset used for the strike position
- _strike_collateral_amount_: Total amount of strike collateral asset used for the position
- _entered_earnings_per_share_: Earnings per share for the position
- _entered_collateral_earnings_per_share_: Earnings per share for the strike position
- _stop_loss_usd_price_: Stop loss USD price for the position
- _take_profit_usd_price_: Take profit USD price for the position
- _liquidate_usd_price_: Liquidate USD price for the position
- _order_submission_usd_price_: Price of asset when the order was submitted
- _order_submission_time_: The time the order was submitted
- _validate_pool_ref_: Reference to the pool validator
- _action_: Action to be taken for the order OpenPositionOrder/ClosePositionOrder/ProvideLiquidityOrder/WithdrawLiquidityOrder/LiquidateOrder
- _side_: Side of the position, Long/Short

#### Actions

A Multi-UTxO indexer is used to match the input to the output.
** Batching Orders and Their Individual Validations **

- **Open Position Order**

  - To open a position a UTxO must be sent to the positions validator with all the minted positions asset, the collateral, and that the datum values are correct

- **Close Position Order**

  - The validator will look at the current price of the asset and check that the output is going to the owner contains the correct amount of assets and all positions

- **Provide Liquidity Order**

  - The UTxO must be send to the positions validator, the minted assets are not consumed and the datum values are correct

- **Withdraw Liquidity Order**

  - The UTxO is going to the owner and it contains the correct amount assets

- **Liquidate Order**

  - There are no outputs corresponding to a liquidate order. The collateral will simply be consumed by the pool UTxO

- **Final validation**

  - After processing through all those orders. The validator will be looping through all the inputs and outputs through a reduce method and throw an exception when any of the above validation fails. The validator checks that the output pool UTxO has the correct amount of assets, and that the datum values are updated correctly. It will also check that the correct amount of assets are burnt. Example if 2 people closed their position, the validator will check that all the positions assets are burnt. If someone provided liquidity, it will check that the pool increased in assets.
  - The batcher license must be present in the transaction so we know that the batcher initiated the transaction

** Canceling Orders **

- **Cancel Open Position Order**

  - The minted assets must be burnt, the owner must signed the transaction

- **Cancel Close Position Order**

  - Collateral assets and minted position assets are sent back to the positions validator with the correct datum values

- **Cancel Provide Liquidity Order**

  - Liquidity assets must be burnt, the owner must signed the transaction

- **Cancel Withdraw Liquidity Order**

  - Collateral assets and minted assets are sent back to the positions validator with the correct datum values
