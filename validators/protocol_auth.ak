use aiken/collection/dict
use aiken/collection/list
use aiken/primitive/string
use cardano/assets.{PolicyId}
use cardano/transaction.{Input, OutputReference, Transaction}

validator protocol_auth(seed: OutputReference) {
  mint(_redeemer: Data, policy_id: PolicyId, self: Transaction) {
    let Transaction { inputs, mint, .. } = self
    expect
      list.any(
        inputs,
        fn(inp) { inp.output_reference.transaction_id == seed.transaction_id },
      )
    expect [
      Pair(token_name, amount), Pair(token_name1, amount1),
      Pair(token_name2, amount2),
    ] =
      mint
        |> assets.tokens(policy_id)
        |> dict.to_pairs()

    expect
      token_name == string.to_bytearray(@"PROTOCOL_MANAGER_NFT") && amount == 1

    expect
      token_name1 == string.to_bytearray(@"PROTOCOL_POOL_NFT") && amount1 == 1

    token_name2 == string.to_bytearray(@"PROTOCOL_SETTINGS_NFT") && amount2 == 1
  }

  else(_) {
    False
  }
}
