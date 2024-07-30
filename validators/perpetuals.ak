use aiken/list
use aiken/transaction.{
  InlineDatum, Input, Output, ScriptContext, Spend, WithdrawFrom,
  find_script_outputs,
}
use aiken/transaction/credential.{
  Address, Inline, ScriptCredential, from_verification_key,
}
use aiken/transaction/value.{quantity_of}
use types.{ComparePerpetualInfo, PerpetualDatum}
use utils.{
  get_asset_to_address, get_inputs_from_script, get_lower_bound,
  get_validators_inputs,
}

fn get_inputs_from_script_info(
  inputs: List<Input>,
  ctx: ScriptContext,
) -> List<ComparePerpetualInfo> {
  list.foldl(
    inputs,
    [],
    fn(input, inputs_loan) {
      let output: Output = input.output
      expect InlineDatum(perpetual_datum) = output.datum
      expect perpetual_datum_typed: PerpetualDatum = perpetual_datum

      let perpetual_info =
        ComparePerpetualInfo {
          total_ratio_feed: perpetual_datum_typed.total_ratio_feed,
          orcfax_price_feed: perpetual_datum_typed.orcfax_price_feed,
          position_asset: perpetual_datum_typed.position_asset,
          leverage_amount: perpetual_datum_typed.leverage_amount,
          owner_address_hash: perpetual_datum_typed.owner_address_hash,
          owner_bech32_address: perpetual_datum_typed.owner_bech32_address,
          expected_new_round_entry_price: 0,
          expected_new_round_entry_time: 0,
          expected_new_balance: 0,
        }

      [perpetual_info, ..inputs_loan]
    },
  )
}

fn get_outputs_back_to_script_info(
  outputs_back_to_script: List<Output>,
  ctx: ScriptContext,
) -> List<ComparePerpetualInfo> {
  list.filter_map(
    outputs_back_to_script,
    fn(output: Output) {
      expect InlineDatum(collateral_datum) = output.datum
      expect perpetual_datum_typed: PerpetualDatum = collateral_datum

      let output_info_valid = True

      if output_info_valid {
        let perpetual_info =
          ComparePerpetualInfo {
            total_ratio_feed: perpetual_datum_typed.total_ratio_feed,
            orcfax_price_feed: perpetual_datum_typed.orcfax_price_feed,
            position_asset: perpetual_datum_typed.position_asset,
            leverage_amount: perpetual_datum_typed.leverage_amount,
            owner_address_hash: perpetual_datum_typed.owner_address_hash,
            owner_bech32_address: perpetual_datum_typed.owner_bech32_address,
            expected_new_round_entry_price: 0,
            expected_new_round_entry_time: 0,
            expected_new_balance: 0,
          }

        Some(perpetual_info)
      } else {
        None
      }
    },
  )
}

// based on the script, and based on their portportion of the total ratio, subtract or add to their balance
// only after the distribute time
fn validate_update_new_funding_round(
  ctx: ScriptContext,
  perpetual_validator_hash: ByteArray,
) {
  let inputs_from_script: List<Input> =
    get_inputs_from_script(ctx.transaction.inputs, perpetual_validator_hash)

  let outputs_back_to_script: List<Output> =
    find_script_outputs(ctx.transaction.outputs, perpetual_validator_hash)

  let inputs_from_script_info =
    get_inputs_from_script_info(inputs_from_script, ctx)

  let outputs_back_to_script_info =
    get_outputs_back_to_script_info(outputs_back_to_script, ctx)

  let info_difference =
    list.difference(inputs_from_script_info, outputs_back_to_script_info)
  let info_matches = list.length(info_difference) == 0
  let length_matches =
    list.length(inputs_from_script) == list.length(outputs_back_to_script)

  info_matches && length_matches
}

fn validate_close_position(datum: PerpetualDatum, ctx: ScriptContext) {
  expect Spend(my_output_reference) = ctx.purpose
  expect Some(input_from_validator) =
    ctx.transaction.inputs
      |> transaction.find_input(my_output_reference)

  let asset_amount_in_input: Int =
    quantity_of(
      input_from_validator.output.value,
      datum.position_asset.policy_id,
      datum.position_asset.asset_name,
    )

  let issuer_address: Address = from_verification_key(datum.owner_address_hash)
  let fee: Int =
    quantity_of(
      ctx.transaction.fee,
      datum.position_asset.policy_id,
      datum.position_asset.asset_name,
    )

  let amount_to_issuer: Int =
    get_asset_to_address(
      ctx.transaction.outputs,
      issuer_address,
      datum.position_asset.policy_id,
      datum.position_asset.asset_name,
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

validator {
  fn spend(datum: PerpetualDatum, _redeemer: Int, ctx: ScriptContext) -> Bool {
    validate_close_position(datum, ctx)
  }

  fn withdraw(_redeemer: Int, ctx: ScriptContext) {
    expect ScriptContext { transaction: _tx, purpose: WithdrawFrom(stake_cred) } =
      ctx

    expect Inline(ScriptCredential(perpetual_validator_hash)) = stake_cred
    validate_update_new_funding_round(ctx, perpetual_validator_hash)
  }
}
