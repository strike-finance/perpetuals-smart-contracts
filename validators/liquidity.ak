use aiken/collection/list
use cardano/assets.{PolicyId, quantity_of}
use cardano/transaction.{
  InlineDatum, OutputReference, Transaction, find_script_outputs,
}
use types.{
  BurnLiquidity, LiquidityMintsRedeemer, LiquidityParams, LiquidityPositionDatum,
  LiquidityRedeemer, MintLiquidity, OrdersDatum, ProvideLiquidityOrder,
  WithdrawLiquidityOrder,
}
use utils.{validate_token_mint}

validator liquidity(params: LiquidityParams) {
  spend(
    datum: Option<LiquidityPositionDatum>,
    _redeemer: LiquidityRedeemer,
    _out_ref: OutputReference,
    transaction: Transaction,
  ) {
    expect Some(datum) = datum

    let outputs_to_orders_address =
      find_script_outputs(transaction.outputs, params.orders_script_hash)

    let only_one_output_to_orders = list.length(outputs_to_orders_address) == 1

    expect Some(output_to_orders_validator) =
      list.head(outputs_to_orders_address)

    expect InlineDatum(orders_datum) = output_to_orders_validator.datum

    expect orders_datum_typed: OrdersDatum = orders_datum

    let action_valid = orders_datum_typed.action == WithdrawLiquidityOrder

    let earnings_per_share_valid =
      orders_datum_typed.entered_earnings_per_share == datum.entered_earnings_per_share && orders_datum_typed.entered_collateral_earnings_per_share == datum.entered_collateral_earnings_per_share

    let signed_by_owner =
      list.has(transaction.extra_signatories, datum.owner_address_hash)

    only_one_output_to_orders && signed_by_owner && action_valid && earnings_per_share_valid
  }

  mint(
    redeemer: LiquidityMintsRedeemer,
    policy_id: PolicyId,
    transaction: Transaction,
  ) {
    when redeemer is {
      MintLiquidity -> {
        let outputs_to_orders_address =
          find_script_outputs(transaction.outputs, params.orders_script_hash)

        let only_one_output_to_orders: Bool =
          list.length(outputs_to_orders_address) == 1

        expect Some(output_to_orders_validator) =
          list.head(outputs_to_orders_address)

        expect InlineDatum(orders_datum) = output_to_orders_validator.datum

        expect orders_datum_typed: OrdersDatum = orders_datum

        let pool_asset_deposited_amount: Int =
          quantity_of(
            output_to_orders_validator.value,
            params.provided_asset_policy_id,
            params.provided_asset_name,
          )

        let expected_mint =
          (policy_id, params.asset_name, pool_asset_deposited_amount)

        let mint_valid: Bool =
          validate_token_mint(transaction.mint, expected_mint)
        let action_valid = orders_datum_typed.action == ProvideLiquidityOrder

        only_one_output_to_orders && mint_valid && action_valid
      }
      BurnLiquidity(burn_amount) -> {
        let mint = (policy_id, params.asset_name, burn_amount)
        validate_token_mint(transaction.mint, mint)
      }
    }
  }

  else(_) {
    False
  }
}
