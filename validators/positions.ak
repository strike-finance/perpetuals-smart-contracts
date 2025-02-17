use cardano/assets.{PolicyId, flatten}
use cardano/transaction.{OutputReference, Transaction}
use positions_validations.{
  close_position_valid, mint_position_valid, update_position_valid,
}
use types.{
  Close, ClosePosition, OpenPosition, PositionDatum, PositionMintRedeemer,
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
      OpenPosition(current_usd_price, open_asset) ->
        mint_position_valid(
          transaction: transaction,
          params: params,
          current_usd_price: current_usd_price,
          policy_id: policy_id,
          open_asset: open_asset,
        )
      // Batcher might close/liquidate multiple positions at once
      ClosePosition(burn_amount, asset_name) -> {
        let expected_burnt = [(policy_id, asset_name, -burn_amount)]
        expected_burnt == flatten(transaction.mint)
      }
    }
  }

  else(_) {
    False
  }
}
