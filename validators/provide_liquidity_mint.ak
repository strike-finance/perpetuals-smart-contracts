use aiken/collection/list
use cardano/assets.{PolicyId, quantity_of}
use cardano/transaction.{InlineDatum, Transaction, find_script_outputs}
use types.{OrdersDatum, ProvideLiquidity, ProvideLiquidityMintParams}
use utils.{validate_token_mint}

// when user wants to provide liquidity, they will mint assets and sent it to the orders validator for processing
validator provide_liquidity_mint(params: ProvideLiquidityMintParams) {
  mint(_redeemer: Int, policy_id: PolicyId, transaction: Transaction) {
    let outputs_to_orders_address =
      find_script_outputs(transaction.outputs, params.orders_validator)

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

    let mint_valid: Bool = validate_token_mint(transaction.mint, expected_mint)

    let action_valid = orders_datum_typed.action == ProvideLiquidity

    only_one_output_to_orders && mint_valid && action_valid
  }

  else(_) {
    False
  }
}
