use aiken/collection/dict
use aiken/collection/list
use aiken/interval.{Finite}
use cardano/address.{Address, Credential, ScriptCredential}
use cardano/aseets.{PolicyId, Value, flatten, tokens}
use cardano/transaction.{
  Input, Output, ScriptContext, Transaction, ValidityRange,
}
use types.{PerpetualDatum, PositionDatum}

pub fn get_lower_bound(range: ValidityRange) -> Int {
  expect Finite(lower_bound) = range.lower_bound.bound_type
  lower_bound
}

pub fn get_upper_bound(range: ValidityRange) -> Int {
  expect Finite(upper_bound) = range.upper_bound.bound_type
  upper_bound
}

pub fn get_address_outputs(ctx: ScriptContext, address: Address) -> List<Output> {
  list.filter(ctx.transaction.outputs, fn(output) { output.address == address })
}

pub fn get_address_input(ctx: ScriptContext, address: Address) -> List<Input> {
  list.filter(
    ctx.transaction.inputs,
    fn(input) { input.output.address == address },
  )
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

// Make sure only one token is minted from the asset tuple
fn only_one_token_in_policy_minted(mints, expected_minting) {
  let (policy_id, _, _) = expected_minting
  let policy_id: PolicyId = policy_id
  // Check for the policy mints
  list.length(dict.keys(tokens(mints, policy_id))) == 1
  // Total count of minted unique tokens with policy is 1
}

pub fn is_script_credential(credential: Credential) -> Bool {
  when credential is {
    ScriptCredential(_validator_hash) -> True
    _ -> False
  }
}

pub fn get_validators_inputs(ctx: ScriptContext) -> List<Input> {
  list.filter(
    ctx.transaction.inputs,
    fn(input) { is_script_credential(input.output.address.payment_credential) },
  )
}

pub fn get_burn_long_amount_valid(
  perpetual_datum: PerpetualDatum,
  position_datum: PositionDatum,
  consumed_amount: Int,
) -> Bool {
  if position_datum.leverage_amount > 0 {
    let total_position_amount: Int =
      position_datum.position_amount + position_datum.leverage_amount

    let proportion_with_leverage: Int =
      perpetual_datum.long_position_amount / total_position_amount

    perpetual_datum.long_position_amount * proportion_with_leverage - position_datum.leverage_amount >= consumed_amount
  } else {
    let proportion: Int =
      perpetual_datum.long_position_amount / position_datum.position_amount

    perpetual_datum.long_position_amount * proportion >= consumed_amount
  }
}

pub fn get_burn_short_amount_valid(
  perpetual_datum: PerpetualDatum,
  position_datum: PositionDatum,
  consumed_amount: Int,
) -> Bool {
  if position_datum.leverage_amount > 0 {
    let total_position_amount: Int =
      position_datum.position_amount + position_datum.leverage_amount

    let proportion_with_leverage: Int =
      perpetual_datum.short_position_amount / total_position_amount

    perpetual_datum.short_position_amount * proportion_with_leverage - position_datum.leverage_amount >= consumed_amount
  } else {
    let proportion: Int =
      perpetual_datum.short_position_amount / position_datum.position_amount

    perpetual_datum.short_position_amount * proportion >= consumed_amount
  }
}
