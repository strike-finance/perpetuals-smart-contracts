use aiken/collection/list
use aiken/math/rational
use cardano/assets.{PolicyId, Value, flatten, match, quantity_of}
use cardano/transaction.{
  InlineDatum, Input, Output, Transaction, find_script_outputs,
}
use constants.{batcher_fee,
  lovelace_amount, strike_asset_name, strike_policy_id}
use types.{
  Asset, ClosePositionOrder, CloseSendAmount, CloseType, LiquidateClose,
  LiquidatePositionOrder, Long, LongCloseOrder, OpenPositionOrder, OrderDatum,
  POSIXTime, PoolDatum, PositionDatum, PositionSide, PositionsParams,
  ShortCloseOrder, StopLossClose, TakeProfitClose, TraderClose,
}
use utils.{
  divide, get_address_outputs, get_all_validators_inputs, get_collateral_asset,
  get_lower_bound, policy_in_value, to_ada_if_lovelace,
}

pub fn close_position_valid(
  transaction: Transaction,
  datum: Option<PositionDatum>,
  current_usd_price: Int,
  orders_script_hash: ByteArray,
  close_type: CloseType,
) -> Bool {
  expect Some(datum) = datum

  let PositionDatum {
    owner_address_hash,
    position_asset_amount,
    leverage_factor,
    entered_at_usd_price,
    stop_loss_usd_price,
    take_profit_usd_price,
    entered_position_time,
    side,
    position_hash,
    hourly_usd_borrow_fee,
    collateral_asset,
    maintain_margin_amount,
  } = datum

  let all_validators_inputs: List<Input> =
    get_all_validators_inputs(transaction)
  let only_one_input_from_script: Bool = list.length(all_validators_inputs) == 1

  expect Some(input_from_script) = list.head(all_validators_inputs)

  let outputs_to_orders_validator: List<Output> =
    find_script_outputs(transaction.outputs, orders_script_hash)

  expect Some(output_to_orders_validator) =
    list.head(outputs_to_orders_validator)

  expect InlineDatum(orders_datum) = output_to_orders_validator.datum

  let assets_match: Bool =
    match(output_to_orders_validator.value, input_from_script.output.value, >=)

  expect assets_match && only_one_input_from_script

  let collateral_asset_amount: Int =
    quantity_of(
      input_from_script.output.value,
      collateral_asset.policy_id,
      collateral_asset.asset_name,
    )

  let current_time: POSIXTime = get_lower_bound(transaction.validity_range)

  if close_type == TraderClose {
    let signed_by_owner: Bool =
      list.has(transaction.extra_signatories, datum.owner_address_hash)

    let return_amount =
      calculate_return(
        position_asset_amount,
        collateral_asset_amount,
        entered_at_usd_price,
        current_usd_price,
        current_time,
        entered_position_time,
        hourly_usd_borrow_fee,
        side,
      )

    let expected_order_datum =
      OrderDatum {
        action: ClosePositionOrder {
          owner_address_hash,
          order_submission_usd_price: current_usd_price,
          leverage_factor,
          entered_at_usd_price,
          stop_loss_usd_price,
          take_profit_usd_price,
          entered_position_time,
          position_hash,
          position_asset_amount,
          maintain_margin_amount,
          hourly_usd_borrow_fee,
          return_amount,
          side,
        },
      }

    let expected_order_datum_data: Data = expected_order_datum

    let orders_datum_valid: Bool = expected_order_datum_data == orders_datum

    signed_by_owner && orders_datum_valid
  } else if close_type == StopLossClose {
    let return_amount =
      calculate_return(
        position_asset_amount,
        collateral_asset_amount,
        entered_at_usd_price,
        current_usd_price,
        current_time,
        entered_position_time,
        hourly_usd_borrow_fee,
        side,
      )

    let expected_order_datum =
      OrderDatum {
        action: ClosePositionOrder {
          owner_address_hash,
          order_submission_usd_price: current_usd_price,
          leverage_factor,
          entered_at_usd_price,
          stop_loss_usd_price,
          take_profit_usd_price,
          entered_position_time,
          position_hash,
          position_asset_amount,
          margin_requirement,
          hourly_usd_borrow_fee,
          return_amount,
          side,
        },
      }

    let expected_order_datum_data: Data = expected_order_datum

    let orders_datum_valid: Bool = expected_order_datum_data == orders_datum

    let stop_loss_reached: Bool =
      price_reached_stop_loss(current_usd_price, datum)

    stop_loss_reached && orders_datum_valid
  } else if close_type == TakeProfitClose {
    let return_amount =
      calculate_return(
        position_asset_amount,
        collateral_asset_amount,
        entered_at_usd_price,
        current_usd_price,
        current_time,
        entered_position_time,
        hourly_usd_borrow_fee,
        side,
      )

    let expected_order_datum =
      OrderDatum {
        action: ClosePositionOrder {
          owner_address_hash,
          order_submission_usd_price: current_usd_price,
          leverage_factor,
          entered_at_usd_price,
          stop_loss_usd_price,
          take_profit_usd_price,
          entered_position_time,
          position_hash,
          position_asset_amount,
          margin_requirement,
          hourly_usd_borrow_fee,
          return_amount,
          side,
        },
      }

    let expected_order_datum_data: Data = expected_order_datum

    let orders_datum_valid: Bool = expected_order_datum_data == orders_datum

    let take_profit_reached: Bool =
      price_reached_take_profit(current_usd_price, datum)

    take_profit_reached && orders_datum_valid
  } else if close_type == LiquidateClose {
    let expected_order_datum =
      OrderDatum {
        action: LiquidatePositionOrder {
          position_hash,
          side,
          owner_address_hash,
        },
      }

    let expected_order_datum_data: Data = expected_order_datum

    let orders_datum_valid: Bool = expected_order_datum_data == orders_datum

    let current_time: POSIXTime = get_lower_bound(transaction.validity_range)

    let liquidate_reached: Bool =
      reach_liquidation_price(
        side,
        position_asset_amount,
        current_usd_price,
        entered_at_usd_price,
        margin_requirement,
        collateral_asset_amount,
        entered_position_time,
        hourly_usd_borrow_fee,
        current_time,
      )

    orders_datum_valid && liquidate_reached
  } else {
    False
  }
}

