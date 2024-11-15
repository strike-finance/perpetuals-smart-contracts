use positions_validations.{
  calculate_accumulative_interest_fee, calculate_hourly_usd_borrow_fee,
  calculate_return,
}
use types.{CloseSendAmount, Long, LongCloseOrder, Short, ShortCloseOrder}

// Doesn't work if underlying_asset_amount / underlying_asset_lended_amount is less than 1, which will be the case most of the time
// Utilization rate is the percentage of the underlying asset lended that is being used, and this will often be less than 1% unless for 
// most trades
test test_calculate_hourly_usd_borrow_fee() {
  let hourly_usd_borrow_fee =
    calculate_hourly_usd_borrow_fee(
      position_asset_amount: 3_400_000,
      underlying_asset_lended_amount: 50_000_000,
      current_usd_price: 58678,
      underlying_asset_amount: 1_500_000_000,
      interest_rate: 20,
    )

  hourly_usd_borrow_fee == 119703120000
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
      collateral_amount: 10_000_000,
      entered_at_usd_price: 58678,
      current_usd_price: 80000,
      current_time: 1727453227635 + 3_800_000,
      entered_position_time: 1727453227635,
      hourly_borrow_fee: 119_703_120_000,
      side: Long,
    )

  expect LongCloseOrder { asset_amount } = return

  asset_amount == 35156211
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
      collateral_amount: 10_000_000,
      entered_at_usd_price: 58678,
      current_usd_price: 56000,
      current_time: 1727453227635 + 3_800_000,
      entered_position_time: 1727453227635,
      hourly_borrow_fee: 119_703_120_000,
      side: Long,
    )

  expect LongCloseOrder { asset_amount } = return

  asset_amount == 3080301
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
  //    - collateral_amount: 10000000 lovelace (unchanged)
  let return: CloseSendAmount =
    calculate_return(
      position_amount: 100_000_000,
      collateral_amount: 50,
      entered_at_usd_price: 58678,
      current_usd_price: 56000,
      current_time: 1727453227635 + 3_800_000,
      entered_position_time: 1727453227635,
      hourly_borrow_fee: 119_703_120_000,
      side: Short,
    )

  expect ShortCloseOrder { asset_amount, collateral_amount } = return

  trace asset_amount
  trace collateral_amount

  asset_amount == 2644587 && collateral_amount == 50
}

// TODO: The function fails for this 
test test_calculate_short_loss_return() {
  let return: CloseSendAmount =
    calculate_return(
      position_amount: 100_000_000,
      collateral_amount: 500000,
      entered_at_usd_price: 58678,
      current_usd_price: 59000,
      current_time: 1727453227635 + 3_800_000,
      entered_position_time: 1727453227635,
      hourly_borrow_fee: 119_703_120_000,
      side: Short,
    )

  expect ShortCloseOrder { asset_amount, collateral_amount } = return

  trace collateral_amount

  asset_amount == 0 && collateral_amount == 0
}

test test_calculate_accumulative_interest_fee() {
  let accumulative_interest_fee =
    calculate_accumulative_interest_fee(
      current_time: 1727453227635 + 3_800_000,
      entered_position_time: 1727453227635,
      hourly_borrow_usd_fee: 119703120000,
    )

  trace accumulative_interest_fee
  accumulative_interest_fee == 119703120000
}
