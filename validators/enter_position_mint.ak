use cardano/assets.{PolicyId}
use cardano/transaction.{Transaction}
use types.{
  BurnLong, BurnShort, EnterPositionParams, MintLong, MintShort,
  PositionsMintRedeemer,
}
use utils.{validate_token_mint}
use validations/enter_position_mint_utils.{enter_long_mint, enter_short_mint}

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
      BurnLong(burn_amount) -> {
        let mint = (policy_id, params.long_asset_name, burn_amount)
        validate_token_mint(transaction.mint, mint)
      }
      BurnShort(burn_amount) -> {
        let mint = (policy_id, params.short_asset_name, burn_amount)
        validate_token_mint(transaction.mint, mint)
      }
    }
  }

  else(_) {
    False
  }
}
