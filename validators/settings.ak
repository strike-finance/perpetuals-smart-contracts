use aiken/collection/list
use cardano/assets.{AssetName, PolicyId, flatten, match}
use cardano/transaction.{Input, Output, OutputReference, Transaction}
use types.{PoolDatum}
use utils.{get_address_outputs, get_all_validators_inputs}

pub type SettingsRedeemer {
  UpdateInterestRate { interest_rate: Int }
  UpdateLiquidateMargin { maintain_margin_amount: Int }
  UpdateMaxLeverageFactor { max_leverage_factor: Int }
  UpdateMaxStrikeHolderLeverageFactor { max_strike_holder_leverage_factor: Int }
}

// Global settings script. This script contains UTxO that sets things such as margin requirements, max leverage, borrow rate etc.....
// Checks that the input contains the auth token, and output is send back to the script
validator settings(seed: OutputReference, asset_name: AssetName) {
  spend(
    _datum: Option<PoolDatum>,
    _redeemer: Int,
    _own_ref: OutputReference,
    transaction: Transaction,
  ) {
    let inputs_from_scripts: List<Input> =
      get_all_validators_inputs(transaction)

    expect list.length(inputs_from_scripts) == 1

    expect Some(input_from_script) = list.head(inputs_from_scripts)

    let outputs_back_to_pools_validator: List<Output> =
      get_address_outputs(transaction, input_from_script.output.address)

    expect Some(output_to_pools_validator) =
      list.head(outputs_back_to_pools_validator)

    match(output_to_pools_validator.value, input_from_script.output.value, >=)
  }

  // Mints a token and sends back to script. Token verifies that this is the correct global settings UTxO
  // Is only minted once, and is sent back to the script 
  mint(_redeemer: Int, policy_id: PolicyId, transaction: Transaction) {
    let Transaction { inputs, mint, .. } = transaction
    expect
      list.any(
        inputs,
        fn(inp) { inp.output_reference.transaction_id == seed.transaction_id },
      )

    [(policy_id, asset_name, 1)] == flatten(mint)
  }

  else(_) {
    False
  }
}
