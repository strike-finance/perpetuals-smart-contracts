use positions_validations.{
  calculate_accumulative_interest_fee, calculate_hourly_usd_borrow_fee,
  calculate_return, reach_liquidation_price,
}
use types.{CloseSendAmount, Long, LongCloseOrder, Short, ShortCloseOrder}

// Inital Position:
// - Amount: 3.4 ADA (3_400_000 lovelace)
// - Entry Price: $0.58678 per ADA
// - Initial Position Value: $1.995052
// Utilization Factor: 50_000_000 / 1_500_000_000 = 3.3333333333333335%
// Hourly Borrow Fee: $1.995052 * 3.3333333333333335% * 20% = $0.01328704632
test test_calculate_hourly_usd_borrow_fee() {
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

test test_calculate_long_profit_return() {
  // Initial Position:
  // - Amount: 100 ADA (100_000_000 lovelace)
  // - Entry Price: $0.58678 per ADA
  // - Initial Position Value: $58.678
  // Current State:
  // - Current Price: $0.80 per ADA
  // - Current Position Value: $80.00
  // - Position Profit: $80.00 - $58.678 = $21.322
  // Fees:
  // - Accumulated Fee: 119_703_120_000 (≈ $1.19703)
  // - Fee Calculation: amount / 1_000_000 (to ADA) / 10_000 (USD multiplier)
  // Final Calculation:
  // 1. Net Profit = $21.322 - $1.19703 = $20.1245
  // 2. Profit in ADA = $20.1245 / $0.80 = 25.155625 ADA
  // 3. Total Return = 25.155625 ADA + 10 ADA (collateral) = 35.155625 ADA
  // 4. Expected Result: 35156211 lovelace
  let return: CloseSendAmount =
    calculate_return(
      position_amount: 100_000_000,
      underlying_asset_multiplier: 1_000_000,
      collateral_asset_amount: 10_000_000,
      stable_asset_multiplier: 1_000_000,
      entered_at_usd_price: 58678,
      current_usd_price: 80000,
      current_time: 1727453227635 + 3_800_000,
      entered_position_time: 1727453227635,
      hourly_borrow_fee: 119_703_120_000,
      strike_collateral_amount: 10,
      side: Long,
    )

  expect LongCloseOrder {
    asset_amount,
    strike_collateral_amount,
    pool_asset_amount,
  } = return

  asset_amount == 35156211 && strike_collateral_amount == 10 && pool_asset_amount == -25156211
}

test test_calculate_long_loss_return() {
  // Initial Position:
  // - Amount: 100 ADA (100_000_000 lovelace)
  // - Entry Price: $0.58678 per ADA
  // - Initial Position Value: $58.678
  // Current State:
  // - Current Price: $0.56 per ADA
  // - Current Position Value: $56.00
  // - Position Loss: $56.00 - $58.678 = -$2.678
  // Fees:
  // - Accumulated Fee: 119_703_120_000 (≈ $1.19703)
  // - Fee Calculation: amount / 1_000_000 (to ADA) / 10_000 (USD multiplier)
  // Final Calculation:
  // 1. Total Loss = -$2.678 - $1.19703 = -$3.87503
  // 2. Current Collateral Value = 10 ADA * $0.56 = $5.60
  // 3. Net Value = $5.60 - $3.87503 = $1.72497
  // 4. Return in ADA = $1.72497 / $0.56 = 3.080301 ADA
  // 5. Expected Result: 3080301 lovelace
  let return: CloseSendAmount =
    calculate_return(
      position_amount: 100_000_000,
      underlying_asset_multiplier: 1_000_000,
      collateral_asset_amount: 10_000_000,
      stable_asset_multiplier: 1_000_000,
      entered_at_usd_price: 58678,
      current_usd_price: 56000,
      current_time: 1727453227635 + 3_800_000,
      entered_position_time: 1727453227635,
      hourly_borrow_fee: 119_703_120_000,
      strike_collateral_amount: 10,
      side: Long,
    )

  expect LongCloseOrder {
    asset_amount,
    strike_collateral_amount,
    pool_asset_amount,
  } = return

  asset_amount == 3080301 && strike_collateral_amount == 10 && pool_asset_amount == 6919699
}

test test_calculate_short_profit_return() {
  // Initial Position:
  // - Amount: 100 ADA (100_000_000 lovelace)
  // - Entry Price: $0.58678 per ADA
  // - Initial Position Value: $58.678
  // Current State:
  // - Current Price: $0.56 per ADA
  // - Position Profit: $58.678 - $56.00 = $2.678
  // Fees:
  // - Accumulated Fee: 119_703_120_000 (≈ $1.19703)
  // - Fee Calculation: amount / 1_000_000 (to ADA) / 10_000 (USD multiplier)
  // Final Calculation:
  // 1. Net Profit = $2.678 - $1.19703 = $1.48097
  // 2. Return in ADA = $1.48097 / $0.56 = 2.64458 ADA
  // 3. Total Return = Original Collateral + Profit = 10 ADA + 2.64458 ADA
  // 4. Expected Results:
  //    - asset_amount:  2644587 lovelace
  //    - stable_amount: 10000000 lovelace (unchanged)
  let return: CloseSendAmount =
    calculate_return(
      position_amount: 100_000_000,
      underlying_asset_multiplier: 1_000_000,
      collateral_asset_amount: 50,
      stable_asset_multiplier: 1_000_000,
      entered_at_usd_price: 58678,
      current_usd_price: 56000,
      current_time: 1727453227635 + 3_800_000,
      entered_position_time: 1727453227635,
      hourly_borrow_fee: 119_703_120_000,
      strike_collateral_amount: 10,
      side: Short,
    )

  expect ShortCloseOrder {
    asset_amount,
    strike_collateral_amount,
    stable_amount,
    pool_asset_amount,
    pool_stable_amount,
  } = return

  asset_amount == 2644587 && stable_amount == 50 && strike_collateral_amount == 10 && pool_asset_amount == -2644587 && pool_stable_amount == 0
}

test test_calculate_short_loss_return() {
  // Initial Position:
  // - Amount: 100 ADA (100_000_000 lovelace)
  // - Entry Price: $0.58000 per ADA
  // - Initial Position Value: $58
  // Current State:
  // - Current Price: $0.59 per ADA
  // - Position Loss: $58.00 - $59.00 = -$1
  // Fees:
  // - Accumulated Fee: 119_703_120_000 (≈ $1.19703)
  // - Fee Calculation: amount / 1_000_000 (to ADA) / 10_000 (USD multiplier)
  // Final Calculation:
  // 1. Net Loss = -$1 - $1.19703 = -$2.19703
  // 3. Total Return = Original Collateral + loss = $50 ADA + -$2.19703
  // 4. Expected Results:
  //    - asset_amount:  0 lovelace
  //    - stable_amount: 47802960 stable asset or ~$47.80296 (unchanged)
  let return: CloseSendAmount =
    calculate_return(
      position_amount: 100_000_000,
      underlying_asset_multiplier: 1_000_000,
      collateral_asset_amount: 50_000_000,
      stable_asset_multiplier: 1_000_000,
      entered_at_usd_price: 58000,
      current_usd_price: 59000,
      current_time: 1727453227635 + 3_800_000,
      entered_position_time: 1727453227635,
      hourly_borrow_fee: 119_703_120_000,
      strike_collateral_amount: 10,
      side: Short,
    )

  expect ShortCloseOrder {
    asset_amount,
    stable_amount,
    strike_collateral_amount,
    pool_stable_amount,
    pool_asset_amount,
  } = return

  asset_amount == 0 && stable_amount == 47802960 && strike_collateral_amount == 10 && pool_stable_amount == 2197040 && pool_asset_amount == 0
}

test test_calculate_accumulative_interest_fee() {
  let accumulative_interest_fee =
    calculate_accumulative_interest_fee(
      current_time: 1727453227635 + 3_800_000,
      entered_position_time: 1727453227635,
      hourly_borrow_usd_fee: 119703120000,
    )

  accumulative_interest_fee == 119703120000
}

test test_long_reach_liquidation_price() {
  reach_liquidation_price(
    side: Long,
    position_amount: 10_000_000,
    current_usd_price: 5300,
    entered_at_usd_price: 5400,
    maintain_margin_amount: 5,
    collateral_amount: 1_000_000,
    entered_position_time: 1727453227635,
    current_time: 1727453227635 + 3_800_000,
    hourly_borrow_fee: 119_703_120_000,
    underlying_asset_multiplier: 1_000_000,
    stable_asset_multiplier: 1_000_000,
  ) == True
}

test test_long_not_reach_liquidation_price() {
  reach_liquidation_price(
    side: Long,
    position_amount: 10_000_000,
    current_usd_price: 5500,
    entered_at_usd_price: 5400,
    maintain_margin_amount: 5,
    collateral_amount: 1_000_000,
    entered_position_time: 1727453227635,
    current_time: 1727453227635 + 3_800_000,
    hourly_borrow_fee: 119_703_120_000,
    underlying_asset_multiplier: 1_000_000,
    stable_asset_multiplier: 1_000_000,
  ) == False
}

test test_short_reach_liquidation_price() {
  reach_liquidation_price(
    side: Short,
    position_amount: 10_000_000,
    current_usd_price: 8000,
    entered_at_usd_price: 5400,
    maintain_margin_amount: 5,
    collateral_amount: 1_000_000,
    entered_position_time: 1727453227635,
    current_time: 1727453227635 + 3_800_000,
    hourly_borrow_fee: 119_703_120_000,
    underlying_asset_multiplier: 1_000_000,
    stable_asset_multiplier: 1_000_000,
  ) == True
}

test test_short_not_reach_liquidation_price() {
  reach_liquidation_price(
    side: Short,
    position_amount: 10_000_000,
    current_usd_price: 5300,
    entered_at_usd_price: 5400,
    maintain_margin_amount: 5,
    collateral_amount: 10_000_000,
    entered_position_time: 1727453227635,
    current_time: 1727453227635 + 3_800_000,
    hourly_borrow_fee: 119_703_120_000,
    underlying_asset_multiplier: 1_000_000,
    stable_asset_multiplier: 1_000_000,
  ) == False
}
