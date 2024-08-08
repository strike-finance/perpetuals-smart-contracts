use aiken/dict
use aiken/interval.{Finite}
use aiken/list
use aiken/transaction.{
  InlineDatum, Input, Output, ScriptContext, ValidityRange, find_script_outputs,
}
use aiken/transaction/credential.{
  Address, Credential, ScriptCredential, VerificationKeyCredential,
}
use aiken/transaction/value.{
  AssetName, PolicyId, Value, flatten, policies, quantity_of, tokens,
}
use types.{
  ComparePerpetualInfo, DistributeDatum, PerpetualDatum, Ratio, RationalDatum,
}

pub fn get_lower_bound(range: ValidityRange) -> Int {
  expect Finite(lower_bound) = range.lower_bound.bound_type
  lower_bound
}

pub fn get_upper_bound(range: ValidityRange) -> Int {
  expect Finite(upper_bound) = range.upper_bound.bound_type
  upper_bound
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

pub fn get_ratio(ctx: ScriptContext, datum: PerpetualDatum) -> Ratio {
  let ratio_script_token = #"01"

  expect Some(ratio_script_token_utxo) =
    list.find(
      ctx.transaction.reference_inputs,
      fn(input) {
        list.has(policies(input.output.value), datum.total_ratio_feed)
      },
    )

  expect InlineDatum(ratio_hash) = ratio_script_token_utxo.output.datum
  expect ratio_hash_datum_typed: ByteArray = ratio_hash

  expect Some(orc_fs_utxo) =
    list.find(
      ctx.transaction.reference_inputs,
      fn(input) {
        value.quantity_of(
          input.output.value,
          ratio_hash_datum_typed,
          ratio_script_token,
        ) == 1
      },
    )
  expect InlineDatum(ratio_datum) = orc_fs_utxo.output.datum
  expect ratio_datum_typed: Ratio = ratio_datum

  ratio_datum_typed
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
    redeem_asset: datum.redeem_asset,
    position_asset: datum.position_asset,
    position_code: datum.position_code,
  }
}

pub fn calculate_distribute_info(
  ctx: ScriptContext,
  datum: PerpetualDatum,
  asset_amount: Int,
) -> ComparePerpetualInfo {
  let ratio = get_ratio(ctx, datum)

  let rewards =
    asset_amount / ratio.total_winning_amount * ratio.total_losing_amount

  ComparePerpetualInfo {
    total_ratio_feed: datum.total_ratio_feed,
    orcfax_price_feed: datum.orcfax_price_feed,
    leverage_amount: datum.leverage_amount,
    owner_address_hash: datum.owner_address_hash,
    owner_bech32_address: datum.owner_bech32_address,
    new_balance: asset_amount + rewards,
    funds_to_distribute: rewards,
    redeem_asset: datum.redeem_asset,
    position_asset: datum.position_asset,
    position_code: datum.position_code,
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
      let perpetual_datum: PerpetualDatum = get_perpetual_datum(input.output)

      let asset_in_input: Int =
        quantity_of(input.output.value, policy_id, asset_name)

      calculate_perpetual_info(ctx, perpetual_datum, asset_in_input)
    },
  )
}

pub fn get_input_from_distribute_info(
  inputs: List<Input>,
  ctx: ScriptContext,
) -> List<ComparePerpetualInfo> {
  list.map(
    inputs,
    fn(input: Input) {
      let perpetual_datum: PerpetualDatum = get_perpetual_datum(input.output)

      let asset_in_output: Int =
        quantity_of(
          input.output.value,
          perpetual_datum.redeem_asset.policy_id,
          perpetual_datum.redeem_asset.asset_name,
        )

      calculate_distribute_info(ctx, perpetual_datum, asset_in_output)
    },
  )
}

pub fn get_output_to_distribute_info(
  outputs: List<Output>,
  ctx: ScriptContext,
) -> List<ComparePerpetualInfo> {
  list.map(
    outputs,
    fn(output: Output) {
      let perpetual_datum: PerpetualDatum = get_perpetual_datum(output)

      let asset_in_output: Int =
        quantity_of(
          output.value,
          perpetual_datum.redeem_asset.policy_id,
          perpetual_datum.redeem_asset.asset_name,
        )

      calculate_distribute_info(ctx, perpetual_datum, asset_in_output)
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
      let perpetual_datum: PerpetualDatum = get_perpetual_datum(output)

      let asset_in_output: Int =
        quantity_of(output.value, policy_id, asset_name)

      calculate_perpetual_info(ctx, perpetual_datum, asset_in_output)
    },
  )
}

pub fn get_output_to_validator(
  outputs: List<Output>,
  validator_hash: ByteArray,
) -> Output {
  let output_to_validator: List<Output> =
    find_script_outputs(outputs, validator_hash)

  expect Some(output_to_validator) = list.head(output_to_validator)

  output_to_validator
}

pub fn get_output_to_distribute_ratio_policy(output: Output) -> PolicyId {
  let distribute_datum: DistributeDatum = get_distribute_datum(output)

  distribute_datum.total_ratio_feed
}

pub fn get_distribute_datum(output: Output) -> DistributeDatum {
  expect InlineDatum(distribute_datum) = output.datum
  expect distribute_datum_typed: DistributeDatum = distribute_datum

  distribute_datum_typed
}

pub fn get_perpetual_datum(output: Output) -> PerpetualDatum {
  expect InlineDatum(perpetual_datum) = output.datum
  expect perpetual_datum_typed: PerpetualDatum = perpetual_datum

  perpetual_datum_typed
}

pub fn validate_token_mint(
  mints: Value,
  expected_minting: (ByteArray, ByteArray, Int),
) -> Bool {
  when list.find(flatten(mints), fn(mint) { mint == expected_minting }) is {
    Some(_) -> only_one_token_in_policy_minted(mints, expected_minting)
    None -> False
  }
}

fn only_one_token_in_policy_minted(mints, expected_minting) {
  let (policy_id, _, _) = expected_minting
  let policy_id: PolicyId = policy_id

  list.length(dict.keys(tokens(mints, policy_id))) == 1
}

pub fn perpetuals_info_list_matches(
  perpetuals_info: List<ComparePerpetualInfo>,
  expected_perpetuals_info: List<ComparePerpetualInfo>,
) -> Bool {
  let info_difference: List<ComparePerpetualInfo> =
    list.difference(perpetuals_info, expected_perpetuals_info)

  list.length(info_difference) == 0
}
