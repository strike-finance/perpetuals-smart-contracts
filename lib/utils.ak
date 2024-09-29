use aiken/collection/list
use aiken/collection/pairs
use aiken/interval.{Finite}
use cardano/address.{Address, Script}
use cardano/script_context.{ScriptContext}
use cardano/transaction.{
  Input, Output, OutputReference, Transaction, ValidityRange, find_input,
}
use types.{AddressHash}

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

pub fn withdraw(
  validation_logic: fn(Output, Output) -> Bool,
  redeemer: List<(Int, Int)>,
  tx: Transaction,
  own_validator: AddressHash,
) -> Bool {
  let Transaction { inputs, outputs, .. } = tx
  let (script_inputs, script_input_count) =
    list.foldr(
      inputs,
      ([], 0),
      fn(i, acc_tuple) {
        let Input { output, .. } = i
        when output.address.payment_credential is {
          Script(script) ->
            if script == own_validator {
              let (acc, count) = acc_tuple
              ([output, ..acc], count + 1)
            } else {
              acc_tuple
            }
          _ -> acc_tuple
        }
      },
    )

  let indices: List<(Int, Int)> = redeemer
  let (_, _, input_index_count) =
    list.foldl(
      indices,
      (-1, -1, 0),
      fn(curr, acc) {
        let (in0, out0, count) = acc
        let (in1, out1) = curr
        if in1 > in0 && out1 > out0 {
          expect Some(in_utxo) = script_inputs |> list.at(in1)
          expect Some(out_utxo) = outputs |> list.at(out1)
          if validation_logic(in_utxo, out_utxo) {
            (in1, out1, count + 1)
          } else {
            fail @"Validation failed"
          }
        } else {
          fail @"Input and output indices must be in ascending orders"
        }
      },
    )
  (script_input_count == input_index_count)?
}

pub fn is_withdrawal(transaction: Transaction, own_ref: OutputReference) -> Bool {
  expect Some(input) = find_input(transaction.inputs, own_ref)

  let withdrawals = transaction.withdrawals

  let own_withdrawal = input.output.address.payment_credential

  pairs.has_key(withdrawals, own_withdrawal)
}
