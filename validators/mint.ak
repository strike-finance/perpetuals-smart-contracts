use aiken/transaction.{Mint, Output, ScriptContext, Transaction}
use aiken/transaction/value.{from_minted_value, quantity_of}
use types.{PerpetualDatum}
use utils.{get_output_to_validator, get_perpetual_datum}

validator(token_name: ByteArray, perpetual_validator_hash: ByteArray) {
  fn mint(_redeemer: Int, ctx: ScriptContext) -> Bool {
    let ScriptContext { transaction, purpose } = ctx
    expect Mint(policy_id) = purpose
    let Transaction { mint, .. } = transaction

    let mints_quantity =
      quantity_of(from_minted_value(mint), policy_id, token_name)

    let output_to_validator: Output =
      get_output_to_validator(ctx.transaction.outputs, perpetual_validator_hash)

    let perpetual_datum: PerpetualDatum =
      get_perpetual_datum(output_to_validator)

    let perpetual_asset_in_output: Int =
      quantity_of(
        output_to_validator.value,
        perpetual_datum.position_asset.policy_id,
        perpetual_datum.position_asset.asset_name,
      )

    mints_quantity == perpetual_asset_in_output
  }
}
