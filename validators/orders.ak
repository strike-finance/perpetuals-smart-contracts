use aiken/collection/list
use cardano/address.{Credential, Script}
use cardano/assets.{PolicyId, match}
use cardano/transaction.{InlineDatum, Input, OutputReference, Transaction}
use orders_validations.{valid_orders}
use types.{
  ClosePendingOpenOrders, OrderDatum, OrdersRedeemer, PoolDatum, ProcessOrders,
  ScriptHash, UTxOIndexer,
}
use utils.{is_withdrawal}

pub type OrdersWithdrawRedeemer {
  indexer: UTxOIndexer,
  pool_utxo_index: (Int, Int),
  batcher_index: Int,
}

validator orders(batcher_license: PolicyId, burn_address: ScriptHash) {
  spend(
    _datum: Option<OrderDatum>,
    redeemer: OrdersRedeemer,
    own_ref: OutputReference,
    transaction: Transaction,
  ) {
    when redeemer is {
      ProcessOrders -> is_withdrawal(transaction, own_ref)
      ClosePendingOpenOrders -> is_withdrawal(transaction, own_ref)
    }
  }

  withdraw(
    redeemer: OrdersWithdrawRedeemer,
    credential: Credential,
    transaction: Transaction,
  ) {
    expect Script(own_validator) = credential

    let (input_pool_utxo_index, output_pool_utxo_index) =
      redeemer.pool_utxo_index

    expect Some(input_pool_utxo) =
      list.at(transaction.inputs, input_pool_utxo_index)

    expect InlineDatum(input_pool_datum) = input_pool_utxo.output.datum
    expect input_pool_datum_typed: PoolDatum = input_pool_datum

    let expected_pool_output =
      valid_orders(
        redeemer.indexer,
        transaction,
        own_validator,
        input_pool_utxo.output.value,
        input_pool_datum_typed,
        burn_address,
      )

    expect Some(output_pool_utxo) =
      list.at(transaction.outputs, output_pool_utxo_index)

    let value_valid =
      match(output_pool_utxo.value, expected_pool_output.value, >=)

    expect InlineDatum(output_pool_datum) = output_pool_utxo.datum
    expect output_pool_datum_typed: PoolDatum = output_pool_datum

    let output_datum_valid =
      expected_pool_output.datum == output_pool_datum_typed

    let address_valid =
      input_pool_utxo.output.address == output_pool_utxo.address

    let expected_mint_valid = expected_pool_output.mint == transaction.mint

    value_valid && output_datum_valid && address_valid && expected_mint_valid
  }

  else(_) {
    fail
  }
}
