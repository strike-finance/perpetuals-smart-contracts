use aiken/collection/list
use cardano/transaction.{
  InlineDatum, OutputReference, Transaction, find_script_outputs,
}
use types.{FundPeriodDatum}
use utils.{
  get_lower_bound, get_validators_inputs, new_funding_period_datum_valid,
  own_validator_script_address_hash,
}

// This validator handles the logic of funding periods. It reallocates the losing sides postions to the winning sides positions every funding period. 
// Can only update funding round. Right now the redeemer is the new updated price. Change logic to use oracle for price
validator funding_period {
  spend(
    datum: Option<FundPeriodDatum>,
    redeemer: Int,
    own_ref: OutputReference,
    transaction: Transaction,
  ) {
    expect Some(datum) = datum

    expect Some(validator_hash) =
      own_validator_script_address_hash(transaction.inputs, own_ref)

    let outputs_back_to_validator =
      find_script_outputs(transaction.outputs, validator_hash)

    let validators_inputs = get_validators_inputs(transaction, validator_hash)

    let only_one_input_and_output =
      list.length(outputs_back_to_validator) == 1 && list.length(
        validators_inputs,
      ) == 1

    expect Some(output_back_to_validator) = list.head(outputs_back_to_validator)

    expect InlineDatum(output_back_to_validator_datum) =
      output_back_to_validator.datum

    expect output_back_to_validator_typed: FundPeriodDatum =
      output_back_to_validator_datum

    // Only after 50 Minutes can this be updated
    let valid_time = datum.start_time + 3_000_000

    let current_transaction_time_valid =
      get_lower_bound(transaction.validity_range) >= valid_time

    let new_datum_valid =
      new_funding_period_datum_valid(
        datum,
        output_back_to_validator_typed,
        redeemer,
      )

    only_one_input_and_output && current_transaction_time_valid && new_datum_valid
  }

  else(_) {
    False
  }
}
