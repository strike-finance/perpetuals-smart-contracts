use cardano/assets.{PolicyId}
use cardano/transaction.{OutputReference, Transaction}
use positions_validations.{
  close_position, mint_position, pay_lend, update_stop_loss, update_take_profit,
}
use types.{
  BurnPosition, Close, MintPosition, PayLend, PositionDatum,
  PositionsMintRedeemer, PositionsParams, PositionsRedeemer, UpdateStopLoss,
  UpdateTakeProfit,
}
use utils.{validate_token_mint}

validator positions(params: PositionsParams) {
  spend(
    datum: Option<PositionDatum>,
    redeemer: PositionsRedeemer,
    _own_ref: OutputReference,
    transaction: Transaction,
  ) {
    when redeemer is {
      Close(current_price, close_type) ->
        close_position(
          transaction,
          datum,
          current_price,
          params.orders_script_hash,
          close_type,
        )
      UpdateStopLoss(stop_loss_price) ->
        update_stop_loss(transaction, datum, stop_loss_price)
      UpdateTakeProfit(take_profit_price) ->
        update_take_profit(transaction, datum, take_profit_price)
      PayLend(current_price) -> pay_lend(transaction, datum, current_price)
    }
  }

  mint(
    redeemer: PositionsMintRedeemer,
    policy_id: PolicyId,
    transaction: Transaction,
  ) {
    when redeemer is {
      MintPosition(current_price) ->
        mint_position(
          transaction,
          params,
          current_price,
          policy_id,
          params.pool_license,
        )
      BurnPosition(burn_amount, asset_name) -> {
        let mint = (policy_id, asset_name, -burn_amount)
        validate_token_mint(transaction.mint, mint)
      }
    }
  }

  else(_) {
    False
  }
}
