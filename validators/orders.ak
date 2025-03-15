use aiken/collection/dict
use aiken/collection/list
use cardano/address.{Credential, Script}
use cardano/assets.{PolicyId, match}
use cardano/transaction.{
  InlineDatum, Input, Output, OutputReference, Transaction,
}
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
    let Transaction { inputs, mint, outputs, .. } = transaction

    expect Script(own_validator) = credential

    let (input_pool_utxo_index, output_pool_utxo_index) =
      redeemer.pool_utxo_index

    expect Some(input_pool_utxo) = list.at(inputs, input_pool_utxo_index)

    expect InlineDatum(input_pool_datum) = input_pool_utxo.output.datum
    expect input_pool_datum_typed: PoolDatum = input_pool_datum

    expect Some(output_pool_utxo) = list.at(outputs, output_pool_utxo_index)

    // UTxO is sent back to the pool
    expect input_pool_utxo.output.address == output_pool_utxo.address

    // The functions checks the inputs and its corresponding outputs. Making sure of things such as liquidity providers that withdraw liquidity get their tokens
    // It also computes the expected pool output and datum. We then compare the expected pool output with the actual pool output to make sure the pool is in sync with the orders
    let expected_pool_output =
      valid_orders(
        redeemer.indexer,
        transaction,
        own_validator,
        input_pool_utxo.output.value,
        input_pool_datum_typed,
        burn_address,
      )

    expect match(output_pool_utxo.value, expected_pool_output.value, >=)

    expect InlineDatum(output_pool_datum) = output_pool_utxo.datum
    expect output_pool_datum_typed: PoolDatum = output_pool_datum

    expect expected_pool_output.datum == output_pool_datum_typed

    expect expected_pool_output.mint == mint

    // Make sure the batcher license is in the inputs
    expect Some(Input { output: Output { value: batcher_value, .. }, .. }) =
      list.at(inputs, redeemer.batcher_index)

    expect [Pair(_tn, amount)] =
      batcher_value
        |> assets.tokens(batcher_license)
        |> dict.to_pairs()

    amount == 1
  }

  else(_) {
    fail
  }
}
