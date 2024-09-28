use aiken/collection/dict
use aiken/collection/list
use aiken/interval.{Finite}
use cardano/address.{Address, Credential}
use cardano/assets.{PolicyId, Value, flatten, tokens}
use cardano/script_context.{ScriptContext}
use cardano/transaction.{Input, Output, Transaction, ValidityRange}
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
