use cardano/assets.{PolicyId, flatten}
use cardano/transaction.{OutputReference, Transaction}
use positions_validations.{
  close_position, mint_position, update_stop_loss, update_take_profit,
}
use types.{
  BurnPosition, Close, MintPosition, PositionDatum, PositionMintRedeemer,
  PositionRedeemer, PositionsParams, UpdateStopLoss, UpdateTakeProfit,
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
        close_position(
          transaction,
          datum,
          current_usd_price,
          params.orders_script_hash,
          close_type,
        )
      UpdateStopLoss(stop_loss_price) ->
        update_stop_loss(transaction, datum, stop_loss_price)
      UpdateTakeProfit(take_profit_price) ->
        update_take_profit(transaction, datum, take_profit_price)
    }
  }

  mint(
    redeemer: PositionMintRedeemer,
    policy_id: PolicyId,
    transaction: Transaction,
  ) {
    when redeemer is {
      MintPosition(current_usd_price) ->
        mint_position(
          transaction,
          params,
          current_usd_price,
          policy_id,
          params.pool_license,
        )
      BurnPosition(burn_amount, asset_name) -> {
        let expected_burnt = [(policy_id, asset_name, -burn_amount)]
        expected_burnt == flatten(transaction.mint)
      }
    }
  }

  else(_) {
    False
  }
}
