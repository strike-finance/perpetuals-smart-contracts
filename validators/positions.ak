use cardano/transaction.{OutputReference, Transaction}
use validations/positions_utils.{
  validate_close_position, validate_pay_lend, validate_stop_loss,
}
use types.{Close, PayLend, PositionDatum, PositionsRedeemer, StopLoss}

validator positions(orders_validator: ByteArray) {
  spend(
    datum: Option<PositionDatum>,
    redeemer: PositionsRedeemer,
    _own_ref: OutputReference,
    transaction: Transaction,
  ) {
    when redeemer is {
      Close -> validate_close_position(transaction, datum, orders_validator)
      StopLoss(current_price) ->
        validate_stop_loss(transaction, datum, current_price, orders_validator)
      PayLend(current_price) ->
        validate_pay_lend(transaction, datum, current_price)
    }
  }

  else(_) {
    False
  }
}
