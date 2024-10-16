use aiken/collection/list
use cardano/transaction.{
  InlineDatum, OutputReference, Transaction, find_script_outputs,
}
use types.{
  LiquidityPositionDatum, OrdersDatum, ProcessWithdrawLiquidityOrder, ScriptHash,
}

// Users liquidity positions are held here. When they want to withdraw their liquidity, they will spend from this script and send to the orders
// validator for processing
validator liquidity_position(orders_script_hash: ScriptHash) {
  spend(
    datum: Option<LiquidityPositionDatum>,
    _redeemer: Int,
    _out_ref: OutputReference,
    transaction: Transaction,
  ) {
    expect Some(datum) = datum

    let outputs_to_orders_address =
      find_script_outputs(transaction.outputs, orders_script_hash)

    let only_one_output_to_orders = list.length(outputs_to_orders_address) == 1

    expect Some(output_to_orders_validator) =
      list.head(outputs_to_orders_address)

    expect InlineDatum(orders_datum) = output_to_orders_validator.datum

    expect orders_datum_typed: OrdersDatum = orders_datum

    let action_valid =
      orders_datum_typed.action == ProcessWithdrawLiquidityOrder

    let earnings_per_share_valid =
      orders_datum_typed.entered_earnings_per_share == datum.entered_earnings_per_share && orders_datum_typed.entered_collateral_earnings_per_share == datum.entered_collateral_earnings_per_share

    let signed_by_owner =
      list.has(transaction.extra_signatories, datum.owner_address_hash)

    only_one_output_to_orders && signed_by_owner && action_valid && earnings_per_share_valid
  }

  else(_) {
    False
  }
}
