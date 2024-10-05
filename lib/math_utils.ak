use types.{PoolDatum, PositionDatum}

pub fn calculate_pay_borrow(
  position_datum: PositionDatum,
  pool_datum: PoolDatum,
  current_price_volume: Int,
) -> Int {
  let utilization =
    pool_datum.pool_asset_lended_amount / pool_datum.pool_asset_amount

  let current_position_usd_value =
    position_datum.position_amount * current_price_volume

  utilization * pool_datum.pooled_interest_rate * current_position_usd_value
}