// assets are not consumed, user signed transaction, only stop lose is updated 
pub fn update_stop_loss_valid(
  transaction: Transaction,
  maybe_datum: Option<PositionDatum>,
  stop_loss_usd_price: Int,
) -> Bool {
  expect Some(datum) = maybe_datum

  let PositionDatum {
    position_hash,
    collateral_asset,
    position_asset_amount,
    owner_address_hash,
    entered_at_usd_price,
    leverage_factor,
    take_profit_usd_price,
    entered_position_time,
    side,
    margin_requirement,
    hourly_usd_borrow_fee,
    ..
  } = datum

  let all_validators_inputs: List<Input> =
    get_all_validators_inputs(transaction)
  let only_one_input_from_script: Bool = list.length(all_validators_inputs) == 1

  expect Some(input_from_script) = list.head(all_validators_inputs)

  let outputs_back_to_positions_validator: List<Output> =
    get_address_outputs(transaction, input_from_script.output.address)

  expect Some(output_to_positions_validator) =
    list.head(outputs_back_to_positions_validator)

  expect InlineDatum(output_datum) = output_to_positions_validator.datum

  let assets_locked_valid: Bool =
    match(
      output_to_positions_validator.value,
      input_from_script.output.value,
      >=,
    )

  let expected_output_datum =
    PositionDatum {
      owner_address_hash,
      position_hash,
      entered_at_usd_price,
      leverage_factor,
      position_asset_amount,
      collateral_asset,
      stop_loss_usd_price,
      take_profit_usd_price,
      entered_position_time,
      margin_requirement,
      hourly_usd_borrow_fee,
      side,
    }

  let expected_output_datum_data: Data = expected_output_datum

  let output_datum_valid: Bool = expected_output_datum_data == output_datum

  only_one_input_from_script && output_datum_valid && assets_locked_valid
}

// assets are not consumed, user signed transaction, only stop lose is updated 
pub fn update_take_profit_valid(
  transaction: Transaction,
  maybe_datum: Option<PositionDatum>,
  take_profit_usd_price: Int,
) -> Bool {
  expect Some(datum) = maybe_datum

  let PositionDatum {
    owner_address_hash,
    position_hash,
    entered_at_usd_price,
    leverage_factor,
    stop_loss_usd_price,
    position_asset_amount,
    entered_position_time,
    margin_requirement,
    side,
    hourly_usd_borrow_fee,
    collateral_asset,
    ..
  } = datum

  let all_validators_inputs: List<Input> =
    get_all_validators_inputs(transaction)
  let only_one_input_from_script: Bool = list.length(all_validators_inputs) == 1

  expect Some(input_from_script) = list.head(all_validators_inputs)

  let outputs_back_to_positions_validator: List<Output> =
    get_address_outputs(transaction, input_from_script.output.address)
  let only_one_output_to_positions_validator: Bool =
    list.length(outputs_back_to_positions_validator) == 1

  expect Some(output_to_positions_validator) =
    list.head(outputs_back_to_positions_validator)

  expect InlineDatum(output_datum) = output_to_positions_validator.datum

  let assets_locked_valid: Bool =
    match(
      output_to_positions_validator.value,
      input_from_script.output.value,
      >=,
    )

  let expected_output_datum =
    PositionDatum {
      owner_address_hash,
      position_hash,
      entered_at_usd_price,
      leverage_factor,
      position_asset_amount,
      collateral_asset,
      stop_loss_usd_price,
      take_profit_usd_price,
      entered_position_time,
      margin_requirement,
      hourly_usd_borrow_fee,
      side,
    }

  let expected_output_datum_data: Data = expected_output_datum

  let output_datum_valid: Bool = expected_output_datum_data == output_datum

  only_one_input_from_script && only_one_output_to_positions_validator && output_datum_valid && assets_locked_valid
}

