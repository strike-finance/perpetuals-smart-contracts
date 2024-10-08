use cardano/assets.{PolicyId, quantity_of}
use cardano/transaction.{Transaction}
use validations/enter_position_mint_utils.{enter_long_mint, enter_short_mint}
use types.{
  BurnLong, BurnShort, EnterPositionParams, MintLong, MintShort,
  PositionsMintRedeemer,
}

validator enter_position_mint(params: EnterPositionParams) {
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
      BurnLong -> {
        let mint_amount: Int =
          quantity_of(transaction.mint, policy_id, params.long_asset_name)
        mint_amount < 0
      }
      BurnShort -> {
        let mint_amount: Int =
          quantity_of(transaction.mint, policy_id, params.short_asset_name)
        mint_amount < 0
      }
    }
  }

  else(_) {
    False
  }
}
