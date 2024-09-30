use aiken/collection/list
use cardano/address.{Script}
use cardano/transaction.{Input, Output, Transaction}
use types.{AddressHash}

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

pub fn validate_order_transaction(input: Input, output: Output) -> Bool {
  todo
}

pub fn validate_enter_position_transaction(input: Input, output: Output) -> Bool {
  todo
}

pub fn validate_close_position_transaction(input: Input, output: Output) -> Bool {
  todo
}
