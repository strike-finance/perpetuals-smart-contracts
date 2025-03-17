use aiken/collection/list
use cardano/assets.{PolicyId, Value, flatten, match, quantity_of}
use cardano/transaction.{
  InlineDatum, Input, Output, OutputReference, Transaction, find_script_outputs,
}
use constants.{
  batcher_fee, position_asset_name, strike_asset_name, strike_policy_id,
}
use math.{calculate_hourly_usd_borrow_fee}
use types.{
  Long, OpenPositionOrder, OrderDatum, PoolDatum, PositionDatum, ScriptHash,
  SettingsDatum, Short,
}
use utils.{get_lower_bound}

pub type LimitOrderRedeemer {
  CompleteLimitOrder { price: Int }
  CancelLimitOrder
}

pub type PositionMintRedeemer {
  OpenPosition { current_usd_price: Int }
  OpenLimitPosition { current_usd_price: Int }
  ClosePosition { burn_amount: Int }
}

// Create positions and send to orders script
// Can create limit orders and send to orders script once the limit order price is reached
validator positions_mint(orders_script_hash: ScriptHash) {
  spend(
    datum: Option<PositionDatum>,
    redeemer: LimitOrderRedeemer,
    _own_ref: OutputReference,
    transaction: Transaction,
  ) {
    todo
  }

  mint(
    redeemer: PositionMintRedeemer,
    policy_id: PolicyId,
    transaction: Transaction,
  ) {
    when redeemer is {
      OpenPosition(current_usd_price) ->
        mint_position_valid(
          transaction: transaction,
          orders_script_hash: orders_script_hash,
          current_usd_price: current_usd_price,
          policy_id: policy_id,
        )
      OpenLimitPosition(current_usd_price) ->
        mint_position_valid(
          transaction: transaction,
          orders_script_hash: orders_script_hash,
          current_usd_price: current_usd_price,
          policy_id: policy_id,
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
) {
  let Transaction { mint, reference_inputs, .. } = transaction

  let outputs_to_orders_address: List<Output> =
    find_script_outputs(transaction.outputs, orders_script_hash)

  expect list.length(outputs_to_orders_address) == 1

  expect Some(output_to_orders_validator) = list.head(outputs_to_orders_address)

  expect InlineDatum(orders_datum) = output_to_orders_validator.datum

  expect orders_datum_typed: OrderDatum = orders_datum

  expect OpenPositionOrder{position_datum: PositionDatum {
    entered_position_time,
    entered_at_usd_price,
    position_asset_amount,
    hourly_usd_borrow_fee,
    collateral_asset,
    side,
    ..
  }} = orders_datum_typed.action

  expect Some(Input {
    output: Output { value: pool_value, datum: pool_datum, .. },
    ..
  }) = list.head(reference_inputs)

  expect InlineDatum(pool_datum) = pool_datum
  expect pool_datum_typed: PoolDatum = pool_datum

  let PoolDatum {
    underlying_asset,
    long_total_asset_amount,
    short_total_asset_amount,
    long_available_asset_amount,
    short_available_asset_amount,
    ..
  } = pool_datum_typed

  expect Some(Input { output: Output { datum: global_settings_datum, .. }, .. }) =
    list.at(reference_inputs, 1)

  expect InlineDatum(global_settings_datum) = global_settings_datum
  expect global_settings_datum_typed: SettingsDatum = global_settings_datum

  let SettingsDatum {
    interest_rate,
    max_leverage_factor,
    max_strike_holder_leverage_factor,
    ..
  } = global_settings_datum_typed

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

  let underlying_asset_lended_amount =
    when side is {
      Long -> long_total_asset_amount - long_available_asset_amount
      Short -> short_total_asset_amount - short_available_asset_amount
    }

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
