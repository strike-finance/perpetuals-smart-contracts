use aiken/collection/list
use cardano/assets.{quantity_of}
use cardano/transaction.{
  InlineDatum, Output, OutputReference, Transaction, find_input,
  find_script_outputs,
}
use types.{LiquidityPositionDatum, OrdersDatum, WithdrawLiquidity}

validator liquidity_position(orders_validator_hash: ByteArray) {
  spend(
    datum: Option<LiquidityPositionDatum>,
    _redeemer: Int,
    out_ref: OutputReference,
    transaction: Transaction,
  ) {
    expect Some(datum) = datum
    // Signed By Owner, Assets are sent to orders validator, datum values are correct, only one input 
    let signed_by_owner: Bool =
      list.has(transaction.extra_signatories, datum.owner_address_hash)

    expect Some(input_from_script) = find_input(transaction.inputs, out_ref)

    let outputs_to_orders_validator: List<Output> =
      find_script_outputs(transaction.outputs, orders_validator_hash)

    let liquidity_asset_in_input: Int =
      quantity_of(
        input_from_script.output.value,
        datum.liquidity_asset.policy_id,
        datum.liquidity_asset.asset_name,
      )

    expect Some(output_to_orders_validator) =
      list.head(outputs_to_orders_validator)

    let liquidity_asset_in_output: Int =
      quantity_of(
        output_to_orders_validator.value,
        datum.liquidity_asset.policy_id,
        datum.liquidity_asset.asset_name,
      )

    let liquidity_asset_not_spend =
      liquidity_asset_in_input == liquidity_asset_in_output

    expect InlineDatum(output_datum) = output_to_orders_validator.datum

    expect output_datum_typed: OrdersDatum = output_datum

    let output_datum_valid: Bool =
      output_datum_typed.action == WithdrawLiquidity && output_datum_typed.owner_address_hash == datum.owner_address_hash

    signed_by_owner && liquidity_asset_not_spend && output_datum_valid
  }

  else(_) {
    False
  }
}
