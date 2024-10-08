use aiken/collection/list
use cardano/assets.{PolicyId, quantity_of}
use cardano/transaction.{Transaction, find_script_outputs}
use types.{MintValidPoolParams}
use utils.{validate_token_mint}

validator liquidity_mint(params: MintValidPoolParams) {
  mint(_redeemer: Int, policy_id: PolicyId, transaction: Transaction) {
    let outputs_to_orders_address =
      find_script_outputs(transaction.outputs, params.orders_validator)

    let only_one_output_to_orders = list.length(outputs_to_orders_address) == 1

    expect Some(output_to_orders_validator) =
      list.head(outputs_to_orders_address)

    let pool_asset_deposited_amount =
      quantity_of(
        output_to_orders_validator.value,
        policy_id,
        params.pool_asset_name,
      )

    let expected_mint =
      (policy_id, params.asset_name, pool_asset_deposited_amount)

    let mint_valid = validate_token_mint(transaction.mint, expected_mint)

    let signed_by_admin =
      list.has(transaction.extra_signatories, params.admin_pkh)

    only_one_output_to_orders && mint_valid && signed_by_admin
  }

  else(_) {
    False
  }
}
