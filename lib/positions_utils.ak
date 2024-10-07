use aiken/collection/list
use cardano/assets.{quantity_of}
use cardano/transaction.{
  InlineDatum, Input, Output, Transaction, find_script_outputs,
}
use math_utils.{calculate_pay_borrow}
use types.{OrdersDatum, POSIXTime, PoolDatum, PositionDatum}
use utils.{
  get_address_outputs, get_all_validators_inputs, get_lower_bound,
  validate_token_mint,
}

pub fn from_positions_to_orders_datum_valid(
  position_datum: PositionDatum,
  orders_datum: OrdersDatum,
) -> Bool {
  let owner_address_hash_valid: Bool =
    position_datum.owner_address_hash == orders_datum.owner_address_hash

  let underlying_asset_valid: Bool =
    position_datum.underlying_asset == orders_datum.underlying_asset

  let positions_asset_amount_valid: Bool =
    position_datum.positions_asset_amount == orders_datum.positions_asset_amount

  let leverage_factor_valid: Bool =
    position_datum.leverage_factor == orders_datum.leverage_factor

  let positions_asset_valid: Bool =
    position_datum.positions_asset == orders_datum.positions_asset

  let side_valid: Bool = position_datum.side == orders_datum.side

  let collateral_asset_valid: Bool =
    position_datum.collateral_asset == orders_datum.stable_collateral_asset

  let collateral_asset_amount_valid: Bool =
    position_datum.collateral_asset_amount == orders_datum.stable_collateral_asset_amount

  let validate_pool_ref_valid: Bool =
    position_datum.validate_pool_ref == orders_datum.validate_pool_ref

  let last_pay_lend_time_valid: Bool =
    position_datum.last_pay_lend_time == orders_datum.order_submission_time

  let take_profit_amount_valid: Bool =
    position_datum.take_profit_amount == orders_datum.take_profit_amount

  let enter_at_price_valid: Bool =
    position_datum.entered_at_price == orders_datum.entered_at_price

  owner_address_hash_valid && underlying_asset_valid && positions_asset_amount_valid && leverage_factor_valid && positions_asset_valid && side_valid && collateral_asset_valid && collateral_asset_amount_valid && validate_pool_ref_valid && last_pay_lend_time_valid && take_profit_amount_valid && enter_at_price_valid
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

  expect InlineDatum(orders_datum) = output_to_orders_validator.datum
  expect orders_datum_typed: OrdersDatum = orders_datum

  let only_one_output_to_orders_validator: Bool =
    list.length(outputs_to_orders_validator) == 1

  let valid_asset_in_output: Bool =
    quantity_of(
      output_to_orders_validator.value,
      datum.underlying_asset.policy_id,
      datum.underlying_asset.asset_name,
    ) == 1

  let orders_datum_valid: Bool =
    from_positions_to_orders_datum_valid(datum, orders_datum_typed)

  signed_by_owner && only_one_output_to_orders_validator && valid_asset_in_output && orders_datum_valid
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

  let current_price_volume = current_price * datum.positions_asset_amount

  let outputs_to_orders_validator: List<Output> =
    find_script_outputs(transaction.outputs, orders_validator_hash)

  expect Some(output_to_orders_validator) =
    list.head(outputs_to_orders_validator)

  expect InlineDatum(orders_datum) = output_to_orders_validator.datum
  expect orders_datum_typed: OrdersDatum = orders_datum

  let only_one_output_to_orders_validator: Bool =
    list.length(outputs_to_orders_validator) == 1

  let valid_asset_in_output: Bool =
    quantity_of(
      output_to_orders_validator.value,
      datum.positions_asset.policy_id,
      datum.positions_asset.asset_name,
    ) == 1

  let orders_datum_valid: Bool =
    from_positions_to_orders_datum_valid(datum, orders_datum_typed)

  let stop_loss_valid: Bool = current_price_volume >= datum.stop_loss_amount

  orders_datum_valid && only_one_input_from_script && only_one_output_to_orders_validator && valid_asset_in_output && stop_loss_valid
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
