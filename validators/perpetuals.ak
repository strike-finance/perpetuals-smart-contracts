use aiken/list
use aiken/transaction.{
  Input, Output, ScriptContext, Spend, WithdrawFrom, find_script_outputs,
}
use aiken/transaction/credential.{
  Address, Inline, ScriptCredential, from_verification_key,
}
use aiken/transaction/value.{PolicyId, from_minted_value, quantity_of}
use types.{ComparePerpetualInfo, DistributeDatum, PerpetualDatum}
use utils.{
  calculate_total_expected_funds_to_distribute, get_asset_to_address,
  get_distribute_datum, get_inputs_from_script, get_inputs_from_script_info,
  get_lower_bound, get_output_to_distribute_ratio_policy,
  get_output_to_validator, get_outputs_back_to_script_info,
  get_validators_inputs, validate_token_mint,
}

type PerpetualRedeemer {
  UpdateFundingRound
  CollectRewards
}

type Redeemer {
  action: PerpetualRedeemer,
}

// based on the script, and based on their portportion of the total ratio, subtract or add to their balance
// only after the distribute time
fn validate_update_new_funding_round(
  ctx: ScriptContext,
  perpetual_validator_hash: ByteArray,
  distribute_validator_hash: ByteArray,
  asset_policy_id: ByteArray,
  asset_name: ByteArray,
) {
  let inputs_from_script: List<Input> =
    get_inputs_from_script(ctx.transaction.inputs, perpetual_validator_hash)

  let outputs_back_to_script: List<Output> =
    find_script_outputs(ctx.transaction.outputs, perpetual_validator_hash)

  let inputs_from_script_info: List<ComparePerpetualInfo> =
    get_inputs_from_script_info(
      inputs_from_script,
      ctx,
      asset_policy_id,
      asset_name,
    )

  let outputs_back_to_script_info: List<ComparePerpetualInfo> =
    get_outputs_back_to_script_info(
      outputs_back_to_script,
      ctx,
      asset_policy_id,
      asset_name,
    )

  let output_to_distribute_validator: Output =
    get_output_to_validator(ctx.transaction.outputs, distribute_validator_hash)

  let distribute_datum: DistributeDatum =
    get_distribute_datum(output_to_distribute_validator)

  let output_to_distribute_ratio_policy: PolicyId =
    get_output_to_distribute_ratio_policy(output_to_distribute_validator)

  let expected_total_funds_to_distribute: Int =
    calculate_total_expected_funds_to_distribute(inputs_from_script_info)

  let total_funds_to_distribute_validator: Int =
    quantity_of(
      output_to_distribute_validator.value,
      asset_policy_id,
      asset_name,
    )

  let redeem_asset_to_distribute_validator: Int =
    quantity_of(
      output_to_distribute_validator.value,
      distribute_datum.redeem_asset.policy_id,
      distribute_datum.redeem_asset.asset_name,
    )

  let info_difference: List<ComparePerpetualInfo> =
    list.difference(inputs_from_script_info, outputs_back_to_script_info)

  let ratio_policy_not_altered: Bool =
    list.all(
      outputs_back_to_script_info,
      fn(info: ComparePerpetualInfo) -> Bool {
        info.total_ratio_feed == output_to_distribute_ratio_policy
      },
    )

  let total_expected_funds_to_distribute_valid: Bool =
    expected_total_funds_to_distribute == total_funds_to_distribute_validator

  let info_matches: Bool = list.length(info_difference) == 0

  let inputs_outputs_length_matches: Bool =
    list.length(inputs_from_script) == list.length(outputs_back_to_script)

  let redeem_asset_in_distribute_utxo_valid =
    redeem_asset_to_distribute_validator == expected_total_funds_to_distribute

  info_matches && inputs_outputs_length_matches && total_expected_funds_to_distribute_valid && ratio_policy_not_altered && redeem_asset_in_distribute_utxo_valid
}

fn validate_collect_rewards(
  ctx: ScriptContext,
  perpetual_validator_hash: ByteArray,
) {
  let inputs_from_validator: List<Input> =
    get_inputs_from_script(ctx.transaction.inputs, perpetual_validator_hash)

  let outputs_back_to_script: List<Output> =
    find_script_outputs(ctx.transaction.outputs, perpetual_validator_hash)

  let inputs_and_outputs_length_match: Bool =
    list.length(inputs_from_validator) == list.length(outputs_back_to_script)

  inputs_and_outputs_length_match
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

  let must_be_signed_by_owner: Bool =
    list.has(ctx.transaction.extra_signatories, datum.owner_address_hash)

  let before_distribute_fund: Bool =
    datum.distribute_time > get_lower_bound(ctx.transaction.validity_range)

  let one_hour_after_distribute_time: Bool =
    get_lower_bound(ctx.transaction.validity_range) + 3_600_000 > datum.distribute_time

  let token_burnt_valid: Bool =
    validate_token_mint(
      from_minted_value(ctx.transaction.mint),
      (
        datum.redeem_asset.policy_id,
        datum.redeem_asset.asset_name,
        asset_amount_in_input,
      ),
    )

  ( amount_to_owner_valid || must_be_signed_by_owner ) && (
    before_distribute_fund || one_hour_after_distribute_time
  ) && only_one_validator_input && token_burnt_valid
}

validator(
  distribute_validator_hash: ByteArray,
  asset_policy_id: ByteArray,
  asset_name: ByteArray,
) {
  fn spend(datum: PerpetualDatum, _redeemer: Int, ctx: ScriptContext) -> Bool {
    validate_close_position(datum, ctx, asset_policy_id, asset_name)
  }

  fn withdraw(redeemer: Redeemer, ctx: ScriptContext) -> Bool {
    expect ScriptContext { transaction: _tx, purpose: WithdrawFrom(stake_cred) } =
      ctx

    expect Inline(ScriptCredential(perpetual_validator_hash)) = stake_cred

    when redeemer.action is {
      UpdateFundingRound ->
        validate_update_new_funding_round(
          ctx,
          perpetual_validator_hash,
          distribute_validator_hash,
          asset_policy_id,
          asset_name,
        )
      CollectRewards -> validate_collect_rewards(ctx, perpetual_validator_hash)
    }
  }
}
