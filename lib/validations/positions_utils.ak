use aiken/collection/list
use cardano/assets.{quantity_of}
use cardano/transaction.{
  InlineDatum, Input, Output, Transaction, find_script_outputs,
}
use types.{
  OrderAction, OrdersDatum, POSIXTime, PoolDatum, PositionDatum,
  ProcessClosePositionOrder, ProcessLiquidateOrder, ProcessStopLossOrder,
  ProcessTakeProfitOrder,
}
use utils.{
  get_address_outputs, get_all_validators_inputs, get_lower_bound,
  validate_token_mint,
}

pub fn close_position(
  transaction: Transaction,
  datum: Option<PositionDatum>,
  current_price: Int,
  orders_script_hash: ByteArray,
) -> Bool {
  expect Some(input_datum) = datum

  let all_validators_inputs: List<Input> =
    get_all_validators_inputs(transaction)
  let only_one_input_from_script: Bool = list.length(all_validators_inputs) == 1
  expect Some(input_from_script) = list.head(all_validators_inputs)

  let outputs_to_orders_validator: List<Output> =
    find_script_outputs(transaction.outputs, orders_script_hash)

  expect Some(output_to_orders_validator) =
    list.head(outputs_to_orders_validator)

  expect InlineDatum(orders_datum) = output_to_orders_validator.datum
  expect orders_datum_typed: OrdersDatum = orders_datum

  let valid_asset_in_output: Bool =
    quantity_of(
      output_to_orders_validator.value,
      input_datum.underlying_asset.policy_id,
      input_datum.underlying_asset.asset_name,
    ) == 1

  let collateral_asset_not_consumed =
    quantity_of(
      input_from_script.output.value,
      input_datum.collateral_asset.policy_id,
      input_datum.collateral_asset.asset_name,
    ) == quantity_of(
      output_to_orders_validator.value,
      input_datum.collateral_asset.policy_id,
      input_datum.collateral_asset.asset_name,
    )

  let signed_by_owner: Bool =
    list.has(transaction.extra_signatories, input_datum.owner_address_hash)

  let orders_datum_valid: Bool =
    from_positions_to_orders_datum_valid(
      input_datum,
      orders_datum_typed,
      current_price,
      ProcessClosePositionOrder,
    )

  signed_by_owner && valid_asset_in_output && orders_datum_valid && only_one_input_from_script && collateral_asset_not_consumed
}

pub fn stop_loss(
  transaction: Transaction,
  datum: Option<PositionDatum>,
  current_price: Int,
  orders_script_hash: ByteArray,
) -> Bool {
  expect Some(input_datum) = datum

  let all_validators_inputs: List<Input> =
    get_all_validators_inputs(transaction)
  let only_one_input_from_script: Bool = list.length(all_validators_inputs) == 1
  expect Some(input_from_script) = list.head(all_validators_inputs)

  let outputs_to_orders_validator: List<Output> =
    find_script_outputs(transaction.outputs, orders_script_hash)

  expect Some(output_to_orders_validator) =
    list.head(outputs_to_orders_validator)

  expect InlineDatum(orders_datum) = output_to_orders_validator.datum
  expect orders_datum_typed: OrdersDatum = orders_datum

  let valid_asset_in_output: Bool =
    quantity_of(
      output_to_orders_validator.value,
      input_datum.underlying_asset.policy_id,
      input_datum.underlying_asset.asset_name,
    ) == 1

  let collateral_asset_not_consumed =
    quantity_of(
      input_from_script.output.value,
      input_datum.collateral_asset.policy_id,
      input_datum.collateral_asset.asset_name,
    ) == quantity_of(
      output_to_orders_validator.value,
      input_datum.collateral_asset.policy_id,
      input_datum.collateral_asset.asset_name,
    )

  let orders_datum_valid: Bool =
    from_positions_to_orders_datum_valid(
      input_datum,
      orders_datum_typed,
      current_price,
      ProcessStopLossOrder,
    )

  let stop_loss_reached: Bool = current_price <= input_datum.stop_loss_usd_price

  valid_asset_in_output && orders_datum_valid && only_one_input_from_script && collateral_asset_not_consumed && stop_loss_reached
}

