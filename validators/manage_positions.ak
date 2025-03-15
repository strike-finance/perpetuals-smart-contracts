use aiken/collection/list
use cardano/assets.{match, quantity_of}
use cardano/transaction.{
  InlineDatum, Input, Output, OutputReference, Transaction, find_script_outputs,
}
use constants.{strike_asset_name, strike_policy_id}
use math.{
  calculate_accumulative_interest_fee, calculate_return, reach_liquidation_price,
}
use types.{
  ClosePositionOrder, CloseSendAmount, CloseType, LiquidatePositionOrder, Long,
  OrderDatum, POSIXTime, PositionDatum, ScriptHash, Short, StopLossClose,
  TakeProfitClose, TraderClose,
}
use utils.{get_address_outputs, get_all_validators_inputs, get_lower_bound}

pub type ManagePositionRedeemer {
  Close { close_price: Int, close_type: CloseType }
  AddCollateral
  PositionUpdate { stop_loss: Int, take_profit: Int }
  LiquidateClose { current_usd_price: Int }
  RebalancePosition
  IncreasePositionFromProfit
}

validator manage_positions(orders_script_hash: ScriptHash) {
  spend(
    datum: Option<PositionDatum>,
    redeemer: ManagePositionRedeemer,
    _own_ref: OutputReference,
    transaction: Transaction,
  ) {
    when redeemer is {
      Close(current_usd_price, close_type) ->
        close_position_valid(
          transaction,
          datum,
          current_usd_price,
          orders_script_hash,
          close_type,
        )
      LiquidateClose(current_usd_price) ->
        liquidate_close_valid(
          transaction,
          datum,
          orders_script_hash,
          current_usd_price,
        )
      AddCollateral -> add_collateral_valid(transaction, datum)
      PositionUpdate(stop_loss, take_profit) ->
        update_position_valid(transaction, datum, stop_loss, take_profit)
      RebalancePosition -> rebalance_position_valid()
      IncreasePositionFromProfit -> increase_position_from_profit_valid()
    }
  }

  else(_) {
    False
  }
}

pub fn close_position_valid(
  transaction: Transaction,
  maybe_datum: Option<PositionDatum>,
  current_usd_price: Int,
  orders_script_hash: ScriptHash,
  close_type: CloseType,
) -> Bool {
  expect Some(datum) = maybe_datum

  // Validate basic transaction structure
  let all_validators_inputs = get_all_validators_inputs(transaction)
  expect list.length(all_validators_inputs) == 1
  expect Some(input_from_script) = list.head(all_validators_inputs)

  let outputs_to_orders_validator =
    find_script_outputs(transaction.outputs, orders_script_hash)
  expect Some(output_to_orders_validator) =
    list.head(outputs_to_orders_validator)
  expect InlineDatum(orders_datum) = output_to_orders_validator.datum

  // Calculate amounts and fees
  let collateral_asset_amount =
    quantity_of(
      input_from_script.output.value,
      datum.collateral_asset.policy_id,
      datum.collateral_asset.asset_name,
    )

  let current_time = get_lower_bound(transaction.validity_range)
  let strike_collateral_asset_amount =
    quantity_of(
      input_from_script.output.value,
      strike_policy_id,
      strike_asset_name,
    )

  let accumulative_interest_fee =
    calculate_accumulative_interest_fee(
      current_time,
      datum.entered_position_time,
      datum.hourly_usd_borrow_fee,
    )

  // Calculate return amount (same for all close types)
  let CloseSendAmount { send_asset_amount, .. } =
    calculate_return(
      datum.position_asset_amount,
      collateral_asset_amount,
      datum.entered_at_usd_price,
      current_usd_price,
      strike_collateral_asset_amount,
      datum.side,
      accumulative_interest_fee,
    )

  let underlying_asset_gain_loss = collateral_asset_amount - send_asset_amount

  let expected_assets_sent =
    input_from_script.output.value
      |> assets.add(
          datum.collateral_asset.policy_id,
          datum.collateral_asset.asset_name,
          -send_asset_amount,
        )

  expect match(expected_assets_sent, output_to_orders_validator.value, >=)

  // Create expected order datum (same for all close types)
  let expected_order_datum =
    OrderDatum {
      action: ClosePositionOrder {
        position_hash: datum.position_hash,
        underlying_asset_gain_loss,
      },
    }
  let expected_order_datum_data: Data = expected_order_datum

  expect expected_order_datum_data == orders_datum

  // Validate based on close type
  when close_type is {
    // TraderClose: only owner can close
    TraderClose ->
      list.has(transaction.extra_signatories, datum.owner_address_hash)
    // In a long position, a loss is when the current price is less than the inital price, so 
    // a stop loss is reached when the price is below or equal to the stop_loss_usd_price
    StopLossClose ->
      if datum.side == Long {
        current_usd_price <= datum.stop_loss_usd_price
      } else {
        current_usd_price >= datum.stop_loss_usd_price
      }
    // In a long position, a take profit is when the current price is greater than the inital price, so 
    // a take profit is reached when the price is above or equal to the take_profit_usd_price
    TakeProfitClose ->
      if datum.side == Long {
        current_usd_price >= datum.take_profit_usd_price
      } else {
        current_usd_price <= datum.take_profit_usd_price
      }
  }
}

