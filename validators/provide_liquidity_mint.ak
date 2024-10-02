use aiken/collection/list
use cardano/assets.{PolicyId, quantity_of}
use cardano/transaction.{Transaction, find_script_outputs}
use utils.{validate_token_mint}

validator pools_mint(
  orders_validator: ByteArray,
  asset_name: ByteArray,
  pool_asset_policy_id: PolicyId,
  pool_asset_name: ByteArray,
) {
  mint(_redeemer: Int, policy_id: PolicyId, transaction: Transaction) {
    let outputs_to_orders_address =
      find_script_outputs(transaction.outputs, orders_validator)

    let only_one_output_to_orders = list.length(outputs_to_orders_address) == 1

    expect Some(output_to_orders_validator) =
      list.head(outputs_to_orders_address)

    let pool_asset_deposited_amount =
      quantity_of(
        output_to_orders_validator.value,
        pool_asset_policy_id,
        pool_asset_name,
      )

    let expected_mint = (policy_id, asset_name, pool_asset_deposited_amount)

    let mint_valid = validate_token_mint(transaction.mint, expected_mint)

    only_one_output_to_orders && mint_valid
  }

  else(_) {
    False
  }
}
