use aiken/collection/list
use cardano/assets.{quantity_of}
use cardano/transaction.{
  InlineDatum, Input, Output, Transaction, find_script_outputs,
}
use math_utils.{calculate_pay_borrow}
use types.{POSIXTime, PoolDatum, PositionDatum}
use utils.{
  get_address_outputs, get_all_validators_inputs, get_lower_bound,
  validate_token_mint,
}

pub fn validate_close_position(
  transaction: Transaction,
  datum: Option<PositionDatum>,
  orders_validator_hash: ByteArray,
) -> Bool {
  expect Some(datum) = datum

  let signed_by_owner: Bool =
    list.has(transaction.extra_signatories, datum.owner_address_hash)

  let outputs_to_orders_validator: List<Output> =
    find_script_outputs(transaction.outputs, orders_validator_hash)

  expect Some(output_to_orders_validator) =
    list.head(outputs_to_orders_validator)

  let only_one_output_to_orders_validator: Bool =
    list.length(outputs_to_orders_validator) == 1

  let valid_asset_in_output: Bool =
    quantity_of(
      output_to_orders_validator.value,
      datum.underlying_asset.policy_id,
      datum.underlying_asset.asset_name,
    ) == 1

  signed_by_owner && only_one_output_to_orders_validator && valid_asset_in_output
}

pub fn validate_stop_loss(
  transaction: Transaction,
  datum: Option<PositionDatum>,
  current_price: Int,
  orders_validator_hash: ByteArray,
) -> Bool {
  expect Some(datum) = datum

  let all_validators_inputs: List<Input> =
    get_all_validators_inputs(transaction)

  let only_one_input_from_script: Bool = list.length(all_validators_inputs) == 1

  let current_price_volume =
    current_price * datum.position_amount * datum.leverage_factor

  let outputs_to_orders_validator: List<Output> =
    find_script_outputs(transaction.outputs, orders_validator_hash)

  expect Some(output_to_orders_validator) =
    list.head(outputs_to_orders_validator)

  let only_one_output_to_orders_validator: Bool =
    list.length(outputs_to_orders_validator) == 1

  let valid_asset_in_output: Bool =
    quantity_of(
      output_to_orders_validator.value,
      datum.positions_asset.policy_id,
      datum.positions_asset.asset_name,
    ) == 1

  let stop_loss_valid: Bool = current_price_volume >= datum.stop_loss_amount

  only_one_input_from_script && only_one_output_to_orders_validator && valid_asset_in_output && stop_loss_valid
}

pub fn validate_pay_lend(
  transaction: Transaction,
  datum: Option<PositionDatum>,
  current_price: Int,
) -> Bool {
  expect Some(datum) = datum

  let all_validators_inputs: List<Input> =
    get_all_validators_inputs(transaction)

  let ref_input: List<Input> = transaction.reference_inputs

  expect Some(pool_ref_input) =
    list.find(
      ref_input,
      fn(ref_input: Input) {
        ref_input.output_reference == datum.validate_pool_ref
      },
    )

  expect InlineDatum(pool_ref_datum) = pool_ref_input.output.datum
  expect pool_ref_datum_typed: PoolDatum = pool_ref_datum

  let only_one_input_from_script: Bool = list.length(all_validators_inputs) == 1

  expect Some(input_from_script) = list.head(all_validators_inputs)

  let outputs_back_to_positions_validator: List<Output> =
    get_address_outputs(transaction, input_from_script.output.address)

  let only_one_output_to_positions_validator: Bool =
    list.length(outputs_back_to_positions_validator) == 1

  let current_time: POSIXTime = get_lower_bound(transaction.validity_range)

  let one_hour_has_passed: Bool =
    current_time > datum.last_pay_lend_time + 3_600_000

  let expected_burn_amount =
    calculate_pay_borrow(datum, pool_ref_datum_typed, current_price)

  let expected_mint =
    (
      datum.positions_asset.policy_id,
      datum.positions_asset.asset_name,
      expected_burn_amount * -1,
    )

  let mint_valid: Bool = validate_token_mint(transaction.mint, expected_mint)

  only_one_input_from_script && only_one_output_to_positions_validator && one_hour_has_passed && mint_valid
}
