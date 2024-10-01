use aiken/collection/list
use cardano/assets.{quantity_of}
use cardano/transaction.{Input, Output, Transaction, find_script_outputs}
use types.{PositionDatum}
use utils.{get_all_validators_inputs}

pub fn validate_close_position(
  transaction: Transaction,
  datum: Option<PositionDatum>,
  orders_validator_hash: ByteArray,
) {
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
