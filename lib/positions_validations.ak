use aiken/collection/list
use aiken/math/rational
use cardano/assets.{PolicyId, Value, flatten, match, quantity_of}
use cardano/transaction.{
  InlineDatum, Input, Output, Transaction, find_script_outputs,
}
use constants.{batcher_fee, strike_asset_name, strike_policy_id, usd_multiplier}
use types.{
  Asset, ClosePositionOrder, CloseSendAmount, CloseType, LiquidateClose,
  LiquidatePositionOrder, Long, LongCloseOrder, OpenPositionOrder, OrderDatum,
  POSIXTime, PoolDatum, PositionDatum, PositionSide, PositionsParams,
  ShortCloseOrder, StopLossClose, TakeProfitClose, TraderClose,
}
use utils.{
  divide, get_address_outputs, get_all_validators_inputs, get_collateral_asset,
  get_lower_bound,
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
          maintain_margin_amount,
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
          maintain_margin_amount,
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
    maintain_margin_amount,
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
      maintain_margin_amount,
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
    maintain_margin_amount,
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
      maintain_margin_amount,
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
    hourly_usd_borrow_fee,
    ..
  } = orders_datum_typed.action

  let ref_input: List<Input> = transaction.reference_inputs

  expect Some(Input {
    output: Output { value: pool_value, datum: pool_datum, .. },
    ..
  }) = list.head(ref_input)

  expect InlineDatum(pool_datum) = pool_datum
  expect pool_datum_typed: PoolDatum = pool_datum

  let PoolDatum {
    underlying_asset,
    stable_asset,
    max_strike_holder_leverage_factor,
    max_leverage_factor,
    underlying_asset_lended_amount,
    interest_rate,
    ..
  } = pool_datum_typed

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

  // check if lovelace, and subtract collateral_asset_amount with batcher fee, or else it gets counted twice
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

  let collateral_asset: Asset =
    get_collateral_asset(
      underlying_asset.policy_id,
      underlying_asset.asset_name,
      stable_asset.policy_id,
      stable_asset.asset_name,
      side,
    )

  let underlying_asset_amount =
    quantity_of(
      pool_value,
      collateral_asset.policy_id,
      collateral_asset.asset_name,
    )

  let estimated_hourly_usd_borrow_fee: Int =
    calculate_hourly_usd_borrow_fee(
      position_asset_amount,
      underlying_asset_lended_amount,
      current_usd_price,
      underlying_asset_amount,
      interest_rate,
    )

  let hourly_usd_borrow_fee_valid =
    hourly_usd_borrow_fee >= estimated_hourly_usd_borrow_fee

  let order_submission_time_valid =
    get_lower_bound(transaction.validity_range) >= order_submission_time

  let owner_signed_tx =
    list.has(transaction.extra_signatories, owner_address_hash)

  let minted_assets_amount_valid: Bool =
    is_position_assets_amount_valid(
      side,
      position_asset_amount,
      leverage_factor,
      collateral_asset_amount,
      current_usd_price,
    )

  expect
    minted_assets_amount_valid && hourly_usd_borrow_fee_valid && order_submission_time_valid && owner_signed_tx

  let contains_strike_collateral: Bool =
    quantity_of(
      output_to_orders_validator.value,
      strike_policy_id,
      strike_asset_name,
    ) > 0

  if contains_strike_collateral {
    max_strike_holder_leverage_factor >= leverage_factor
  } else {
    max_leverage_factor >= leverage_factor
  }
}

