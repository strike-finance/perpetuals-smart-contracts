use aiken/transaction.{Mint, Output, ScriptContext, Transaction}
use aiken/transaction/value.{from_minted_value, quantity_of}
use types.{PerpetualDatum}
use utils.{
  get_lower_bound, get_output_to_validator, get_perpetual_datum, get_upper_bound,
}

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

    let lower_bound: Int = get_lower_bound(ctx.transaction.validity_range)
    let upper_bound: Int = get_upper_bound(ctx.transaction.validity_range)

    let minted_asset_in_utxo: Int =
      quantity_of(output_to_validator.value, policy_id, token_name)

    let entry_time_valid: Bool =
      perpetual_datum.entry_time >= lower_bound && perpetual_datum.entry_time <= upper_bound

    let minted_asset_valid: Bool =
      mints_quantity == perpetual_asset_in_output && minted_asset_in_utxo == perpetual_asset_in_output

    let redeem_asset_in_datum_valid: Bool =
      perpetual_datum.redeem_asset.policy_id == policy_id && perpetual_datum.redeem_asset.asset_name == token_name

    redeem_asset_in_datum_valid && minted_asset_valid && entry_time_valid
  }
}
