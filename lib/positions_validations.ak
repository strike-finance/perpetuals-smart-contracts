use aiken/collection/list
use aiken/math/rational
use cardano/assets.{PolicyId, Value, flatten, match, quantity_of}
use cardano/transaction.{
  InlineDatum, Input, Output, Transaction, find_script_outputs,
}
use constants.{batcher_fee, strike_asset_name, strike_policy_id, usd_multiplier}
use types.{
  Asset, AssetType, ClosePositionOrder, CloseSendAmount, CloseType,
  LiquidateClose, LiquidatePositionOrder, Long, OpenAsset, OpenPositionOrder,
  OrderDatum, POSIXTime, PoolDatum, PositionDatum, PositionDatumInfo,
  PositionSide, PositionUpdateType, PositionsParams, StopLossClose,
  TakeProfitClose, TraderClose, UnderlyingAsset, UpdateStopLoss,
}
use utils.{
  get_address_outputs, get_all_validators_inputs, get_asset_type,
  get_lower_bound,
}

pub fn close_position_valid(
  transaction: Transaction,
  datum: Option<PositionDatum>,
  current_usd_price: Int,
  params: PositionsParams,
  close_type: CloseType,
  close_asset_type: AssetType,
) -> Bool {
  expect Some(datum) = datum

  let PositionsParams {
    orders_script_hash,
    underlying_asset_multiplier,
    stable_asset_multiplier,
  } = params

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
    collateral_asset_type,
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

  let collateral_amount: Int =
    quantity_of(
      input_from_script.output.value,
      collateral_asset.policy_id,
      collateral_asset.asset_name,
    )

  if close_type == TraderClose {
    let signed_by_owner: Bool =
      list.has(transaction.extra_signatories, datum.owner_address_hash)

    let return_amount =
      calculate_return(
        position_asset_amount,
        underlying_asset_multiplier,
        collateral_asset_amount,
        stable_asset_multiplier,
        entered_at_usd_price,
        current_usd_price,
        strike_collateral_asset_amount,
        side,
        close_asset_type,
        accumulative_interest_fee,
        collateral_asset_type,
        collateral_amount,
      )

    let expected_order_datum =
      OrderDatum {
        action: ClosePositionOrder {
          stop_loss_usd_price,
          take_profit_usd_price,
          return_amount,
          position_datum: PositionDatumInfo {
            owner_address_hash,
            leverage_factor,
            entered_position_time,
            entered_at_usd_price,
            position_hash,
            position_asset_amount,
            maintain_margin_amount,
            hourly_usd_borrow_fee,
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
        underlying_asset_multiplier,
        collateral_asset_amount,
        stable_asset_multiplier,
        entered_at_usd_price,
        current_usd_price,
        strike_collateral_asset_amount,
        side,
        close_asset_type,
        accumulative_interest_fee,
        collateral_asset_type,
        collateral_amount,
      )

    let expected_order_datum =
      OrderDatum {
        action: ClosePositionOrder {
          stop_loss_usd_price,
          take_profit_usd_price,
          return_amount,
          position_datum: PositionDatumInfo {
            owner_address_hash,
            leverage_factor,
            entered_position_time,
            entered_at_usd_price,
            position_hash,
            position_asset_amount,
            maintain_margin_amount,
            hourly_usd_borrow_fee,
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
        underlying_asset_multiplier,
        collateral_asset_amount,
        stable_asset_multiplier,
        entered_at_usd_price,
        current_usd_price,
        strike_collateral_asset_amount,
        side,
        close_asset_type,
        accumulative_interest_fee,
        collateral_asset_type,
        collateral_amount,
      )

    let expected_order_datum =
      OrderDatum {
        action: ClosePositionOrder {
          stop_loss_usd_price,
          take_profit_usd_price,
          return_amount,
          position_datum: PositionDatumInfo {
            owner_address_hash,
            leverage_factor,
            entered_position_time,
            entered_at_usd_price,
            position_hash,
            position_asset_amount,
            maintain_margin_amount,
            hourly_usd_borrow_fee,
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
        underlying_asset_multiplier,
        stable_asset_multiplier,
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
  update_type: PositionUpdateType,
  update_price: Int,
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

  expect only_one_input_from_script && assets_locked_valid

  if update_type == UpdateStopLoss {
    let expected_output_datum =
      PositionDatum { ..datum, stop_loss_usd_price: update_price }

    let expected_output_datum_data: Data = expected_output_datum

    expected_output_datum_data == output_datum
  } else {
    let expected_output_datum =
      PositionDatum { ..datum, take_profit_usd_price: update_price }

    let expected_output_datum_data: Data = expected_output_datum

    expected_output_datum_data == output_datum
  }
}

pub fn mint_position_valid(
  transaction: Transaction,
  params: PositionsParams,
  current_usd_price: Int,
  policy_id: PolicyId,
  open_asset: OpenAsset,
) {
  let PositionsParams {
    orders_script_hash,
    underlying_asset_multiplier,
    stable_asset_multiplier,
  } = params

  let Transaction { mint, .. } = transaction

  let outputs_to_orders_address: List<Output> =
    find_script_outputs(transaction.outputs, orders_script_hash)

  expect list.length(outputs_to_orders_address) == 1

  expect Some(output_to_orders_validator) = list.head(outputs_to_orders_address)

  expect InlineDatum(orders_datum) = output_to_orders_validator.datum

  expect orders_datum_typed: OrderDatum = orders_datum

  expect OpenPositionOrder{position_datum: PositionDatumInfo {
    owner_address_hash,
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
    stable_asset,
    underlying_asset,
    max_strike_holder_leverage_factor,
    max_leverage_factor,
    underlying_asset_lended_amount,
    interest_rate,
    ..
  } = pool_datum_typed

  let OpenAsset { collateral_asset } = open_asset

  expect current_usd_price == entered_at_usd_price

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

  // check if lovelace, and subtract collateral_asset_amount with batcher fee, or else the batcher fee gets counted twice
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

  let pool_underlying_asset_amount =
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
      pool_underlying_asset_amount,
      interest_rate,
    )

  let hourly_usd_borrow_fee_valid =
    hourly_usd_borrow_fee >= estimated_hourly_usd_borrow_fee

  let order_submission_time_valid =
    get_lower_bound(transaction.validity_range) >= entered_position_time

  let owner_signed_tx =
    list.has(transaction.extra_signatories, owner_address_hash)

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

  let collateral_asset_type =
    get_asset_type(collateral_asset, stable_asset, underlying_asset)

  let assets_amount_valid: Bool =
    is_position_assets_amount_valid(
      collateral_asset_type,
      position_asset_amount,
      position_max_leverage_factor,
      collateral_asset_amount,
      current_usd_price,
      underlying_asset_multiplier,
      stable_asset_multiplier,
    )

  assets_amount_valid && hourly_usd_borrow_fee_valid && order_submission_time_valid && owner_signed_tx
}

// make sure the amount of position_asset_amount is less than the collateral asset amount * leverage factor
// for strike holders, they have a different leverage factor
pub fn is_position_assets_amount_valid(
  collateral_asset_type: AssetType,
  position_asset_amount: Int,
  max_leverage_factor: Int,
  collateral_asset_amount: Int,
  current_usd_price: Int,
  underlying_asset_multiplier: Int,
  stable_asset_multiplier: Int,
) -> Bool {
  if collateral_asset_type == UnderlyingAsset {
    // If the underlying asset is the collateral asset, so we can simply divide by the leverage factor and compare the two values
    position_asset_amount / max_leverage_factor <= collateral_asset_amount
  } else {
    // If the stable asset is the collateral asset, we need to convert the collateral asset amount to the same unit as the position asset amount

    // use the stable asset multiplier and underlyting asset multiplier to make it into the same unit to compare
    let collateral_position_asset_amount: Int =
      position_asset_amount / max_leverage_factor

    // get the total price after dividing by the max leverage factor, then divide by the underlying asset multiplier to get the units
    // because the posiition asset represents the total asset amount of the position, in the underlying asset
    let stable_amount_expected: Int =
      collateral_position_asset_amount * current_usd_price / underlying_asset_multiplier

    // now convert the collateral asset amount to the same unit as the stable amount expected. The usd multiplier converts 
    // the collateral asset amount to the same unit as the position asset amount
    let stable_amount: Int =
      collateral_asset_amount / stable_asset_multiplier * usd_multiplier

    stable_amount_expected <= stable_amount
  }
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
  stable_asset_multiplier: Int,
  underlying_asset_multiplier: Int,
) -> Bool {
  let accumulative_interest_fee: Int =
    calculate_accumulative_interest_fee(
      current_time,
      entered_position_time,
      hourly_borrow_fee,
    )

  if side == Long {
    let inital_position_usd_value: Int = position_amount * entered_at_usd_price

    let current_position_value: Int = position_amount * current_usd_price

    let total_value_loss: Int =
      current_position_value - inital_position_usd_value

    // if positive that means this is in profit and return false 
    if total_value_loss >= 0 {
      False
    } else {
      let collateral_value: Int = collateral_amount * current_usd_price

      let collateral_value_after_loss: Int =
        collateral_value - accumulative_interest_fee - total_value_loss

      let current_margin: Int =
        collateral_value_after_loss / current_position_value

      current_margin <= maintain_margin_amount
    }
  } else {
    let inital_position_usd_value: Int = position_amount * entered_at_usd_price

    let current_position_value: Int = position_amount * current_usd_price

    let total_value_loss: Int =
      inital_position_usd_value - current_position_value - accumulative_interest_fee

    // if positive that means this is in profit and return false 
    if total_value_loss > 0 {
      False
    } else {
      // change formatted current position value to the same unit as the stable amount lost
      let formatted_current_position_value =
        current_position_value / underlying_asset_multiplier

      // divide by the underlying asset multiplier to get units lost 
      let formatted_total_loss_usd: Int =
        total_value_loss / underlying_asset_multiplier

      let formatted_collateral_amount: Int =
        collateral_amount / stable_asset_multiplier * usd_multiplier

      // using a + here because total usd loss is negative
      let stable_amount_lost: Int =
        formatted_collateral_amount + formatted_total_loss_usd

      let current_margin: Int =
        stable_amount_lost / formatted_current_position_value

      current_margin <= maintain_margin_amount
    }
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

pub fn calculate_return(
  position_amount: Int,
  underlying_asset_multiplier: Int,
  collateral_asset_amount: Int,
  stable_asset_multiplier: Int,
  entered_at_usd_price: Int,
  current_usd_price: Int,
  strike_collateral_amount: Int,
  side: PositionSide,
  close_asset_type: AssetType,
  accumulative_interest_fee: Int,
  collateral_asset_type: AssetType,
  collateral_amount: Int,
) -> CloseSendAmount {
  // Simply calculate the profit or loss and add it to the collateral amount since the collateral is in the same asset as the underlying asset for longs
  // Then calculate how much is taken from the pool or how much is given to the pool based on the profit or loss
  if side == Long {
    let current_position_usd_value: Int = position_amount * current_usd_price

    let inital_position_usd_value: Int = position_amount * entered_at_usd_price

    // Calculate profit/loss in USD by current value minus initial value for long positions
    let position_usd_value: Int =
      current_position_usd_value - inital_position_usd_value

    let collateral_value: Int = collateral_asset_amount * current_usd_price

    // Subtract interest fees from position profit/loss to get net position value
    let position_value_after_interest_fee =
      position_usd_value - accumulative_interest_fee

    if close_asset_type == UnderlyingAsset {
      let send_asset_amount =
        ( collateral_value + position_value_after_interest_fee ) / current_usd_price

      let return_pool_asset_amount =
        position_value_after_interest_fee / current_usd_price * -1

      if collateral_asset_type == UnderlyingAsset {
        CloseSendAmount {
          send_asset_amount,
          return_pool_asset_amount,
          send_stable_amount: 0,
          return_pool_stable_amount: 0,
          strike_collateral_amount,
        }
      } else {
        CloseSendAmount {
          send_asset_amount,
          return_pool_asset_amount,
          send_stable_amount: 0,
          return_pool_stable_amount: collateral_amount,
          strike_collateral_amount,
        }
      }
    } else {
      let send_stable_amount =
        position_value_after_interest_fee * stable_asset_multiplier

      let return_pool_stable_amount = send_stable_amount * -1

      if collateral_asset_type == UnderlyingAsset {
        CloseSendAmount {
          send_asset_amount: 0,
          return_pool_asset_amount: collateral_amount,
          send_stable_amount,
          return_pool_stable_amount,
          strike_collateral_amount,
        }
      } else {
        CloseSendAmount {
          send_asset_amount: 0,
          return_pool_asset_amount: 0,
          send_stable_amount,
          return_pool_stable_amount,
          strike_collateral_amount,
        }
      }
    }
  } else {
    // first calculate if there is a profit or loss
    // If there is a profit, subtract the interest fee from the profit and return the profit + the full collateral amount
    // If there is a loss, subtract the loss and interest fee from the inital collateral amount, the collateral is a stable coin for short positions
    let current_position_value: Int = position_amount * current_usd_price

    let inital_position_usd_value: Int = position_amount * entered_at_usd_price

    let position_usd_value: Int =
      inital_position_usd_value - current_position_value

    let total_usd_value = position_usd_value - accumulative_interest_fee

    // divide by the usd price to get the asset amount0                                                                                                                                                       
    let asset_amount: Int = total_usd_value / current_usd_price

    // pool_asset_amount is negative because the gained assets are from the pool
    // no stable coin is taken from the pool
    if close_asset_type == UnderlyingAsset {
      if collateral_asset_type == UnderlyingAsset {
        CloseSendAmount {
          send_asset_amount: asset_amount,
          return_pool_asset_amount: -asset_amount,
          send_stable_amount: 0,
          return_pool_stable_amount: 0,
          strike_collateral_amount,
        }
      } else {
        CloseSendAmount {
          send_asset_amount: 0,
          return_pool_asset_amount: asset_amount,
          send_stable_amount: collateral_amount,
          return_pool_stable_amount: collateral_amount,
          strike_collateral_amount,
        }
      }
    } else {
      // divide by the underlying asset multiplier to get units lost 
      let formatted_total_loss_usd: Int =
        total_usd_value / underlying_asset_multiplier

      // divide the stable collateral amount by the stable asset multiplier and multiply it by the usd price multiplier to get the usd amount of the collateral 
      // in same unit as the total value loss usd
      let formatted_collateral_amount: Int =
        collateral_asset_amount / stable_asset_multiplier * usd_multiplier

      // using a + here because total usd loss is negative
      let stable_amount_lost: Int =
        formatted_collateral_amount + formatted_total_loss_usd

      // convert to back to collateral asset amount, by dividing by the usd multiplier and multiplying by the asset multiplier
      let formatted_stable_amount_lost: Int =
        stable_amount_lost * stable_asset_multiplier / usd_multiplier

      // convert to stable asset amount by multiplying by the stable asset multiplier and dividing by the usd multiplier
      // the formmated_total_loss_usd is already formatted to unit basis when we divided by the underlying asset multiplier
      // now we need to convert it to the stable asset amount, and divide by the usd multiplier
      // then multiply by -1 because this is negative and we want the value to be positive to know how much stable coin the pool with take
      let stable_amount =
        formatted_total_loss_usd * stable_asset_multiplier / usd_multiplier

      let pool_stable_amount: Int = stable_amount * -1

      if collateral_asset_type == UnderlyingAsset {
        CloseSendAmount {
          send_asset_amount: 0,
          return_pool_asset_amount: asset_amount,
          send_stable_amount: stable_amount,
          return_pool_stable_amount: pool_stable_amount,
          strike_collateral_amount,
        }
      } else {
        CloseSendAmount {
          send_asset_amount: 0,
          return_pool_asset_amount: 0,
          send_stable_amount: stable_amount,
          return_pool_stable_amount: pool_stable_amount,
          strike_collateral_amount,
        }
      }
    }
  }
}
