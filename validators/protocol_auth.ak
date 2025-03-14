use aiken/collection/list
use cardano/assets.{AssetName, flatten}
use cardano/transaction.{OutputReference, Transaction}

// Auth token is used to update the protocol params and batcher license
// Can only be minted by the protocol manager once
validator protocol_authtoken_mp(seed: OutputReference, asset_name: AssetName) {
  mint(_redeemer: Data, policy_id: ByteArray, self: Transaction) {
    let Transaction { inputs, mint, .. } = self
    expect
      list.any(
        inputs,
        fn(inp) { inp.output_reference.transaction_id == seed.transaction_id },
      )

    [(policy_id, asset_name, 1)] == flatten(mint)
  }

  else(_) {
    fail
  }
}
