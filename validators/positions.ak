use cardano/transaction.{OutputReference, Transaction}
use types.{
  Close, LiquidatePosition, PayLend, PositionDatum, PositionsRedeemer, StopLoss,
  TakeProfit, UpdateStopLoss, UpdateTakeProfit,
}
use validations/positions_utils.{
  close_position, liquidate_position, stop_loss, take_profit, update_stop_loss, pay_lend,
  update_take_profit,
}

validator positions(orders_validator: ByteArray) {
  spend(
    datum: Option<PositionDatum>,
    redeemer: PositionsRedeemer,
    _own_ref: OutputReference,
    transaction: Transaction,
  ) {
    when redeemer is {
      Close -> close_position(transaction, datum, orders_validator)
      StopLoss(current_price) ->
      stop_loss(transaction, datum, current_price, orders_validator)
      UpdateStopLoss -> update_stop_loss(transaction, datum, orders_validator)
      TakeProfit(current_price) ->
        take_profit(transaction, datum, current_price, orders_validator)
      UpdateTakeProfit -> update_take_profit(transaction, datum, orders_validator)
      LiquidatePosition(current_price) ->
        liquidate_position(
          transaction,
          datum,
          current_price,
          orders_validator,
        )
      PayLend(current_price) ->
   pay_lend(transaction, datum, current_price)
    }
  }

  else(_) {
    False
  }
}
