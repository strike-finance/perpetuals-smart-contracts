use aiken/collection/list
use cardano/assets.{quantity_of}
use cardano/transaction.{
  Input, Output, OutputReference, Transaction, find_input, find_script_outputs,
}
use types.{PositionDatum}
use utils.{get_all_validators_inputs}

pub fn validate_close_position(
  transaction: Transaction,
  own_ref: OutputReference,
  datum: Option<PositionDatum>,
) {
  expect Some(datum) = datum
  expect Some(input_from_script): Option<Input> =
    find_input(transaction.inputs, own_ref)

  let assets_in_input: Int =
    quantity_of(
      input_from_script.output.value,
      datum.underlying_asset.policy_id,
      datum.underlying_asset.asset_name,
    )

  let signed_by_owner: Bool =
    list.has(transaction.extra_signatories, datum.owner_address_hash)

  let outputs_to_orders_validator: List<Output> =
    find_script_outputs(transaction.outputs, datum.orders_validator_hash)

  expect Some(output_to_orders_validator) =
    list.head(outputs_to_orders_validator)

  let only_one_output_to_orders_validator: Bool =
    list.length(outputs_to_orders_validator) == 1

  let asset_in_output_to_orders_validator: Int =
    quantity_of(
      output_to_orders_validator.value,
      datum.underlying_asset.policy_id,
      datum.underlying_asset.asset_name,
    )

  signed_by_owner && only_one_output_to_orders_validator && asset_in_output_to_orders_validator == assets_in_input
}

pub fn validate_stop_loss(
  transaction: Transaction,
  own_ref: OutputReference,
  datum: Option<PositionDatum>,
  current_price: Int,
) -> Bool {
  expect Some(datum) = datum

  expect Some(input_from_script): Option<Input> =
    find_input(transaction.inputs, own_ref)

  let all_validators_inputs: List<Input> =
    get_all_validators_inputs(transaction)

  let only_one_input_from_script: Bool = list.length(all_validators_inputs) == 1

  let assets_in_input: Int =
    quantity_of(
      input_from_script.output.value,
      datum.underlying_asset.policy_id,
      datum.underlying_asset.asset_name,
    )

  let current_price_volume =
    current_price * datum.position_amount * datum.leverage_amount

  let outputs_to_orders_validator: List<Output> =
    find_script_outputs(transaction.outputs, datum.orders_validator_hash)

  expect Some(output_to_orders_validator) =
    list.head(outputs_to_orders_validator)

  let only_one_output_to_orders_validator: Bool =
    list.length(outputs_to_orders_validator) == 1

  let asset_in_output_to_orders_validator: Int =
    quantity_of(
      output_to_orders_validator.value,
      datum.underlying_asset.policy_id,
      datum.underlying_asset.asset_name,
    )

  let stop_loss_valid: Bool = current_price_volume >= datum.stop_loss_amount

  let assets_not_consumed: Bool =
    asset_in_output_to_orders_validator == assets_in_input

  only_one_input_from_script && only_one_output_to_orders_validator && assets_not_consumed && stop_loss_valid
}
