use aiken/collection/list
use aiken/collection/pairs
use cardano/assets.{match}
use cardano/transaction.{
  InlineDatum, Input, Output, OutputReference, Transaction,
}
use types.{PoolDatum}
use utils.{get_address_outputs, get_all_validators_inputs}

// Global settings script. This script contains UTxO that sets things such as margin requirements, max leverage, borrow rate etc.....
// Checks that the input contains the auth token, and output is send back to the script
validator settings {
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
  mint(
    redeemer: PositionMintRedeemer,
    policy_id: PolicyId,
    transaction: Transaction,
  ) {
    when redeemer is {
      OpenPosition(current_usd_price) ->
        mint_position_valid(transaction, params, current_usd_price, policy_id)
    }
  }

  else(_) {
    False
  }
}
