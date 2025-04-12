use aiken/collection/dict
use aiken/collection/list
use aiken/interval
use aiken/primitive/string
use cardano/address.{from_verification_key}
use cardano/assets.{PolicyId}
use cardano/transaction.{Input, NoDatum, Output, OutputReference, Transaction}

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

test protocol_authtoken_mp_success() {
  let own_ref =
    OutputReference {
      transaction_id: #"b4971034feee28d07f157faf99b850f856d8da3494c70b19b521cfe690258e26",
      output_index: 0,
    }
  let seed_input =
    Input {
      output_reference: own_ref,
      output: Output {
        address: from_verification_key(#""),
        value: assets.from_lovelace(2_000_000),
        datum: NoDatum,
        reference_script: None,
      },
    }
  let own_policy_id =
    #"282ba2d9a72501e3816ee9682db80703b121826a93d7fd646e87a629"
  let mint =
    assets.from_asset(
      own_policy_id,
      string.to_bytearray(@"PROTOCOL_MANAGER_NFT"),
      1,
    )
      |> assets.add(
          own_policy_id,
          string.to_bytearray(@"PROTOCOL_SETTINGS_NFT"),
          1,
        )
      |> assets.add(own_policy_id, string.to_bytearray(@"PROTOCOL_POOL_NFT"), 1)
  let tx =
    Transaction {
      inputs: [seed_input],
      reference_inputs: [],
      outputs: [],
      fee: 0,
      mint,
      certificates: [],
      withdrawals: [],
      validity_range: interval.everything,
      extra_signatories: [],
      redeemers: [],
      datums: dict.empty,
      id: #"0000000000000000000000000000000000000000000000000000000000000000",
      votes: [],
      proposal_procedures: [],
      current_treasury_amount: None,
      treasury_donation: None,
    }
  protocol_auth.mint(own_ref, 1, own_policy_id, tx)
}
