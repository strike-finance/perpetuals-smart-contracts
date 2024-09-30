use aiken/collection/list
use aiken/collection/pairs
use aiken/crypto.{ScriptHash}
use aiken/interval.{Finite}
use aiken/option
use cardano/address.{Address, Credential, Script}
use cardano/script_context.{ScriptContext}
use cardano/transaction.{
  Input, Output, OutputReference, Transaction, ValidityRange, find_input,
}

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

pub fn is_withdrawal(transaction: Transaction, own_ref: OutputReference) -> Bool {
  expect Some(input) = find_input(transaction.inputs, own_ref)

  let withdrawals = transaction.withdrawals

  let own_withdrawal = input.output.address.payment_credential

  pairs.has_key(withdrawals, own_withdrawal)
}

pub fn own_validator_script_address_hash(
  inputs: List<Input>,
  output_reference: OutputReference,
) -> Option<ScriptHash> {
  inputs
    |> list.find(fn(input) { input.output_reference == output_reference })
    |> option.map(fn(v) { v.output })
    |> option.map(fn(v) { v.address })
    |> option.map(fn(v) { v.payment_credential })
    |> option.map(
        fn(v) {
          when v is {
            Script(hash) -> Some(hash)
            _ -> None
          }
        },
      )
    |> option.flatten()
}

pub fn is_script_credential(
  credential: Credential,
  own_validator: ScriptHash,
) -> Bool {
  when credential is {
    Script(validator_hash) -> validator_hash == own_validator
    _ -> False
  }
}

pub fn get_validators_inputs(
  transaction: Transaction,
  own_validator: ScriptHash,
) -> List<Input> {
  list.filter(
    transaction.inputs,
    fn(input) {
      is_script_credential(
        input.output.address.payment_credential,
        own_validator,
      )
    },
  )
}
