use cardano/assets.{PolicyId, flatten}
use cardano/transaction.{OutputReference, Transaction}
use positions_validations.{
  add_collateral_valid, close_position_valid,
  increase_position_from_profit_valid, mint_position_valid,
  rebalance_position_valid, update_position_valid,
}
use types.{
  AddCollateral, Close, ClosePosition, IncreasePositionFromProfit, OpenPosition,
  PositionDatum, PositionMintRedeemer, PositionRedeemer, PositionUpdate,
  PositionsParams, RebalancePosition,
}

validator positions(params: PositionsParams) {
  spend(
    datum: Option<PositionDatum>,
    redeemer: PositionRedeemer,
    _own_ref: OutputReference,
    transaction: Transaction,
  ) {
    when redeemer is {
      Close(current_usd_price, close_type) ->
        close_position_valid(
          transaction,
          datum,
          current_usd_price,
          params,
          close_type,
        )
      AddCollateral -> add_collateral_valid(transaction, datum)
      PositionUpdate(stop_loss, take_profit) ->
        update_position_valid(transaction, datum, stop_loss, take_profit)
      RebalancePosition -> rebalance_position_valid()
      IncreasePositionFromProfit -> increase_position_from_profit_valid()
    }
  }

  mint(
    redeemer: PositionMintRedeemer,
    policy_id: PolicyId,
    transaction: Transaction,
  ) {
    when redeemer is {
      OpenPosition(current_usd_price) ->
        mint_position_valid(
          transaction: transaction,
          params: params,
          current_usd_price: current_usd_price,
          policy_id: policy_id,
        )
      // Batcher might close/liquidate multiple positions at once
      ClosePosition(burn_amount) ->
        [(policy_id, params.asset_name, -burn_amount)] == flatten(
          transaction.mint,
        )
    }
  }

  else(_) {
    False
  }
}
