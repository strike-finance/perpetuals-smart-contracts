use aiken/collection/list
use aiken/collection/pairs
use cardano/assets.{AssetName, PolicyId, Value, flatten, match, quantity_of}
use cardano/transaction.{
  InlineDatum, Input, Output, Transaction, find_script_outputs,
}
use constants.{
  batcher_fee, position_asset_name, strike_asset_name, strike_policy_id,
}
use math.{calculate_hourly_usd_borrow_fee}
use types.{
  OpenPositionOrder, OrderDatum, PoolDatum, PositionDatum, ScriptHash,
  SettingsDatum,
}
use utils.{get_lower_bound}

pub type LimitOrderRedeemer {
  CompleteLimitOrder { price: Int }
  CancelLimitOrder
}

pub type PositionMintRedeemer {
  OpenPosition { current_usd_price: Int, pool_index: Int, setting_index: Int }
  ClosePosition { burn_amount: Int }
}

validator position_mint(
  orders_script_hash: ScriptHash,
  pool_nft_policy_id: PolicyId,
  pool_nft_asset_name: AssetName,
  settings_nft_policy_id: PolicyId,
  settings_nft_asset_name: AssetName,
) {
  mint(
    redeemer: PositionMintRedeemer,
    policy_id: PolicyId,
    transaction: Transaction,
  ) {
    when redeemer is {
      OpenPosition(current_usd_price, pool_index, setting_index) ->
        mint_position_valid(
          transaction: transaction,
          orders_script_hash: orders_script_hash,
          current_usd_price: current_usd_price,
          policy_id: policy_id,
          pool_nft_policy_id: pool_nft_policy_id,
          pool_nft_asset_name: pool_nft_asset_name,
          settings_nft_policy_id: settings_nft_policy_id,
          settings_nft_asset_name: settings_nft_asset_name,
          pool_index: pool_index,
          setting_index: setting_index,
        )
      // Batcher might close/liquidate multiple positions at once
      ClosePosition(burn_amount) ->
        [(policy_id, position_asset_name, -burn_amount)] == flatten(
          transaction.mint,
        )
    }
  }

  else(_) {
    False
  }
}

pub fn mint_position_valid(
  transaction: Transaction,
  orders_script_hash: ScriptHash,
  current_usd_price: Int,
  policy_id: PolicyId,
  pool_nft_policy_id: PolicyId,
  pool_nft_asset_name: AssetName,
  settings_nft_policy_id: PolicyId,
  settings_nft_asset_name: AssetName,
  pool_index: Int,
  setting_index: Int,
) {
  let Transaction { mint, reference_inputs, .. } = transaction

  let outputs_to_orders_address: List<Output> =
    find_script_outputs(transaction.outputs, orders_script_hash)

  expect list.length(outputs_to_orders_address) == 1

  expect Some(output_to_orders_validator) = list.head(outputs_to_orders_address)
  expect InlineDatum(orders_datum) = output_to_orders_validator.datum
  expect orders_datum_typed: OrderDatum = orders_datum

  expect OpenPositionOrder {
    position_datum: PositionDatum {
      entered_position_time,
      entered_at_usd_price,
      position_asset_amount,
      hourly_usd_borrow_fee,
      collateral_asset,
      ..
    },
    ..
  } = orders_datum_typed.action

  expect Some(Input {
    output: Output { value: pool_value, datum: pool_datum, .. },
    ..
  }) = list.at(reference_inputs, pool_index)

  expect InlineDatum(pool_datum) = pool_datum
  expect pool_datum_typed: PoolDatum = pool_datum

  expect
    assets.quantity_of(pool_value, pool_nft_policy_id, pool_nft_asset_name) == 1

  let PoolDatum { underlying_asset, liquidity_total_asset_amount, .. } =
    pool_datum_typed

  let available_asset_amount =
    quantity_of(
      pool_value,
      underlying_asset.policy_id,
      underlying_asset.asset_name,
    )

  expect Some(Input {
    output: Output {
      value: global_settings_value,
      datum: global_settings_datum,
      ..
    },
    ..
  }) = list.at(reference_inputs, setting_index)
  expect InlineDatum(global_settings_datum) = global_settings_datum
  expect global_settings_datum_typed: SettingsDatum = global_settings_datum

  let SettingsDatum {
    interest_rate,
    max_leverage_factor,
    max_strike_holder_leverage_factor,
    ..
  } = global_settings_datum_typed

  expect
    assets.quantity_of(
      global_settings_value,
      settings_nft_policy_id,
      settings_nft_asset_name,
    ) == 1
  expect current_usd_price == entered_at_usd_price
  expect [(policy_id, position_asset_name, 1)] == flatten(mint)

  let collateral_asset_amount =
    quantity_of(
      output_to_orders_validator.value,
      collateral_asset.policy_id,
      collateral_asset.asset_name,
    )
  let strike_asset_amount =
    quantity_of(
      output_to_orders_validator.value,
      strike_policy_id,
      strike_asset_name,
    )

  // check if lovelace, and subtract collateral_asset_amount with batcher fee, or else the batcher fee gets counted twice
  if collateral_asset.policy_id == "" {
    let expected_assets_locked: Value =
      assets.from_lovelace(batcher_fee)
        |> assets.add(policy_id, position_asset_name, 1)
        |> assets.add(
            collateral_asset.policy_id,
            collateral_asset.asset_name,
            collateral_asset_amount - batcher_fee,
          )
        |> assets.add(strike_policy_id, strike_asset_name, strike_asset_amount)
    expect match(output_to_orders_validator.value, expected_assets_locked, >=)
  } else {
    let expected_assets_locked: Value =
      assets.from_lovelace(batcher_fee)
        |> assets.add(policy_id, position_asset_name, 1)
        |> assets.add(
            collateral_asset.policy_id,
            collateral_asset.asset_name,
            collateral_asset_amount,
          )
        |> assets.add(strike_policy_id, strike_asset_name, strike_asset_amount)
    expect match(output_to_orders_validator.value, expected_assets_locked, >=)
  }

  let pool_underlying_asset_amount =
    quantity_of(
      pool_value,
      underlying_asset.policy_id,
      underlying_asset.asset_name,
    )

  expect Some(total_asset_amount) =
    pairs.get_first(liquidity_total_asset_amount, underlying_asset.policy_id)

  let underlying_asset_lended_amount =
    total_asset_amount - available_asset_amount

  let estimated_hourly_usd_borrow_fee: Int =
    calculate_hourly_usd_borrow_fee(
      position_asset_amount,
      underlying_asset_lended_amount,
      current_usd_price,
      pool_underlying_asset_amount,
      interest_rate,
    )

  expect hourly_usd_borrow_fee >= estimated_hourly_usd_borrow_fee
  expect get_lower_bound(transaction.validity_range) >= entered_position_time

  let contains_strike_collateral: Bool =
    quantity_of(
      output_to_orders_validator.value,
      strike_policy_id,
      strike_asset_name,
    ) > 0
  // Make sure the amount of position_asset_amount is less than the collateral asset amount * leverage factor
  // for strike holders, they have a different leverage factor
  if contains_strike_collateral {
    position_asset_amount / max_strike_holder_leverage_factor <= collateral_asset_amount
  } else {
    position_asset_amount / max_leverage_factor <= collateral_asset_amount
  }
}
