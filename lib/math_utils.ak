pub fn calculate_pay_borrow(
  position_amount: Int,
  total_amount_in_pool: Int,
  borrow_amount: Int,
  borrow_rate: Int,
) -> Int {
  borrow_amount / total_amount_in_pool * borrow_rate - position_amount
}

pub fn calculate_withdraw_liquidity(
  position_amount: Int,
  position_price: Int,
  liquidity_amount: Int,
) -> Int {
  position_amount * position_price - liquidity_amount
}
