use aiken/builtin
use aiken/collection/dict
use aiken/collection/list
use aiken/collection/pairs
use aiken/crypto.{ScriptHash}
use aiken/interval.{Finite}
use aiken/math/rational
use aiken/option
use aiken/primitive/bytearray
use cardano/address.{Address, Credential, Script}
use cardano/assets.{PolicyId, Value, flatten, tokens}
use cardano/transaction.{
  Input, Output, OutputReference, Transaction, ValidityRange, find_input,
}

const minus_ascii_code = 45

const zero_ascii_code = 48

pub fn get_lower_bound(range: ValidityRange) -> Int {
  expect Finite(lower_bound) = range.lower_bound.bound_type
  lower_bound
}

pub fn policy_in_value(license_symbol: PolicyId, val: Value) -> Bool {
  expect [Pair(_tn, am)] =
    val
      |> assets.tokens(license_symbol)
      |> dict.to_pairs()

  am == 1
}

pub fn find_policy_in_value(license_symbol: PolicyId, val: Value) -> Int {
  expect [Pair(tn, am)] =
    val
      |> assets.tokens(license_symbol)
      |> dict.to_pairs()
  expect am == 1
  bytearray_to_int(tn)
}

pub fn validate_batcher_license(
  transaction: Transaction,
  batcher_license: PolicyId,
  batcher_index: Int,
  maximum_deadline_range: Int,
) -> Bool {
  expect Some(Input { output: Output { value: batcher_value, .. }, .. }) =
    list.at(transaction.inputs, batcher_index)
  let license_deadline = find_policy_in_value(batcher_license, batcher_value)

  let (lower_bound, upper_bound) =
    find_posix_time_range(transaction.validity_range)

  license_deadline >= lower_bound && license_deadline <= upper_bound + maximum_deadline_range
}

pub fn bytearray_to_int(byte_arr: ByteArray) -> Int {
  let byte_len = bytearray.length(byte_arr)
  do_bytearray_to_int(byte_arr, 0, 0, byte_len)
}

pub fn do_bytearray_to_int(
  byte_arr: ByteArray,
  idx: Int,
  acc: Int,
  byte_len: Int,
) -> Int {
  if idx == byte_len {
    acc
  } else {
    let byte = builtin.index_bytearray(byte_arr, idx)
    if idx == 0 && byte == minus_ascii_code {
      do_bytearray_to_int(byte_arr, idx + 1, acc, byte_len) * -1
    } else if byte < zero_ascii_code || byte > zero_ascii_code + 9 {
      fail
    } else {
      do_bytearray_to_int(
        byte_arr,
        idx + 1,
        acc * 10 + ( byte - zero_ascii_code ),
        byte_len,
      )
    }
  }
}

pub fn find_posix_time_range(time_rage: ValidityRange) -> (Int, Int) {
  expect Finite(t1) = time_rage.lower_bound.bound_type
  expect Finite(t2) = time_rage.upper_bound.bound_type
  (t1, t2)
}

pub fn get_upper_bound(range: ValidityRange) -> Int {
  expect Finite(upper_bound) = range.upper_bound.bound_type
  upper_bound
}

pub fn get_all_validators_inputs(transaction: Transaction) -> List<Input> {
  list.filter(
    transaction.inputs,
    fn(input) { is_script_credential(input.output.address.payment_credential) },
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

pub fn is_own_script_credential(
  credential: Credential,
  own_validator: ScriptHash,
) -> Bool {
  when credential is {
    Script(validator_hash) -> validator_hash == own_validator
    _ -> False
  }
}

pub fn return_script_hash(credential: Credential) -> ScriptHash {
  expect Script(hash) = credential
  hash
}

pub fn is_script_credential(credential: Credential) -> Bool {
  when credential is {
    Script(_) -> True
    _ -> False
  }
}

pub fn get_own_validators_inputs(
  transaction: Transaction,
  own_validator: ScriptHash,
) -> List<Input> {
  list.filter(
    transaction.inputs,
    fn(input) {
      is_own_script_credential(
        input.output.address.payment_credential,
        own_validator,
      )
    },
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
fn only_one_token_in_policy_minted(
  mints: Value,
  expected_minting: (ByteArray, ByteArray, Int),
) -> Bool {
  let (policy_id, _, _) = expected_minting
  let policy_id: PolicyId = policy_id
  // Check for the policy mints
  list.length(dict.keys(tokens(mints, policy_id))) == 1
  // Total count of minted unique tokens with policy is 1
}

pub fn get_address_outputs(
  transaction: Transaction,
  address: Address,
) -> List<Output> {
  list.filter(transaction.outputs, fn(output) { output.address == address })
}

pub fn divide(numerator: Int, denominator: Int) -> Int {
  expect Some(divided) = rational.new(numerator, denominator)

  rational.ceil(divided)
}
