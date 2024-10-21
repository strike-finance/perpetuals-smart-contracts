- [Overview](#overview)
- [Architecture](#scripts)
- [Positions Validator](#positions-validator)
- [Liquidity Validator](#pool-validator)
- [Pool Validator](#pool-validator)
- [Orders Validator](orders-smart-validator)
- [Prices](#prices)

## Overview

- A single UTxO is used to store the liquidity and trader's potential winnings. To solve for concurrency problem, a batcher will be used. All orders will go through the orders smart contract, and the batcher will gather them and apply the nessarry validations. Trader's potential loses will also be in the single utxo.

## Architecture

There a 4 total contracts that are used.

- Positions Validator: This validator handles the validation of user's positions mangement such as opening positions, closing positions, and liquidating their positions.

- Liquidity Validator: This validator handles the validations of liquidity providers such as providing liquidity and withdrawing liquidity.

- Pool Validator: This validator handles the validation of creating a pool and holds all the assets used for trading

- Orders Validator: This script will be validating that the movements of assets are correct, ie when some closes a postion, they get the correct amount of assets back.

## Tokens

- Positions Token: Represents the total position value of the trader. This is 1:1 of the his total position size. Example: 1_000_000 position token == 1_000_000 Lovelace
- Liquidity Tokens: Represent the amount of liquidity the lp has provided
- Batcher License: Only holder of this license token can batch orders
- Pool NFT: This can only be minted once per asset pool. It will be in the pool UTxO to validate the pool is valid

## Positions Validator

This is a multivalidator with a spending and minting script

#### Params

orders_script_hash: ScriptHash: The script hash of the orders validator
validate_pool_ref: OutputReference: A reference to the Pool UTxO

#### Datum

```
pub type PositionDatum {
  owner_address_hash: AddressHash,
  entered_at_price: Int,
  underlying_asset: Asset,
  leverage_factor: Int,
  positions_mint_asset: Asset,
  positions_mint_asset_amount: Int,
  collateral_asset: Asset,
  collateral_asset_amount: Int,
  liquidate_usd_price: Int,
  stop_loss_usd_price: Int,
  take_profit_usd_price: Int,
  last_pay_lend_time: POSIXTime,
  validate_pool_ref: OutputReference,
  side: PositionSide,
}
```

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
  Mint
  Burn
}
```

#### Actions

- Open positions

  - When opening a short position, the trader must deposit a stable coin as collateral. When opening a long position, the trader must deposit the underlying asset as collateral
  - The pool ref will pull in the Pool UTxo, where it's datum sepcifies the largest leverage the trader can use.
  - They will mint the amount of assets of their total position
  - A UTxO must be sent to the orders validator with the minted assets, collateral, and valid datum values.

- Close Position

  - Only the owner of the position can close the positon
  - To close a position the trader must sent a UTxO to the orders validtor with the minted assets, collateral, and valid datum values.

- Stop Loss

  - An off-chain bot will be monitoring all UTxOs at the script, and once the stop loss usd of the position is met, the position will be closed automatically
  - The bot must sent the a UTxO to the orders validator with the minted assets, collateral, and valid datum values.

- Update Stop Loss

  - Traders will be able to update their stop loss amount, only the owner of the position can update it
  - The UTxO must be returned back to the positions validator with the minted assets, collateral, and only the `stop_loss_usd_price` datum is changed

- Take profit

  - An off-chain bot will be monitoring all UTxOs at the script, and once the take profit usd of the position is met, the position will be closed automatically
  - The bot must sent the a UTxO to the orders validator with the minted assets, collateral, and valid datum values.

- Update Take Profit

  - Traders will be able to update their take profit amount, only the owner of the position can update it
  - The UTxO must be returned back to the positions validator with the minted assets, collateral, and only the `take_profit_usd_price` datum is changed

- Liquidate

  - An off-chain bot will be monitoring all UTxOs at the script, and once the `liquidate_usd_price` of the position is met, the position will be closed automatically
  - The bot must sent the a UTxO to the orders validator with the minted assets, collateral, and valid datum values.

- Pay Lend

  - An off-chain bot will and see for all positions that has a datum value of `last_pay_lend_time` that was over 1 hour ago
  - The bot will burn the amount of minted tokens that represents the amount that the trader will pay
  - The UTxO must be returned back to the positions validator with the minted assets, collateral, and only the `last_pay_lend_time` and `liquidate_usd_price` datum is changed

# Liquidity Validator

This is a multivalidator with a spending and minting script

#### Params

orders_script_hash: ByteArray,
asset_name: AssetName,
provided_asset_policy_id: PolicyId,
provided_asset_name: AssetName,

#### Datum

```
pub type LiquidityPositionDatum {
  owner_address_hash: AddressHash,
  entered_earnings_per_share: Int,
  entered_collateral_earnings_per_share: Int,
}
```

#### Redeemer

```
pub type PositionsMintRedeemer {
  MintLiquididty
  BurnLiquidity
}
```

#### Actions

- Add Liquidity

  - To add liquidity, they must mint the amount of assets they will supply and send a UTxO to the orders script that contains all the minted assets amount and the correct datum value

- Remove Liquidity
  - To remove liquidity they will consume the UTxO sitting at the liquidity script and send it to be processed at the orders script. The UTxO must contain all the liquidity assets, and the correct datum values

## Pool Validator

This is a multivalidator with a spending and minting script

#### Params

orders_stake_cred: Credential
admin_pkh: AddressHash

#### Redeemer

None

#### Datum

```
pub type PoolDatum {
  underlying_asset: Asset,
  underlying_asset_amount: Int,
  underlying_asset_lended_amount: Int,
  underlying_interest_rate: Int,
  liquidate_margin: Int,
  stable_collateral_asset: Asset,
  max_leverage_factor: Int,
  max_strike_holder_leverage_factor: Int,
  maintain_margin_amount: Int,
  is_valid_pool_asset: Asset,
  earnings_per_share: Int,
  collateral_earnings_per_share: Int,
}
```

#### Actions

- Create Pool
- Only the admin can create a pool, they will mint an asset, specify the datums, and lock the UTxO at the pool validator with the minted asset.
- Utilize Pool
- To utilize the Pool, it will check if the withdrawal script of the orders validator was called
- Update Pool Params
- Pool params can be updated only by the admin. The admin must consume the UTxO, consume no assets, return the UTxO back to the pool validator with the updated datum

## Orders Validator

This is a multivalidator with a spending and withdrawal script

#### Params

batcher_license: PolicyId,
underlying_asset_policy_id: PolicyId,
underlying_asset_name: AssetName,

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

```
pub type OrderAction {
  OpenPositionOrder
  ClosePositionOrder
  ProvideLiquidityOrder
  WithdrawLiquidityOrder
  LiquidateOrder
}

pub type OrdersDatum {
  owner_address_hash: AddressHash,
  underlying_asset: Asset,
  underlying_asset_amount: Int,
  leverage_factor: Int,
  orders_script_hash: ScriptHash,
  positions_script_hash: ScriptHash,
  positions_mint_asset: Asset,
  positions_mint_asset_amount: Int,
  liquidity_asset: Asset,
  liquidity_asset_amount: Int,
  liquidity_positions_script_hash: ScriptHash,
  collateral_asset: Asset,
  collateral_asset_amount: Int,
  strike_collateral_asset: Asset,
  strike_collateral_amount: Int,
  entered_earnings_per_share: Int,
  entered_collateral_earnings_per_share: Int,
  stop_loss_usd_price: Int,
  take_profit_usd_price: Int,
  liquidate_usd_price: Int,
  order_submission_usd_price: Int,
  order_submission_time: POSIXTime,
  validate_pool_ref: OutputReference,
  action: OrderAction,
  side: PositionSide,
}
```

#### Actions

A Multi-UTxO indexer is used to match the input to the output.

- Cancel Open Position Order
  - The minted assets must be burnt, the owner must signed the transaction
- Cancel Close Position Order
  - Collateral assets and minted position assets are sent back to the positions validator with the correct datum values
- Cancel Provide Liquidity Order
  - Liquidity assets must be burnt, the owner must signed the transaction
- Cancel Withdraw Liquidity Order

  - Collateral assets and minted assets are sent back to the positions validator with the correct datum values

- **Open Position Order**
  - To open a position a UTxO must be sent to the positions validator with all the minted positions asset, the collateral, and that the datum values are correct
- **Close Position Order**
  - The validator will look at the current price of the asset and check that the output is going to the owner contains the correct amount of assets and all positions
- Provide Liquidity Order
  - The UTxO must be send to the positions validator, the minted assets are not consumed and the datum values are correct
- **Withdraw Liquidity Order**

  - The UTxO is going to the owner and it contains the correct amount assets

- Liquidate Order

  - There are no outputs corresponding to a liquidate order. The collateral will simply be consumed by the pool UTxO

- **Final validation**
  - After processing through all those orders. The validator will be looping through all the inputs and outputs through a reduce method and throw an exception when any of the above validation fails. The validator checks that the output pool UTxO has the correct amount of assets, and that the datum values are updated correctly. It will also check that the correct amount of assets are burnt. Example if 2 people closed their position, the validator will check that all the positions assets are burnt. If someone provided liquidity, it will check that the pool increased in assets.
