use aiken/list
use aiken/transaction.{
  Input, Output, ScriptContext, Spend, WithdrawFrom, find_script_outputs,
}
use aiken/transaction/credential.{
  Address, Inline, ScriptCredential, from_verification_key,
}
use aiken/transaction/value.{quantity_of}
use types.{ComparePerpetualInfo, PerpetualDatum}
use utils.{
  calculate_total_expected_funds_to_distribute, get_asset_to_address,
  get_inputs_from_script, get_inputs_from_script_info, get_lower_bound,
  get_outputs_back_to_script_info, get_validators_inputs,
}

// based on the script, and based on their portportion of the total ratio, subtract or add to their balance
// only after the distribute time
fn validate_update_new_funding_round(
  ctx: ScriptContext,
  perpetual_validator_hash: ByteArray,
  distribute_validator_hash: ByteArray,
  policy_id: ByteArray,
  asset_name: ByteArray,
) {
  let inputs_from_script: List<Input> =
    get_inputs_from_script(ctx.transaction.inputs, perpetual_validator_hash)

  let outputs_back_to_script: List<Output> =
    find_script_outputs(ctx.transaction.outputs, perpetual_validator_hash)

  let inputs_from_script_info: List<ComparePerpetualInfo> =
    get_inputs_from_script_info(inputs_from_script, ctx, policy_id, asset_name)

  let outputs_back_to_script_info: List<ComparePerpetualInfo> =
    get_outputs_back_to_script_info(
      outputs_back_to_script,
      ctx,
      policy_id,
      asset_name,
    )

  let output_to_distribute =
    find_script_outputs(ctx.transaction.outputs, distribute_validator_hash)

  expect Some(output_to_distribute) = list.head(output_to_distribute)

  let expected_total_funds_to_distribute =
    calculate_total_expected_funds_to_distribute(inputs_from_script_info)

  let total_funds_to_distribute_validator =
    quantity_of(output_to_distribute.value, policy_id, asset_name)

  let total_expected_funds_to_distribute_valid =
    expected_total_funds_to_distribute == total_funds_to_distribute_validator

  let info_difference =
    list.difference(inputs_from_script_info, outputs_back_to_script_info)
  let info_matches = list.length(info_difference) == 0
  let length_matches =
    list.length(inputs_from_script) == list.length(outputs_back_to_script)

  info_matches && length_matches && total_expected_funds_to_distribute_valid
}

fn validate_close_position(
  datum: PerpetualDatum,
  ctx: ScriptContext,
  policy_id: ByteArray,
  asset_name: ByteArray,
) {
  expect Spend(my_output_reference) = ctx.purpose
  expect Some(input_from_validator) =
    ctx.transaction.inputs
      |> transaction.find_input(my_output_reference)

  let asset_amount_in_input: Int =
    quantity_of(input_from_validator.output.value, policy_id, asset_name)

  let issuer_address: Address = from_verification_key(datum.owner_address_hash)
  let fee: Int = quantity_of(ctx.transaction.fee, policy_id, asset_name)

  let amount_to_issuer: Int =
    get_asset_to_address(
      ctx.transaction.outputs,
      issuer_address,
      policy_id,
      asset_name,
    )

  let amount_to_owner_valid: Bool =
    asset_amount_in_input - fee == amount_to_issuer

  let only_one_validator_input: Bool =
    list.length(get_validators_inputs(ctx)) == 1

  let must_be_signed_by_owner =
    list.has(ctx.transaction.extra_signatories, datum.owner_address_hash)

  let before_distribute_fund =
    datum.current_funding_round_distribute_time > get_lower_bound(
      ctx.transaction.validity_range,
    )

  ( amount_to_owner_valid || must_be_signed_by_owner ) && only_one_validator_input && before_distribute_fund
}

validator(
  distribute_validator_hash: ByteArray,
  policy_id: ByteArray,
  asset_name: ByteArray,
) {
  fn spend(datum: PerpetualDatum, _redeemer: Int, ctx: ScriptContext) -> Bool {
    validate_close_position(datum, ctx, policy_id, asset_name)
  }

  fn withdraw(_redeemer: Int, ctx: ScriptContext) {
    expect ScriptContext { transaction: _tx, purpose: WithdrawFrom(stake_cred) } =
      ctx

    expect Inline(ScriptCredential(perpetual_validator_hash)) = stake_cred
    validate_update_new_funding_round(
      ctx,
      perpetual_validator_hash,
      distribute_validator_hash,
      policy_id,
      asset_name,
    )
  }
}
