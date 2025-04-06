use aiken/collection/list
use cardano/assets.{match, quantity_of}
use cardano/transaction.{
  InlineDatum, Input, Output, OutputReference, Transaction, find_script_outputs,
}
use constants.{position_asset_name, strike_asset_name, strike_policy_id}
use math.{
  calculate_accumulative_interest_fee,
  calculate_position_usd_value_based_on_side, reach_liquidation_price,
}
use types.{
  AutomatedClosePositionOrder, CloseType, LiquidatePositionOrder, Long,
  OrderDatum, POSIXTime, PositionDatum, ScriptHash, StopLossClose, TraderClose,
}
use utils.{get_address_outputs, get_all_validators_inputs, get_lower_bound}

pub type ManagePositionRedeemer {
  Close { close_price: Int, close_type: CloseType }
  AddCollateral
  PositionUpdate { stop_loss: Int, take_profit: Int }
  LiquidateClose { current_usd_price: Int }
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
  let Transaction { mint, extra_signatories, .. } = transaction

  expect Some(datum) = maybe_datum

  let PositionDatum {
    entered_at_usd_price,
    side,
    collateral_asset_amount,
    position_asset_amount,
    collateral_asset,
    position_hash,
    ..
  } = datum

  // Validate basic transaction structure
  let all_validators_inputs = get_all_validators_inputs(transaction)
  expect list.length(all_validators_inputs) == 1

  let outputs_to_orders_validator =
    find_script_outputs(transaction.outputs, orders_script_hash)
  expect Some(output_to_orders_validator) =
    list.head(outputs_to_orders_validator)
  expect InlineDatum(orders_datum) = output_to_orders_validator.datum

  let current_time = get_lower_bound(transaction.validity_range)

  expect [(position_hash, position_asset_name, -1)] == assets.flatten(mint)

  let accumulative_interest_fee =
    calculate_accumulative_interest_fee(
      current_time,
      datum.entered_position_time,
      datum.hourly_usd_borrow_fee,
    )

  let position_usd_value =
    calculate_position_usd_value_based_on_side(
      side,
      position_asset_amount,
      current_usd_price,
      entered_at_usd_price,
      accumulative_interest_fee,
    )

  let collateral_value: Int = collateral_asset_amount * entered_at_usd_price

  let send_asset_amount =
    ( collateral_value + position_usd_value ) / current_usd_price

  let strike_collateral_amount =
    quantity_of(
      output_to_orders_validator.value,
      strike_policy_id,
      strike_asset_name,
    )

  // Validate based on close type
  when close_type is {
    // TraderClose: only owner can close
    TraderClose -> {
      expect list.has(extra_signatories, datum.owner_pkh)

      let assets_sent_back_to_pool =
        quantity_of(
          output_to_orders_validator.value,
          collateral_asset.policy_id,
          collateral_asset.asset_name,
        )

      assets_sent_back_to_pool >= position_asset_amount - send_asset_amount
    }

    // Create expected order datum (same for all close types)
    // In a long position, a loss is when the current price is less than the inital price, so 
    // a stop loss is reached when the price is below or equal to the stop_loss_usd_price
    _ -> {
      if close_type == StopLossClose {
        if datum.side == Long {
          expect current_usd_price <= datum.stop_loss_usd_price
        } else {
          expect current_usd_price >= datum.stop_loss_usd_price
        }
      } else {
        if datum.side == Long {
          expect current_usd_price >= datum.take_profit_usd_price
        } else {
          expect current_usd_price <= datum.take_profit_usd_price
        }
      }

      let expected_order_datum =
        OrderDatum {
          action: AutomatedClosePositionOrder {
            send_asset_amount,
            return_pool_asset_amount: position_asset_amount - send_asset_amount,
            strike_collateral_amount,
            owner_pkh: datum.owner_pkh,
            owner_stake_key: datum.owner_stake_key,
            send_asset: collateral_asset,
            pool_asset_profit_loss: collateral_asset_amount - send_asset_amount,
          },
        }
      let expected_order_datum_data: Data = expected_order_datum

      expect expected_order_datum_data == orders_datum

      quantity_of(
        output_to_orders_validator.value,
        strike_policy_id,
        strike_asset_name,
      ) == position_asset_amount
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

  let PositionDatum {
    position_asset_amount,
    entered_at_usd_price,
    entered_position_time,
    side,
    hourly_usd_borrow_fee,
    maintain_margin_amount,
    leverage_factor,
    collateral_asset,
    ..
  } = datum

  let all_validators_inputs = get_all_validators_inputs(transaction)
  expect list.length(all_validators_inputs) == 1

  let outputs_to_orders_validator =
    find_script_outputs(transaction.outputs, orders_script_hash)
  expect Some(output_to_orders_validator) =
    list.head(outputs_to_orders_validator)
  expect InlineDatum(orders_datum) = output_to_orders_validator.datum

  expect Some(input_from_script) = list.head(all_validators_inputs)

  let collateral_asset_gained = position_asset_amount / leverage_factor

  let expected_order_datum =
    OrderDatum {
      action: LiquidatePositionOrder { profit: collateral_asset_gained },
    }

  let expected_order_datum_data: Data = expected_order_datum

  expect expected_order_datum_data == orders_datum

  let current_time: POSIXTime = get_lower_bound(transaction.validity_range)

  expect
    match(input_from_script.output.value, output_to_orders_validator.value, >=)

  let collateral_asset_amount =
    quantity_of(
      input_from_script.output.value,
      collateral_asset.policy_id,
      collateral_asset.asset_name,
    )

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
  expect list.length(all_validators_inputs) == 1

  expect Some(input_from_script) = list.head(all_validators_inputs)

  let outputs_back_to_positions_validator: List<Output> =
    get_address_outputs(transaction, input_from_script.output.address)

  expect Some(output_to_positions_validator) =
    list.head(outputs_back_to_positions_validator)

  expect InlineDatum(output_datum) = output_to_positions_validator.datum

  expect
    match(
      output_to_positions_validator.value,
      input_from_script.output.value,
      >=,
    )

  let input_datum_data: Data = datum
  let output_datum_data: Data = output_datum

  expect input_datum_data == output_datum_data

  list.has(transaction.extra_signatories, datum.owner_pkh)
}

// assets are not consumed, user signed transaction, only stop lose or take profit is updated 
// signed by owner 
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

  expect
    match(
      output_to_positions_validator.value,
      input_from_script.output.value,
      >=,
    )

  expect list.has(transaction.extra_signatories, datum.owner_pkh)

  let expected_output_datum =
    PositionDatum {
      ..datum,
      stop_loss_usd_price: new_stop_loss,
      take_profit_usd_price: new_take_profit,
    }

  let expected_output_datum_data: Data = expected_output_datum

  expected_output_datum_data == output_datum
}
