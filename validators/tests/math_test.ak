use positions_validations.{calculate_hourly_usd_borrow_fee}

test test_calculate_hourly_usd_borrow_fee() {
  let hourly_usd_borrow_fee =
    calculate_hourly_usd_borrow_fee(
      position_asset_amount: 1_000_000,
      underlying_asset_lended_amount: 10,
      current_usd_price: 1_000_000,
      underlying_asset_amount: 1_000_000,
      interest_rate: 10,
    )
  hourly_usd_borrow_fee == 1
}
