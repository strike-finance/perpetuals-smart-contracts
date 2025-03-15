use cardano/transaction.{OutputReference, Transaction}
use positions_validations.{
  add_collateral_valid, close_position_valid,
  increase_position_from_profit_valid, liquidate_close_valid,
  rebalance_position_valid, update_position_valid,
}
use types.{CloseType, PositionDatum, ScriptHash}

pub type ManagePositionRedeemer {
  Close { close_price: Int, close_type: CloseType }
  AddCollateral
  PositionUpdate { stop_loss: Int, take_profit: Int }
  LiquidateClose { current_usd_price: Int }
  RebalancePosition
  IncreasePositionFromProfit
}

validator manage_positions(orders_script_hash: ScriptHash) {
  spend(
    datum: Option<PositionDatum>,
    redeemer: ManagePositionRedeemer,
    _own_ref: OutputReference,
    transaction: Transaction,
  ) {
    when redeemer is {
      Close(current_usd_price, close_type) ->
        close_position_valid(
          transaction,
          datum,
          current_usd_price,
          orders_script_hash,
          close_type,
        )
      LiquidateClose(current_usd_price) ->
        liquidate_close_valid(
          transaction,
          datum,
          orders_script_hash,
          current_usd_price,
        )
      AddCollateral -> add_collateral_valid(transaction, datum)
      PositionUpdate(stop_loss, take_profit) ->
        update_position_valid(transaction, datum, stop_loss, take_profit)
      RebalancePosition -> rebalance_position_valid()
      IncreasePositionFromProfit -> increase_position_from_profit_valid()
    }
  }

  else(_) {
    False
  }
}