pub fn liquidate_close_valid(
  transaction: Transaction,
  maybe_datum: Option<PositionDatum>,
  orders_script_hash: ScriptHash,
  current_usd_price: Int,
) -> Bool {
  expect Some(datum) = maybe_datum

  let outputs_to_orders_validator =
    find_script_outputs(transaction.outputs, orders_script_hash)
  expect Some(output_to_orders_validator) =
    list.head(outputs_to_orders_validator)
  expect InlineDatum(orders_datum) = output_to_orders_validator.datum

  let all_validators_inputs = get_all_validators_inputs(transaction)
  expect list.length(all_validators_inputs) == 1
  expect Some(input_from_script) = list.head(all_validators_inputs)

  let PositionDatum {
    position_asset_amount,
    entered_at_usd_price,
    entered_position_time,
    side,
    position_hash,
    hourly_usd_borrow_fee,
    maintain_margin_amount,
    collateral_asset,
    ..
  } = datum

  let collateral_amount =
    quantity_of(
      input_from_script.output.value,
      collateral_asset.policy_id,
      collateral_asset.asset_name,
    )

  let expected_order_datum =
    OrderDatum {
      action: LiquidatePositionOrder {
        position_hash,
        underlying_asset_gain: collateral_amount,
      },
    }

  let expected_order_datum_data: Data = expected_order_datum

  let orders_datum_valid: Bool = expected_order_datum_data == orders_datum

  let current_time: POSIXTime = get_lower_bound(transaction.validity_range)

  let collateral_asset_amount =
    quantity_of(
      input_from_script.output.value,
      collateral_asset.policy_id,
      collateral_asset.asset_name,
    )

  let liquidate_reached: Bool =
    reach_liquidation_price(
      side,
      position_asset_amount,
      current_usd_price,
      entered_at_usd_price,
      maintain_margin_amount,
      collateral_asset_amount,
      entered_position_time,
      hourly_usd_borrow_fee,
      current_time,
    )

  orders_datum_valid && liquidate_reached
}

// Only add asset amount is changed
// Collateral asset needs to be the same in the datum 
// No assets has been consumed
pub fn add_collateral_valid(
  transaction: Transaction,
  maybe_datum: Option<PositionDatum>,
) -> Bool {
  expect Some(datum) = maybe_datum

  let all_validators_inputs: List<Input> =
    get_all_validators_inputs(transaction)
  let only_one_input_from_script: Bool = list.length(all_validators_inputs) == 1

  expect Some(input_from_script) = list.head(all_validators_inputs)

  let outputs_back_to_positions_validator: List<Output> =
    get_address_outputs(transaction, input_from_script.output.address)

  expect Some(output_to_positions_validator) =
    list.head(outputs_back_to_positions_validator)

  expect InlineDatum(output_datum) = output_to_positions_validator.datum

  let assets_locked_valid: Bool =
    match(
      output_to_positions_validator.value,
      input_from_script.output.value,
      >=,
    )

  let input_datum_data: Data = datum
  let output_datum_data: Data = output_datum

  let datum_not_changed: Bool = input_datum_data == output_datum_data

  datum_not_changed && only_one_input_from_script && assets_locked_valid
}

// assets are not consumed, user signed transaction, only stop lose or take profit is updated 
pub fn update_position_valid(
  transaction: Transaction,
  maybe_datum: Option<PositionDatum>,
  new_stop_loss: Int,
  new_take_profit: Int,
) -> Bool {
  expect Some(datum) = maybe_datum

  let all_validators_inputs: List<Input> =
    get_all_validators_inputs(transaction)

  expect list.length(all_validators_inputs) == 1

  expect Some(input_from_script) = list.head(all_validators_inputs)

  let outputs_back_to_positions_validator: List<Output> =
    get_address_outputs(transaction, input_from_script.output.address)

  expect Some(output_to_positions_validator) =
    list.head(outputs_back_to_positions_validator)

  expect InlineDatum(output_datum) = output_to_positions_validator.datum

  let assets_locked_valid: Bool =
    match(
      output_to_positions_validator.value,
      input_from_script.output.value,
      >=,
    )

  let expected_output_datum =
    PositionDatum {
      ..datum,
      stop_loss_usd_price: new_stop_loss,
      take_profit_usd_price: new_take_profit,
    }

  let expected_output_datum_data: Data = expected_output_datum

  assets_locked_valid && expected_output_datum_data == output_datum
}

pub fn rebalance_position_valid() -> Bool {
  True
}

pub fn increase_position_from_profit_valid() -> Bool {
  True
}
