use aiken/math.{min}
use types.{FundPeriodDatum}

pub fn new_funding_period_datum_valid(
  old_fund_round_datum: FundPeriodDatum,
  new_fund_round_datum: FundPeriodDatum,
  new_price: Int,
) -> Bool {
  let matched_amount: Int =
    min(
      old_fund_round_datum.current_long_position_amount,
      old_fund_round_datum.current_short_position_amount,
    )

  let total_amount_stays_same: Bool =
    old_fund_round_datum.total_long_position_amount == new_fund_round_datum.total_long_position_amount && old_fund_round_datum.total_short_position_amount == new_fund_round_datum.total_short_position_amount

  let long_side_win: Bool = new_price > old_fund_round_datum.start_price

  let percentage_paid: Int = 1 / 10

  let paid_amount: Int = matched_amount * percentage_paid

  if long_side_win {
    let long_amount_valid: Bool =
      new_fund_round_datum.total_long_position_amount + paid_amount == old_fund_round_datum.total_long_position_amount
    let short_amount_valid: Bool =
      new_fund_round_datum.total_short_position_amount - paid_amount == old_fund_round_datum.total_short_position_amount

    long_amount_valid && short_amount_valid && total_amount_stays_same
  } else {
    let long_amount_valid: Bool =
      new_fund_round_datum.total_long_position_amount + paid_amount == old_fund_round_datum.total_long_position_amount
    let short_amount_valid: Bool =
      new_fund_round_datum.total_short_position_amount - paid_amount == old_fund_round_datum.total_short_position_amount

    long_amount_valid && short_amount_valid && total_amount_stays_same
  }
}