// assets are not consumed, user signed transaction, only stop lose is updated 
pub fn update_stop_loss(
  transaction: Transaction,
  datum: Option<PositionDatum>,
  stop_loss_usd_price: Int,
) -> Bool {
  expect Some(input_datum) = datum

  let all_validators_inputs: List<Input> =
    get_all_validators_inputs(transaction)
  let only_one_input_from_script: Bool = list.length(all_validators_inputs) == 1

  expect Some(input_from_script) = list.head(all_validators_inputs)

  let outputs_back_to_positions_validator: List<Output> =
    get_address_outputs(transaction, input_from_script.output.address)

  expect Some(output_to_positions_validator) =
    list.head(outputs_back_to_positions_validator)

  expect InlineDatum(output_datum) = output_to_positions_validator.datum
  expect output_datum_typed: PositionDatum = output_datum

  let collateral_asset_not_consumed: Bool =
    quantity_of(
      input_from_script.output.value,
      input_datum.collateral_asset.policy_id,
      input_datum.collateral_asset.asset_name,
    ) == quantity_of(
      output_to_positions_validator.value,
      input_datum.collateral_asset.policy_id,
      input_datum.collateral_asset.asset_name,
    )

  let positions_asset_returned: Bool =
    quantity_of(
      input_from_script.output.value,
      input_datum.positions_asset.policy_id,
      input_datum.positions_asset.asset_name,
    ) == quantity_of(
      output_to_positions_validator.value,
      input_datum.positions_asset.policy_id,
      input_datum.positions_asset.asset_name,
    )

  let expected_output_datum =
    PositionDatum {
      owner_address_hash: input_datum.owner_address_hash,
      entered_at_price: input_datum.entered_at_price,
      underlying_asset: input_datum.underlying_asset,
      leverage_factor: input_datum.leverage_factor,
      positions_asset: input_datum.positions_asset,
      positions_asset_amount: input_datum.positions_asset_amount,
      collateral_asset: input_datum.collateral_asset,
      collateral_asset_amount: input_datum.collateral_asset_amount,
      liquidate_usd_price: input_datum.liquidate_usd_price,
      stop_loss_usd_price,
      take_profit_usd_price: input_datum.take_profit_usd_price,
      last_pay_lend_time: input_datum.last_pay_lend_time,
      validate_pool_ref: input_datum.validate_pool_ref,
      side: input_datum.side,
    }

  let output_datum_valid: Bool = output_datum_typed == expected_output_datum

  only_one_input_from_script && collateral_asset_not_consumed && positions_asset_returned && output_datum_valid
}

// assets are not consumed, user signed transaction, only stop lose is updated 
pub fn take_profit(
  transaction: Transaction,
  datum: Option<PositionDatum>,
  current_price: Int,
  orders_script_hash: ByteArray,
) -> Bool {
  expect Some(input_datum) = datum

  let all_validators_inputs: List<Input> =
    get_all_validators_inputs(transaction)
  let only_one_input_from_script: Bool = list.length(all_validators_inputs) == 1
  expect Some(input_from_script) = list.head(all_validators_inputs)

  let outputs_to_orders_validator: List<Output> =
    find_script_outputs(transaction.outputs, orders_script_hash)

  expect Some(output_to_orders_validator) =
    list.head(outputs_to_orders_validator)

  expect InlineDatum(orders_datum) = output_to_orders_validator.datum
  expect orders_datum_typed: OrdersDatum = orders_datum

  let valid_asset_in_output: Bool =
    quantity_of(
      output_to_orders_validator.value,
      input_datum.underlying_asset.policy_id,
      input_datum.underlying_asset.asset_name,
    ) == 1

  let collateral_asset_not_consumed =
    quantity_of(
      input_from_script.output.value,
      input_datum.collateral_asset.policy_id,
      input_datum.collateral_asset.asset_name,
    ) == quantity_of(
      output_to_orders_validator.value,
      input_datum.collateral_asset.policy_id,
      input_datum.collateral_asset.asset_name,
    )

  let orders_datum_valid: Bool =
    from_positions_to_orders_datum_valid(
      input_datum,
      orders_datum_typed,
      current_price,
      ProcessTakeProfitOrder,
    )

  let stop_loss_reached: Bool =
    current_price <= input_datum.take_profit_usd_price

  valid_asset_in_output && orders_datum_valid && only_one_input_from_script && collateral_asset_not_consumed && stop_loss_reached
}

// assets are not consumed, user signed transaction, only stop lose is updated 
pub fn update_take_profit(
  transaction: Transaction,
  datum: Option<PositionDatum>,
  take_profit_usd_price: Int,
) -> Bool {
  expect Some(input_datum) = datum

  let all_validators_inputs: List<Input> =
    get_all_validators_inputs(transaction)
  let only_one_input_from_script: Bool = list.length(all_validators_inputs) == 1

  expect Some(input_from_script) = list.head(all_validators_inputs)

  let outputs_back_to_positions_validator: List<Output> =
    get_address_outputs(transaction, input_from_script.output.address)
  let only_one_output_to_positions_validator: Bool =
    list.length(outputs_back_to_positions_validator) == 1

  expect Some(output_to_positions_validator) =
    list.head(outputs_back_to_positions_validator)

  expect InlineDatum(output_datum) = output_to_positions_validator.datum
  expect output_datum_typed: PositionDatum = output_datum

  let collateral_asset_returned: Bool =
    quantity_of(
      input_from_script.output.value,
      input_datum.collateral_asset.policy_id,
      input_datum.collateral_asset.asset_name,
    ) == quantity_of(
      output_to_positions_validator.value,
      output_datum_typed.collateral_asset.policy_id,
      output_datum_typed.collateral_asset.asset_name,
    )

  let positions_asset_returned: Bool =
    quantity_of(
      input_from_script.output.value,
      input_datum.positions_asset.policy_id,
      input_datum.positions_asset.asset_name,
    ) == quantity_of(
      output_to_positions_validator.value,
      output_datum_typed.positions_asset.policy_id,
      output_datum_typed.positions_asset.asset_name,
    )

  let expected_output_datum =
    PositionDatum {
      owner_address_hash: input_datum.owner_address_hash,
      entered_at_price: input_datum.entered_at_price,
      underlying_asset: input_datum.underlying_asset,
      leverage_factor: input_datum.leverage_factor,
      positions_asset: input_datum.positions_asset,
      positions_asset_amount: input_datum.positions_asset_amount,
      collateral_asset: input_datum.collateral_asset,
      collateral_asset_amount: input_datum.collateral_asset_amount,
      liquidate_usd_price: input_datum.liquidate_usd_price,
      stop_loss_usd_price: input_datum.stop_loss_usd_price,
      take_profit_usd_price,
      last_pay_lend_time: input_datum.last_pay_lend_time,
      validate_pool_ref: input_datum.validate_pool_ref,
      side: input_datum.side,
    }

  let output_datum_valid: Bool = output_datum_typed == expected_output_datum

  only_one_input_from_script && only_one_output_to_positions_validator && collateral_asset_returned && positions_asset_returned && output_datum_valid
}

