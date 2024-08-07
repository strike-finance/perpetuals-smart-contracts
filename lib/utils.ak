use aiken/interval.{Finite}
use aiken/list
use aiken/transaction.{
  InlineDatum, Input, Output, ScriptContext, ValidityRange, find_script_outputs,
}
use aiken/transaction/credential.{
  Address, Credential, ScriptCredential, VerificationKeyCredential,
}
use aiken/transaction/value.{AssetName, PolicyId, policies, quantity_of}
use types.{ComparePerpetualInfo, DistributeDatum, PerpetualDatum, RationalDatum}

pub fn get_lower_bound(range: ValidityRange) -> Int {
  expect Finite(lower_bound) = range.lower_bound.bound_type
  lower_bound
}

pub fn get_asset_to_address(
  outputs: List<Output>,
  address: Address,
  policy_id: PolicyId,
  asset_name: AssetName,
) -> Int {
  let output_to_address =
    list.find(
      outputs,
      fn(output) {
        output.address.payment_credential == address.payment_credential
      },
    )

  when output_to_address is {
    Some(output) -> quantity_of(output.value, policy_id, asset_name)
    None -> 0
  }
}

pub fn get_validators_inputs(ctx: ScriptContext) -> List<Input> {
  list.filter(
    ctx.transaction.inputs,
    fn(input) { is_script_credential(input.output.address.payment_credential) },
  )
}

pub fn is_script_credential(credential: Credential) -> Bool {
  when credential is {
    ScriptCredential(_validator_hash) -> True
    _ -> False
  }
}

pub fn get_inputs_from_script(
  inputs: List<Input>,
  script_hash: ByteArray,
) -> List<Input> {
  inputs
    |> list.filter(
        fn(input) {
          when input.output.address.payment_credential is {
            ScriptCredential(addr_script_hash) ->
              script_hash == addr_script_hash
            VerificationKeyCredential(_) -> False
          }
        },
      )
}

pub fn calculate_total_expected_funds_to_distribute(
  perpetual_info: List<ComparePerpetualInfo>,
) -> Int {
  list.foldl(
    perpetual_info,
    0,
    fn(info, acc) { acc + info.funds_to_distribute },
  )
}

pub fn get_orcfax_price(ctx: ScriptContext, datum: PerpetualDatum) -> Int {
  let fsp_script_token_name = #"000de140"
  // find the fsp token utxo
  expect Some(orc_fsp_token_utxo) =
    list.find(
      ctx.transaction.reference_inputs,
      fn(input) {
        list.has(policies(input.output.value), datum.orcfax_price_feed)
      },
    )

  expect InlineDatum(orc_fsp_hash) = orc_fsp_token_utxo.output.datum
  expect orc_fsp_hash_datum: ByteArray = orc_fsp_hash

  // find the fs utxo
  expect Some(orc_fs_utxo) =
    list.find(
      ctx.transaction.reference_inputs,
      fn(input) {
        value.quantity_of(
          input.output.value,
          orc_fsp_hash_datum,
          fsp_script_token_name,
        ) == 1
      },
    )
  expect InlineDatum(rational_datum) = orc_fs_utxo.output.datum
  expect rational_datum_typed: RationalDatum = rational_datum

  rational_datum_typed.numerator / rational_datum_typed.denominator
}

fn calculate_perpetual_info(
  ctx: ScriptContext,
  datum: PerpetualDatum,
  asset_amount: Int,
) -> ComparePerpetualInfo {
  let price = get_orcfax_price(ctx, datum)

  let price_percentage_difference = price / datum.entry_price - 1

  let funds_send_to_distribute = asset_amount * price_percentage_difference

  ComparePerpetualInfo {
    total_ratio_feed: datum.total_ratio_feed,
    orcfax_price_feed: datum.orcfax_price_feed,
    leverage_amount: datum.leverage_amount,
    owner_address_hash: datum.owner_address_hash,
    owner_bech32_address: datum.owner_bech32_address,
    new_balance: asset_amount - funds_send_to_distribute,
    funds_to_distribute: funds_send_to_distribute,
  }
}

pub fn get_inputs_from_script_info(
  inputs: List<Input>,
  ctx: ScriptContext,
  policy_id: PolicyId,
  asset_name: AssetName,
) -> List<ComparePerpetualInfo> {
  list.map(
    inputs,
    fn(input) {
      let output: Output = input.output
      expect InlineDatum(perpetual_datum) = output.datum
      expect perpetual_datum_typed: PerpetualDatum = perpetual_datum

      let asset_in_input =
        quantity_of(input.output.value, policy_id, asset_name)

      calculate_perpetual_info(ctx, perpetual_datum_typed, asset_in_input)
    },
  )
}

pub fn get_outputs_back_to_script_info(
  outputs_back_to_script: List<Output>,
  ctx: ScriptContext,
  policy_id: PolicyId,
  asset_name: AssetName,
) -> List<ComparePerpetualInfo> {
  list.map(
    outputs_back_to_script,
    fn(output: Output) {
      expect InlineDatum(collateral_datum) = output.datum
      expect perpetual_datum_typed: PerpetualDatum = collateral_datum

      let asset_in_output = quantity_of(output.value, policy_id, asset_name)

      calculate_perpetual_info(ctx, perpetual_datum_typed, asset_in_output)
    },
  )
}

pub fn get_output_to_distribute(
  outputs: List<Output>,
  distribute_validator_hash: ByteArray,
) -> Output {
  let output_to_distribute =
    find_script_outputs(outputs, distribute_validator_hash)

  expect Some(output_to_distribute) = list.head(output_to_distribute)

  output_to_distribute
}

pub fn get_output_to_distribute_ratio_policy(output: Output) -> PolicyId {
  expect InlineDatum(collateral_datum) = output.datum
  expect distribute_datum_typed: DistributeDatum = collateral_datum

  distribute_datum_typed.total_ratio_feed
}
