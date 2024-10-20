use cardano/assets.{PolicyId}
use cardano/transaction.{OutputReference, Transaction}
use positions_validations.{
  close_position, enter_long_mint, enter_short_mint, liquidate_position,
  pay_lend, stop_loss, take_profit, update_stop_loss, update_take_profit,
}
use types.{
  Burn, Close, Liquidate, MintLong, MintShort, PayLend, PositionDatum,
  PositionsMintRedeemer, PositionsParams, PositionsRedeemer, StopLoss,
  TakeProfit, UpdateStopLoss, UpdateTakeProfit,
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
      Close(current_price) ->
        close_position(
          transaction,
          datum,
          current_price,
          params.orders_script_hash,
        )
      StopLoss(current_price) ->
        stop_loss(transaction, datum, current_price, params.orders_script_hash)
      UpdateStopLoss(stop_loss_price) ->
        update_stop_loss(transaction, datum, stop_loss_price)
      TakeProfit(current_price) ->
        take_profit(
          transaction,
          datum,
          current_price,
          params.orders_script_hash,
        )
      UpdateTakeProfit(take_profit_price) ->
        update_take_profit(transaction, datum, take_profit_price)
      Liquidate(current_price) ->
        liquidate_position(
          transaction,
          datum,
          current_price,
          params.orders_script_hash,
        )
      PayLend(current_price) -> pay_lend(transaction, datum, current_price)
    }
  }

  mint(
    redeemer: PositionsMintRedeemer,
    policy_id: PolicyId,
    transaction: Transaction,
  ) {
    when redeemer is {
      MintLong(current_price) ->
        enter_long_mint(transaction, params, current_price, policy_id)
      MintShort(current_price) ->
        enter_short_mint(transaction, params, current_price, policy_id)
      Burn(burn_amount, asset_name) -> {
        let mint = (policy_id, asset_name, burn_amount)
        validate_token_mint(transaction.mint, mint)
      }
    }
  }

  else(_) {
    False
  }
}
