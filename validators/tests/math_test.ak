use positions_validations.{
  calculate_accumulative_interest_fee, calculate_hourly_usd_borrow_fee,
  calculate_return,
}
use types.{CloseSendAmount, Long, LongCloseOrder}

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
  // 100 ADA / Inital value $58.678
  // 100 ADA/ Current value = $80
  // position profit = $80 - $58.678 = $21.322
  // 119_703_120_000 fee ~ $1.9703 accumultive fee, divide by 1_000_000 to ADA units, divide by 10_000 for usd multiplier,
  // Total profit = $21.322 - $1.9703 = $20.1245
  // $20.1245 / $.80 = 25.155625 ADA  profit
  // 25.155625 ADA + 10 ada = 35.155625 ADA returned
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
  // 100 ADA / Inital value $58.678
  // 100 ADA/ Current value = $80
  // position profit = $80 - $58.678 = $21.322
  // 119_703_120_000 fee ~ $1.9703 accumultive fee, divide by 1_000_000 to ADA units, divide by 10_000 for usd multiplier,
  // Total profit = $21.322 - $1.9703 = $20.1245
  // $20.1245 / $.80 = 25.155625 ADA  profit
  // 25.155625 ADA + 10 ada = 35.155625 ADA returned
  let return: CloseSendAmount =
    calculate_return(
      position_amount: 100_000_000,
      collateral_amount: 10_000_000,
      entered_at_usd_price: 58678,
      current_usd_price: 40000,
      current_time: 1727453227635 + 3_800_000,
      entered_position_time: 1727453227635,
      hourly_borrow_fee: 119_703_120_000,
      side: Long,
    )

  expect LongCloseOrder { asset_amount } = return

  asset_amount == 35156211
}

// test test_calculate_short_profit_return() {
//   todo
// }

// test test_calculate_short_loss_return() {
//   todo
// }

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