// assets are not consumed, user signed transaction, only stop lose is updated 
pub fn liquidate_position(
  transaction: Transaction,
  datum: Option<PositionDatum>,
  current_price: Int,
  orders_script_hash: ByteArray,
) -> Bool {
  expect Some(input_datum) = datum

  let all_validators_inputs: List<Input> =
    get_all_validators_inputs(transaction)
  let only_one_input_from_script: Bool = list.length(all_validators_inputs) == 1
  expect Some(input_from_script) = list.head(all_validators_inputs)

  let outputs_to_orders_validator: List<Output> =
    find_script_outputs(transaction.outputs, orders_script_hash)

  expect Some(output_to_orders_validator) =
    list.head(outputs_to_orders_validator)

  expect InlineDatum(orders_datum) = output_to_orders_validator.datum
  expect orders_datum_typed: OrdersDatum = orders_datum

  let valid_asset_in_output: Bool =
    quantity_of(
      output_to_orders_validator.value,
      input_datum.underlying_asset.policy_id,
      input_datum.underlying_asset.asset_name,
    ) == 1

  let collateral_asset_not_consumed =
    quantity_of(
      input_from_script.output.value,
      input_datum.collateral_asset.policy_id,
      input_datum.collateral_asset.asset_name,
    ) == quantity_of(
      output_to_orders_validator.value,
      input_datum.collateral_asset.policy_id,
      input_datum.collateral_asset.asset_name,
    )

  let orders_datum_valid: Bool =
    from_positions_to_orders_datum_valid(
      input_datum,
      orders_datum_typed,
      current_price,
      ProcessLiquidateOrder,
    )

  let stop_loss_reached: Bool = current_price <= input_datum.liquidate_usd_price

  valid_asset_in_output && orders_datum_valid && only_one_input_from_script && collateral_asset_not_consumed && stop_loss_reached
}

pub fn pay_lend(
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

fn calculate_pay_borrow(
  position_datum: PositionDatum,
  pool_datum: PoolDatum,
  current_price_volume: Int,
) -> Int {
  let utilization =
    pool_datum.underlying_asset_lended_amount / pool_datum.underlying_asset_amount

  let current_position_usd_value =
    position_datum.positions_asset_amount * position_datum.leverage_factor * current_price_volume

  utilization * pool_datum.underlying_interest_rate * current_position_usd_value
}

pub fn from_positions_to_orders_datum_valid(
  position_datum: PositionDatum,
  orders_datum: OrdersDatum,
  current_price: Int,
  order_type: OrderAction,
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
    position_datum.collateral_asset == orders_datum.collateral_asset

  let collateral_asset_amount_valid: Bool =
    position_datum.collateral_asset_amount == orders_datum.collateral_asset_amount

  let validate_pool_ref_valid: Bool =
    position_datum.validate_pool_ref == orders_datum.validate_pool_ref

  let last_pay_lend_time_valid: Bool =
    position_datum.last_pay_lend_time == orders_datum.order_submission_time

  let take_profit_usd_price_valid: Bool =
    position_datum.take_profit_usd_price == orders_datum.take_profit_usd_price

  let enter_at_price_valid: Bool =
    position_datum.entered_at_price == orders_datum.entered_at_price

  let order_type_valid: Bool = order_type == orders_datum.action

  let order_submission_usd_price_valid: Bool =
    current_price == orders_datum.order_submission_usd_price

  owner_address_hash_valid && underlying_asset_valid && positions_asset_amount_valid && leverage_factor_valid && positions_asset_valid && side_valid && collateral_asset_valid && collateral_asset_amount_valid && validate_pool_ref_valid && last_pay_lend_time_valid && take_profit_usd_price_valid && enter_at_price_valid && order_type_valid && order_submission_usd_price_valid
}
