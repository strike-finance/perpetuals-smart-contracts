use aiken/math/rational
use types.{Long, POSIXTime, PositionSide, Short}

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
    let collateral_value: Int = collateral_amount * entered_at_usd_price

    let collateral_value_after_loss =
      when total_value_loss > 0 is {
        True -> collateral_value - total_value_loss
        False -> collateral_value + total_value_loss
      }

    let current_margin: Int =
      collateral_value_after_loss * 1_000 / current_position_value

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

// The lp = shares of the pool that the user has deposited
// The ratio of the lp they recive and total lp minted is the same as the ratio of the asset they deposit and total asset amount
pub fn calculate_lp_assets_sent(
  total_asset_amount: Int,
  total_lp_minted_amount: Int,
  deposit_asset_amount: Int,
) -> Int {
  if total_asset_amount == 0 {
    deposit_asset_amount
  } else {
    let deposit_asset_amount_multiplier = deposit_asset_amount * 10_000

    let total_liquidity_ratio =
      deposit_asset_amount_multiplier / total_asset_amount

    total_liquidity_ratio * total_lp_minted_amount / 10_000
  }
}

// The ratio of the asset they get back and total asset amount is the same as the ratio of the lp they deposit and total lp minted
pub fn calculate_assets_get_back(
  total_asset_amount: Int,
  total_lp_minted_amount: Int,
  deposit_lp_assets_amount: Int,
) -> Int {
  let deposit_lp_assets_amount_multiplier = deposit_lp_assets_amount * 1_000_000

  let total_liquidity_ratio =
    deposit_lp_assets_amount_multiplier / total_lp_minted_amount

  total_liquidity_ratio * total_asset_amount / 1_000_000
}

// Calculate the reblance method and amount of assets to sent back 
// Since there are no floats in this, we want to send back 10 percent 
// of the position asset amount. We first multiple it by 10, then divide it by a 
// 100 to get 1 percent
pub fn calculate_rebalance_asset_sent_to_pool(position_asset_amount: Int) -> Int {
  position_asset_amount * 10 / 100
}

// Inital Position:
// - Amount: 3.4 ADA (3_400_000 lovelace)
// - Entry Price: $0.58678 per ADA
// - Initial Position Value: $1.995052
// Utilization Factor: 50_000_000 / 1_500_000_000 = 3.3333333333333335%
// Hourly Borrow Fee: $1.995052 * 3.3333333333333335% * 20% = $0.01328704632
test hourly_borrow_fee() {
  let hourly_usd_borrow_fee =
    calculate_hourly_usd_borrow_fee(
      position_asset_amount: 3_400_000,
      underlying_asset_lended_amount: 50_000_000,
      current_usd_price: 58678,
      pool_underlying_asset_amount: 1_500_000_000,
      interest_rate: 20,
    )

  hourly_usd_borrow_fee == 1328704632
}

// Test for reach_liquidation_price
// Case 1: Position in profit (should not be liquidated)
// Long position with price going up
test reach_liquidation_price_long_profit() {
  let side = Long
  let position_amount = 1_000_000
  let current_usd_price = 60000
  let entered_at_usd_price = 50000
  let maintain_margin_amount = 10
  let collateral_amount = 500000
  let entered_position_time = 1000000
  let hourly_borrow_fee = 100000
  let current_time = 2000000

  let result =
    reach_liquidation_price(
      side,
      position_amount,
      current_usd_price,
      entered_at_usd_price,
      maintain_margin_amount,
      collateral_amount,
      entered_position_time,
      hourly_borrow_fee,
      current_time,
    )

  result == False
}

// Case 2: Position at loss but above liquidation threshold
// Long position with price going down but still above margin requirements
test reach_liquidation_price_long_loss_above_threshold() {
  let side = Long
  let position_amount = 1_000_000
  let current_usd_price = 40000
  let entered_at_usd_price = 50000
  let maintain_margin_amount = 10
  let collateral_amount = 200000
  // High collateral
  let entered_position_time = 1000000
  let hourly_borrow_fee = 100000
  let current_time = 2000000

  let result =
    reach_liquidation_price(
      side,
      position_amount,
      current_usd_price,
      entered_at_usd_price,
      maintain_margin_amount,
      collateral_amount,
      entered_position_time,
      hourly_borrow_fee,
      current_time,
    )

  result == True
}

// Case 3: Position at loss and below liquidation threshold
// Long position with price going down significantly
test reach_liquidation_price_long_liquidation() {
  let side = Long
  let position_amount = 1_000_000
  let current_usd_price = 40000
  let entered_at_usd_price = 50000
  let maintain_margin_amount = 10
  let collateral_amount = 50000
  // Low collateral
  let entered_position_time = 1000000
  let hourly_borrow_fee = 100000
  let current_time = 2000000

  let result =
    reach_liquidation_price(
      side,
      position_amount,
      current_usd_price,
      entered_at_usd_price,
      maintain_margin_amount,
      collateral_amount,
      entered_position_time,
      hourly_borrow_fee,
      current_time,
    )

  result == True
}

// Test for calculate_position_usd_value_based_on_side
// Case 1: Long position with profit
test calculate_position_usd_value_long_profit() {
  let side = Long
  let position_amount = 1_000_000
  let current_usd_price = 60000
  let entered_at_usd_price = 50000
  let accumulative_interest_fee = 1000000

  // Current value: 1_000_000 * 60000 = 60_000_000_000
  // Initial value: 1_000_000 * 50000 = 50_000_000_000
  // Profit = 60_000_000_000 - 50_000_000_000 - 1000000 = 9_999_000_000
  let result =
    calculate_position_usd_value_based_on_side(
      side,
      position_amount,
      current_usd_price,
      entered_at_usd_price,
      accumulative_interest_fee,
    )

  result == 9_999_000_000
}

