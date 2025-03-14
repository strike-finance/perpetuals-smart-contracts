use aiken/collection/list
use aiken/math/rational
use cardano/assets.{PolicyId, Value, flatten, match, quantity_of}
use cardano/transaction.{
  InlineDatum, Input, Output, Transaction, find_script_outputs,
}
use constants.{batcher_fee, strike_asset_name, strike_policy_id}
use types.{
  Asset, ClosePositionOrder, CloseSendAmount, CloseType, LiquidateClose,
  LiquidatePositionOrder, Long, OpenPositionOrder, OrderDatum, POSIXTime,
  PoolDatum, PositionDatum, PositionSide, PositionsParams, StopLossClose,
  TakeProfitClose, TraderClose,
}
use utils.{get_address_outputs, get_all_validators_inputs, get_lower_bound}

pub fn close_position_valid(
  transaction: Transaction,
  maybe_datum: Option<PositionDatum>,
  current_usd_price: Int,
  params: PositionsParams,
  close_type: CloseType,
) -> Bool {
  expect Some(datum) = maybe_datum

  let PositionsParams { orders_script_hash, .. } = params

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
    maintain_margin_amount,
    collateral_asset,
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

  let strike_collateral_asset_amount: Int =
    quantity_of(
      input_from_script.output.value,
      strike_policy_id,
      strike_asset_name,
    )

  let accumulative_interest_fee: Int =
    calculate_accumulative_interest_fee(
      current_time,
      entered_position_time,
      hourly_usd_borrow_fee,
    )

  if close_type == TraderClose {
    let signed_by_owner: Bool =
      list.has(transaction.extra_signatories, datum.owner_address_hash)

    let return_amount =
      calculate_return(
        position_asset_amount,
        collateral_asset_amount,
        entered_at_usd_price,
        current_usd_price,
        strike_collateral_asset_amount,
        side,
        accumulative_interest_fee,
      )

    let expected_order_datum =
      OrderDatum {
        action: ClosePositionOrder {
          return_amount,
          position_datum: PositionDatum {
            owner_address_hash,
            leverage_factor,
            entered_position_time,
            entered_at_usd_price,
            position_hash,
            position_asset_amount,
            maintain_margin_amount,
            hourly_usd_borrow_fee,
            collateral_asset,
            stop_loss_usd_price,
            take_profit_usd_price,
            side,
          },
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
        strike_collateral_asset_amount,
        side,
        accumulative_interest_fee,
      )

    let expected_order_datum =
      OrderDatum {
        action: ClosePositionOrder {
          return_amount,
          position_datum: PositionDatum {
            owner_address_hash,
            leverage_factor,
            entered_position_time,
            entered_at_usd_price,
            position_hash,
            position_asset_amount,
            maintain_margin_amount,
            hourly_usd_borrow_fee,
            collateral_asset,
            stop_loss_usd_price,
            take_profit_usd_price,
            side,
          },
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
        strike_collateral_asset_amount,
        side,
        accumulative_interest_fee,
      )

    let expected_order_datum =
      OrderDatum {
        action: ClosePositionOrder {
          return_amount,
          position_datum: PositionDatum {
            owner_address_hash,
            leverage_factor,
            entered_position_time,
            entered_at_usd_price,
            position_hash,
            position_asset_amount,
            maintain_margin_amount,
            hourly_usd_borrow_fee,
            collateral_asset,
            stop_loss_usd_price,
            take_profit_usd_price,
            side,
          },
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
          owner_address_hash,
          position_asset_amount,
          leverage_factor,
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
        maintain_margin_amount,
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

// assets are not consumed, user signed transaction, only stop lose or take profit is updated 
pub fn update_position_valid(
  transaction: Transaction,
  maybe_datum: Option<PositionDatum>,
  new_stop_loss: Int,
  new_take_profit: Int,
) -> Bool {
  expect Some(datum) = maybe_datum

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
      ..datum,
      stop_loss_usd_price: new_stop_loss,
      take_profit_usd_price: new_take_profit,
    }

  let expected_output_datum_data: Data = expected_output_datum

  only_one_input_from_script && assets_locked_valid && expected_output_datum_data == output_datum
}

pub fn mint_position_valid(
  transaction: Transaction,
  params: PositionsParams,
  current_usd_price: Int,
  policy_id: PolicyId,
) {
  let PositionsParams { orders_script_hash, .. } = params

  let Transaction { mint, .. } = transaction

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
    ..
  }} = orders_datum_typed.action

  let ref_input: List<Input> = transaction.reference_inputs

  expect Some(Input {
    output: Output { value: pool_value, datum: pool_datum, .. },
    ..
  }) = list.head(ref_input)

  expect InlineDatum(pool_datum) = pool_datum
  expect pool_datum_typed: PoolDatum = pool_datum

  let PoolDatum {
    max_strike_holder_leverage_factor,
    max_leverage_factor,
    underlying_asset_lended_amount,
    interest_rate,
    underlying_asset,
    ..
  } = pool_datum_typed

  expect current_usd_price == entered_at_usd_price

  expect [(policy_id, params.asset_name, 1)] == flatten(mint)

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
        |> assets.add(policy_id, params.asset_name, 1)
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
        |> assets.add(policy_id, params.asset_name, 1)
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

  let position_max_leverage_factor =
    get_position_max_leverage_factor(
      max_leverage_factor,
      max_strike_holder_leverage_factor,
      contains_strike_collateral,
    )

  is_position_assets_amount_valid(
    position_asset_amount,
    position_max_leverage_factor,
    collateral_asset_amount,
  )
}

pub fn rebalance_position_valid() -> Bool {
  True
}

pub fn increase_position_from_profit_valid() -> Bool {
  True
}

// make sure the amount of position_asset_amount is less than the collateral asset amount * leverage factor
// for strike holders, they have a different leverage factor
pub fn is_position_assets_amount_valid(
  position_asset_amount: Int,
  max_leverage_factor: Int,
  collateral_asset_amount: Int,
) -> Bool {
  // If the underlying asset is the collateral asset, so we can simply divide by the leverage factor and compare the two values
  position_asset_amount / max_leverage_factor <= collateral_asset_amount
}

// Only add asset amount is changed
// Collateral asset needs to be the same in the datum 
// No assets has been consumed
pub fn add_collateral_valid(
  transaction: Transaction,
  maybe_datum: Option<PositionDatum>,
) -> Bool {
  expect Some(datum) = maybe_datum

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

  let input_datum_data: Data = datum
  let output_datum_data: Data = output_datum

  let datum_not_changed: Bool = input_datum_data == output_datum_data

  datum_not_changed && only_one_input_from_script && assets_locked_valid
}

fn get_position_max_leverage_factor(
  max_leverage_factor: Int,
  max_strike_holder_leverage_factor: Int,
  contains_strike_collateral: Bool,
) -> Int {
  if contains_strike_collateral {
    max_strike_holder_leverage_factor
  } else {
    max_leverage_factor
  }
}

fn price_reached_stop_loss(current_usd_price: Int, datum: PositionDatum) -> Bool {
  if datum.side == Long {
    current_usd_price <= datum.stop_loss_usd_price
  } else {
    current_usd_price >= datum.stop_loss_usd_price
  }
}

fn price_reached_take_profit(
  current_usd_price: Int,
  datum: PositionDatum,
) -> Bool {
  if datum.side == Long {
    current_usd_price >= datum.take_profit_usd_price
  } else {
    current_usd_price <= datum.take_profit_usd_price
  }
}

//TODO: CLEANER
// the loss is their inital position value minus the current position value  
// the collateral value is their inital collateral value minus the interest fee
// any loss is subtracted from the collateral value
// the current margin is the collateral value divided by the current position value
// if the current margin is less than the margin requirement, the liquidation price is reached
pub fn reach_liquidation_price(
  side: PositionSide,
  position_amount: Int,
  current_usd_price: Int,
  entered_at_usd_price: Int,
  maintain_margin_amount: Int,
  collateral_amount: Int,
  entered_position_time: POSIXTime,
  hourly_borrow_fee: Int,
  current_time: POSIXTime,
) -> Bool {
  let accumulative_interest_fee: Int =
    calculate_accumulative_interest_fee(
      current_time,
      entered_position_time,
      hourly_borrow_fee,
    )

  let total_value_loss =
    calculate_position_usd_value_based_on_side(
      side,
      position_amount,
      current_usd_price,
      entered_at_usd_price,
      accumulative_interest_fee,
    )

  let current_position_value: Int = position_amount * current_usd_price

  // if positive that means this is in profit and return false 
  if total_value_loss >= 0 {
    False
  } else {
    // Calculate maintain margin has not been meet by comparing the collateral value and amount of loss
    // The collateral value/current_position_value must be within the maintain margin amount
    let collateral_value: Int = collateral_amount * current_usd_price

    let collateral_value_after_loss: Int = collateral_value - total_value_loss

    let current_margin: Int =
      collateral_value_after_loss / current_position_value

    current_margin <= maintain_margin_amount
  }
}

pub fn calculate_position_usd_value_based_on_side(
  side: PositionSide,
  position_amount: Int,
  current_usd_price: Int,
  entered_at_usd_price: Int,
  accumulative_interest_fee: Int,
) -> Int {
  let inital_position_usd_value: Int = position_amount * entered_at_usd_price

  let current_position_value: Int = position_amount * current_usd_price

  if side == Long {
    current_position_value - inital_position_usd_value - accumulative_interest_fee
  } else {
    inital_position_usd_value - current_position_value - accumulative_interest_fee
  }
}

//Only charge for every full hour that has passed, if 1 hour and 1 second has passed, still only charge for 1 hour
pub fn calculate_accumulative_interest_fee(
  current_time: POSIXTime,
  entered_position_time: POSIXTime,
  hourly_borrow_usd_fee: Int,
) -> Int {
  expect Some(divided) =
    rational.new(current_time - entered_position_time, 3_600_000)

  rational.floor(divided) * hourly_borrow_usd_fee
}

// Utilization factor is the ratio of the underlying asset amount to the underlying asset lended amount
// First multiply the underlying asset lended amount so we can divide it by the pool's underlying asset amount to get the utilization percentage
// Then multiply the current position usd value by the utilization percentage and interest rate to get the fee
// Then divide by 100 becausse the interest rate is an int, and 10_000 because we used it to get the utilization percentage
pub fn calculate_hourly_usd_borrow_fee(
  position_asset_amount: Int,
  underlying_asset_lended_amount: Int,
  current_usd_price: Int,
  pool_underlying_asset_amount: Int,
  interest_rate: Int,
) -> Int {
  let underlying_asset_lended_amount_multiplier =
    underlying_asset_lended_amount * 10_000

  let utilization_percentage =
    underlying_asset_lended_amount_multiplier / pool_underlying_asset_amount

  let current_position_usd_value = position_asset_amount * current_usd_price

  utilization_percentage * interest_rate * current_position_usd_value / 100 / 10_000
}

// TODO:CLEANER
pub fn calculate_return(
  position_amount: Int,
  collateral_asset_amount: Int,
  entered_at_usd_price: Int,
  current_usd_price: Int,
  strike_collateral_amount: Int,
  side: PositionSide,
  accumulative_interest_fee: Int,
) -> CloseSendAmount {
  let position_usd_value =
    calculate_position_usd_value_based_on_side(
      side,
      position_amount,
      current_usd_price,
      entered_at_usd_price,
      accumulative_interest_fee,
    )

  let collateral_value: Int = collateral_asset_amount * current_usd_price

  let send_asset_amount =
    ( collateral_value + position_usd_value ) / current_usd_price

  let return_pool_asset_amount = position_usd_value / current_usd_price * -1

  CloseSendAmount {
    send_asset_amount,
    return_pool_asset_amount,
    strike_collateral_amount,
  }
}
