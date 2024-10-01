use cardano/transaction.{OutputReference, Transaction}
use positions_utils.{validate_close_position, validate_stop_loss}
use types.{Close, PositionDatum, PositionsRedeemer, StopLoss}

// This validator handles all logic regarding the users positions. They will be able to open and close their positions here. 
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
    }
  }

  else(_) {
    False
  }
}
