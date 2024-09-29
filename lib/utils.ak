use aiken/collection/list
use aiken/collection/pairs
use aiken/crypto.{ScriptHash}
use aiken/interval.{Finite}
use aiken/math.{min}
use aiken/option
use cardano/address.{Address, Credential, Script}
use cardano/script_context.{ScriptContext}
use cardano/transaction.{
  Input, Output, OutputReference, Transaction, ValidityRange, find_input,
}
use types.{AddressHash, FundPeriodDatum}

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

pub fn new_funding_period_datum_valid(
  old_fund_round_datum: FundPeriodDatum,
  new_fund_round_datum: FundPeriodDatum,
  new_price: Int,
) -> Bool {
  let matched_amount: Int =
    min(
      old_fund_round_datum.current_long_position_amount,
      old_fund_round_datum.current_short_position_amount,
    )

  let total_amount_stays_same: Bool =
    old_fund_round_datum.total_long_position_amount == new_fund_round_datum.total_long_position_amount && old_fund_round_datum.total_short_position_amount == new_fund_round_datum.total_short_position_amount

  let long_side_win: Bool = new_price > old_fund_round_datum.start_price

  let percentage_paid: Int = 1 / 10

  let paid_amount: Int = matched_amount * percentage_paid

  if long_side_win {
    let long_amount_valid: Bool =
      new_fund_round_datum.total_long_position_amount + paid_amount == old_fund_round_datum.total_long_position_amount
    let short_amount_valid: Bool =
      new_fund_round_datum.total_short_position_amount - paid_amount == old_fund_round_datum.total_short_position_amount

    long_amount_valid && short_amount_valid && total_amount_stays_same
  } else {
    let long_amount_valid: Bool =
      new_fund_round_datum.total_long_position_amount + paid_amount == old_fund_round_datum.total_long_position_amount
    let short_amount_valid: Bool =
      new_fund_round_datum.total_short_position_amount - paid_amount == old_fund_round_datum.total_short_position_amount

    long_amount_valid && short_amount_valid && total_amount_stays_same
  }
}
