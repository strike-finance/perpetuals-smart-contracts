use aiken/collection/list
use cardano/assets.{PolicyId, quantity_of}
use cardano/transaction.{Transaction, find_script_outputs}
use types.{Burn, Mint, PositionsMintRedeemer}
use utils.{validate_token_mint}

validator enter_positions_mint(
  orders_validator: ByteArray,
  asset_name: ByteArray,
  position_asset_policy_id: PolicyId,
  position_asset_name: ByteArray,
) {
  mint(
    redeemer: PositionsMintRedeemer,
    policy_id: PolicyId,
    transaction: Transaction,
  ) {
    when redeemer is {
      Mint -> {
        let outputs_to_orders_address =
          find_script_outputs(transaction.outputs, orders_validator)

        let only_one_output_to_orders =
          list.length(outputs_to_orders_address) == 1

        expect Some(output_to_orders_validator) =
          list.head(outputs_to_orders_address)

        let position_asset_deposited_amount =
          quantity_of(
            output_to_orders_validator.value,
            position_asset_policy_id,
            position_asset_name,
          )

        let expected_mint =
          (policy_id, asset_name, position_asset_deposited_amount)

        let mint_valid = validate_token_mint(transaction.mint, expected_mint)

        only_one_output_to_orders && mint_valid
      }
      Burn -> True
    }
  }

  else(_) {
    False
  }
}
