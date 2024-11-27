use cardano/assets.{PolicyId, flatten}
use cardano/transaction.{OutputReference, Transaction}
use positions_validations.{
  close_position_valid, mint_position_valid, update_position_valid,
}
use types.{
  BurnPosition, Close, MintPosition, PositionDatum, PositionMintRedeemer,
  PositionRedeemer, PositionUpdate, PositionsParams,
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
          close_type,
          params,
        )
      PositionUpdate(update_type, update_price) ->
        update_position_valid(transaction, datum, update_type, update_price)
    }
  }

  mint(
    redeemer: PositionMintRedeemer,
    policy_id: PolicyId,
    transaction: Transaction,
  ) {
    when redeemer is {
      MintPosition(current_usd_price) ->
        mint_position_valid(transaction, params, current_usd_price, policy_id)
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