// make sure the amount of position_asset_amount is atleast the collateral asset amount * leverage factor
// For long position, simply divide by the leverage factor since the collateral is in the same asset as the underlying asset
// For short position, divide by the leverage factor and then by multiply it by the current usd price to get the expected stable asset amount
fn is_position_assets_amount_valid(
  position_side: PositionSide,
  position_asset_amount: Int,
  leverage_factor: Int,
  collateral_asset_amount: Int,
  current_usd_price: Int,
) -> Bool {
  if position_side == Long {
    position_asset_amount / leverage_factor <= collateral_asset_amount
  } else {
    let collateral_in_asset_term: Int = position_asset_amount / leverage_factor

    let stable_amount_expected: Int =
      collateral_in_asset_term * current_usd_price

    stable_amount_expected <= collateral_asset_amount
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

// the loss is their inital position value minus the current position value  
// the collateral value is their inital collateral value minus the interest fee
// any loss is subtracted from the collateral value
// the current margin is the collateral value divided by the current position value
// if the current margin is less than the margin requirement, the liquidation price is reached
fn reach_liquidation_price(
  side: PositionSide,
  position_amount: Int,
  current_usd_price: Int,
  entered_at_usd_price: Int,
  maintain_margin_amount: Int,
  collateral_asset_amount: Int,
  entered_position_time: POSIXTime,
  hourly_borrow_fee: Int,
  current_time: POSIXTime,
) -> Bool {
  if side == Long {
    let inital_position_usd_value: Int = position_amount * entered_at_usd_price

    let current_position_value: Int = position_amount * current_usd_price

    let total_value_loss: Int =
      inital_position_usd_value - current_position_value

    let accumulative_interest_fee: Int =
      calculate_accumulative_interest_fee(
        current_time,
        entered_position_time,
        hourly_borrow_fee,
      )

    let inital_collateral_value: Int =
      collateral_asset_amount * entered_at_usd_price

    let collateral_value_after_interest: Int =
      inital_collateral_value - accumulative_interest_fee

    let collateral_value_after_loss: Int =
      collateral_value_after_interest - total_value_loss

    let current_margin: Int =
      divide(collateral_value_after_loss, current_position_value)

    current_margin <= maintain_margin_amount
  } else {
    let inital_position_usd_value: Int = position_amount * entered_at_usd_price

    let current_position_value: Int = position_amount * current_usd_price

    let total_value_loss: Int =
      inital_position_usd_value - current_position_value

    let accumulative_interest_fee: Int =
      calculate_accumulative_interest_fee(
        current_time,
        entered_position_time,
        hourly_borrow_fee,
      )

    let collateral_value_after_interest: Int =
      collateral_asset_amount - accumulative_interest_fee

    let collateral_value_after_loss: Int =
      collateral_value_after_interest - total_value_loss

    let current_margin: Int =
      divide(collateral_value_after_loss, current_position_value)

    current_margin <= maintain_margin_amount
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
// To get the utilization percentage, divide 100 by the utilization factor, EX: 100 / 10 = 10%
// Divide by 100 in the end to account for interest rate being a int instead of a float
pub fn calculate_hourly_usd_borrow_fee(
  position_asset_amount: Int,
  underlying_asset_lended_amount: Int,
  current_usd_price: Int,
  underlying_asset_amount: Int,
  interest_rate: Int,
) -> Int {
  let utilization_factor =
    underlying_asset_amount / underlying_asset_lended_amount

  let utilization_percentage = 100 / utilization_factor

  let current_position_usd_value = position_asset_amount * current_usd_price

  let fee =
    utilization_percentage * interest_rate * current_position_usd_value / 100

  if fee < usd_multiplier {
    usd_multiplier
  } else {
    fee
  }
}

pub fn calculate_return(
  position_amount: Int,
  collateral_amount: Int,
  entered_at_usd_price: Int,
  current_usd_price: Int,
  current_time: POSIXTime,
  entered_position_time: POSIXTime,
  hourly_borrow_fee: Int,
  side: PositionSide,
) -> CloseSendAmount {
  if side == Long {
    // Simply calculate the profit or loss and add it to the collateral amount since the collateral is in the same asset as the underlying asset for longs
    let current_position_usd_value: Int = position_amount * current_usd_price

    let inital_position_usd_value: Int = position_amount * entered_at_usd_price

    let position_usd_value: Int =
      current_position_usd_value - inital_position_usd_value

    let accumulative_interest_fee: Int =
      calculate_accumulative_interest_fee(
        current_time,
        entered_position_time,
        hourly_borrow_fee,
      )

    let collateral_value: Int = collateral_amount * current_usd_price

    let asset_amount =
      ( collateral_value + position_usd_value - accumulative_interest_fee ) / current_usd_price

    LongCloseOrder { asset_amount }
  } else {
    // first calculate if there is a profit or loss
    // If there is a profit, subtract the interest fee from the profit and return the profit + the full collateral amount
    // If there is a loss, subtract the interest fee from the collateral amount, the collateral is a stable coin for short positions
    let current_position_value: Int = position_amount * current_usd_price

    let inital_position_usd_value: Int = position_amount * entered_at_usd_price

    let total_value: Int = inital_position_usd_value - current_position_value

    let accumulative_interest_fee: Int =
      calculate_accumulative_interest_fee(
        current_time,
        entered_position_time,
        hourly_borrow_fee,
      )

    let collateral_value: Int = collateral_amount * current_usd_price

    if total_value > 0 {
      let asset_amount: Int =
        ( total_value - accumulative_interest_fee ) / current_usd_price

      ShortCloseOrder { asset_amount, collateral_amount }
    } else {
      let collateral_amount_after_interest: Int =
        collateral_value - accumulative_interest_fee

      let collateral_amount_after_loss: Int =
        collateral_amount_after_interest - total_value

      ShortCloseOrder {
        asset_amount: 0,
        collateral_amount: collateral_amount_after_loss,
      }
    }
  }
}