// Case 2: Long position with loss
test calculate_position_usd_value_long_loss() {
  let side = Long
  let position_amount = 1_000_000
  let current_usd_price = 40000
  let entered_at_usd_price = 50000
  let accumulative_interest_fee = 1000000

  // Current value: 1_000_000 * 40000 = 40_000_000_000
  // Initial value: 1_000_000 * 50000 = 50_000_000_000
  // Loss = 40_000_000_000 - 50_000_000_000 - 1000000 = -10_001_000_000
  let result =
    calculate_position_usd_value_based_on_side(
      side,
      position_amount,
      current_usd_price,
      entered_at_usd_price,
      accumulative_interest_fee,
    )

  result == -10_001_000_000
}

// Case 3: Short position with profit
test calculate_position_usd_value_short_profit() {
  // Using PositionSide.Short from types
  let position_amount = 1_000_000
  let current_usd_price = 40000
  let entered_at_usd_price = 50000
  let accumulative_interest_fee = 1000000

  // Initial value: 1_000_000 * 50000 = 50_000_000_000
  // Current value: 1_000_000 * 40000 = 40_000_000_000
  // Profit = 50_000_000_000 - 40_000_000_000 - 1000000 = 9_999_000_000
  let result =
    calculate_position_usd_value_based_on_side(
      Short,
      position_amount,
      current_usd_price,
      entered_at_usd_price,
      accumulative_interest_fee,
    )

  result == 9_999_000_000
}

// Case 4: Short position with loss
test calculate_position_usd_value_short_loss() {
  // Using PositionSide.Short from types
  let position_amount = 1_000_000
  let current_usd_price = 60000
  let entered_at_usd_price = 50000
  let accumulative_interest_fee = 1000000

  // Initial value: 1_000_000 * 50000 = 50_000_000_000
  // Current value: 1_000_000 * 60000 = 60_000_000_000
  // Loss = 50_000_000_000 - 60_000_000_000 - 1000000 = -10_001_000_000
  let result =
    calculate_position_usd_value_based_on_side(
      Short,
      position_amount,
      current_usd_price,
      entered_at_usd_price,
      accumulative_interest_fee,
    )

  result == -10_001_000_000
}

// Test for calculate_accumulative_interest_fee
// Case 1: Exactly 1 hour has passed
test calculate_accumulative_interest_fee_1_hour() {
  let current_time = 4_600_000
  // 1 hour + initial time
  let entered_position_time = 1_000_000
  let hourly_borrow_usd_fee = 1000000

  // Time difference: 3_600_000 (1 hour in milliseconds)
  // Hours passed: 1
  // Interest fee: 1 * 1000000 = 1000000
  let result =
    calculate_accumulative_interest_fee(
      current_time,
      entered_position_time,
      hourly_borrow_usd_fee,
    )

  result == 1000000
}

// Case 2: Less than 1 hour has passed
test calculate_accumulative_interest_fee_less_than_1_hour() {
  let current_time = 3_000_000
  // Less than 1 hour
  let entered_position_time = 1_000_000
  let hourly_borrow_usd_fee = 1000000

  // Time difference: 2_000_000 (less than 1 hour)
  // Hours passed: 0
  // Interest fee: 0 * 1000000 = 0
  let result =
    calculate_accumulative_interest_fee(
      current_time,
      entered_position_time,
      hourly_borrow_usd_fee,
    )

  result == 0
}

// Case 3: Multiple hours have passed
test calculate_accumulative_interest_fee_multiple_hours() {
  let current_time = 12_800_000
  // 3 hours + initial time
  let entered_position_time = 1_000_000
  let hourly_borrow_usd_fee = 1000000

  // Time difference: 11_800_000
  // Hours passed: 3 (floor of 11_800_000 / 3_600_000)
  // Interest fee: 3 * 1000000 = 3000000
  let result =
    calculate_accumulative_interest_fee(
      current_time,
      entered_position_time,
      hourly_borrow_usd_fee,
    )

  result == 3000000
}

// Test for calculate_lp_assets_sent
// Case 1: Empty pool (first deposit)
test calculate_lp_assets_sent_empty_pool() {
  let total_asset_amount = 0
  let total_lp_minted_amount = 0
  let deposit_asset_amount = 1000000

  // When pool is empty, LP tokens received equals deposit amount
  let result =
    calculate_lp_assets_sent(
      total_asset_amount,
      total_lp_minted_amount,
      deposit_asset_amount,
    )

  result == 1000000
}

// Case 2: Non-empty pool with deposit
test calculate_lp_assets_sent_existing_pool() {
  let total_asset_amount = 5000000
  let total_lp_minted_amount = 5000000
  let deposit_asset_amount = 1000000

  // Deposit ratio: (1000000 * 10000) / 5000000 = 2000
  // LP sent: 2000 * 5000000 / 10000 = 1000000
  let result =
    calculate_lp_assets_sent(
      total_asset_amount,
      total_lp_minted_amount,
      deposit_asset_amount,
    )

  result == 1000000
}

// Case 3: Large pool values
test calculate_lp_assets_sent_large_values() {
  let total_asset_amount = 100_000_000
  let total_lp_minted_amount = 80_000_000
  let deposit_asset_amount = 10_000_000

  // Deposit ratio: (10_000_000 * 10000) / 100_000_000 = 1000
  // LP sent: 1000 * 80_000_000 / 10000 = 8_000_000
  let result =
    calculate_lp_assets_sent(
      total_asset_amount,
      total_lp_minted_amount,
      deposit_asset_amount,
    )

  result == 8_000_000
}