pub fn mint_position_valid(
  transaction: Transaction,
  params: PositionsParams,
  current_usd_price: Int,
  policy_id: PolicyId,
  pool_license: PolicyId,
) {
  let Transaction { mint, .. } = transaction

  let outputs_to_orders_address: List<Output> =
    find_script_outputs(transaction.outputs, params.orders_script_hash)

  expect list.length(outputs_to_orders_address) == 1

  expect Some(output_to_orders_validator) = list.head(outputs_to_orders_address)

  expect InlineDatum(orders_datum) = output_to_orders_validator.datum

  expect orders_datum_typed: OrderDatum = orders_datum

  expect OpenPositionOrder {
    owner_address_hash,
    leverage_factor,
    side,
    order_submission_time,
    order_submission_usd_price,
    position_asset_amount,
    position_hash,
    hourly_usd_borrow_fee,
    ..
  } = orders_datum_typed.action

  let ref_input: List<Input> = transaction.reference_inputs

  expect Some(Input {
    output: Output { value: batcher_value, datum: pool_ref_datum, .. },
    ..
  }) = list.head(ref_input)

  expect InlineDatum(pool_ref_datum) = pool_ref_datum
  expect pool_ref_datum_typed: PoolDatum = pool_ref_datum

  let PoolDatum { stable_asset, underlying_asset, .. } = pool_ref_datum_typed

  let collateral_asset: Asset =
    get_collateral_asset(
      underlying_asset.policy_id,
      underlying_asset.asset_name,
      stable_asset.policy_id,
      stable_asset.asset_name,
      side,
    )

  expect current_usd_price == order_submission_usd_price

  let expected_mint = [(policy_id, owner_address_hash, 1)]

  expect expected_mint == flatten(mint)

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

  if collateral_asset.policy_id == "" {
    let expected_assets_locked: Value =
      assets.from_lovelace(batcher_fee)
        |> assets.add(policy_id, owner_address_hash, 1)
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
        |> assets.add(policy_id, owner_address_hash, 1)
        |> assets.add(
            collateral_asset.policy_id,
            collateral_asset.asset_name,
            collateral_asset_amount,
          )
        |> assets.add(strike_policy_id, strike_asset_name, strike_asset_amount)

    expect match(output_to_orders_validator.value, expected_assets_locked, >=)
  }

  let estimated_hourly_usd_borrow_fee: Int =
    calculate_pay_borrow(
      position_asset_amount,
      pool_ref_datum_typed,
      current_usd_price,
      pool_ref_datum_typed.underlying_asset,
    )

  expect hourly_usd_borrow_fee >= estimated_hourly_usd_borrow_fee

  expect get_lower_bound(transaction.validity_range) >= order_submission_time

  expect policy_id == position_hash && owner_address_hash == owner_address_hash

  expect list.has(transaction.extra_signatories, owner_address_hash)

  let pool_license_in_transaction: Bool =
    policy_in_value(pool_license, batcher_value)

  let minted_assets_amount_valid: Bool =
    is_position_assets_amount_valid(
      side,
      position_asset_amount,
      leverage_factor,
      collateral_asset_amount,
      pool_ref_datum_typed.underlying_asset,
      current_usd_price,
    )

  expect minted_assets_amount_valid && pool_license_in_transaction

  let contains_strike_collateral: Bool =
    quantity_of(
      output_to_orders_validator.value,
      strike_policy_id,
      strike_asset_name,
    ) > 0

  if contains_strike_collateral {
    pool_ref_datum_typed.max_strike_holder_leverage_factor >= leverage_factor
  } else {
    pool_ref_datum_typed.max_leverage_factor >= leverage_factor
  }
}
