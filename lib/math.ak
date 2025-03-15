use aiken/math/rational
use cardano/transaction.{InlineDatum, Input, Output, Transaction}
use types.{CloseSendAmount, Long, POSIXTime, PositionDatum, PositionSide}

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
