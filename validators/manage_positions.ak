use aiken/collection/dict
use aiken/collection/list
use aiken/interval.{Finite, Interval, IntervalBound}
use cardano/address.{from_script}
use cardano/assets.{from_lovelace, match, quantity_of}
use cardano/transaction.{
  InlineDatum, Input, Output, OutputReference, Transaction, find_script_outputs,
}
use constants.{position_asset_name, strike_asset_name, strike_policy_id}
use math.{
  calculate_accumulative_interest_fee,
  calculate_position_usd_value_based_on_side, reach_liquidation_price,
}
use test_constants.{
  orders_script_hash, out_ref, position_hash, trader_pkh, underlying_asset,
}
use types.{
  ClosePositionOrder, CloseType, LiquidatePositionOrder, Long, OrderDatum,
  POSIXTime, PositionDatum, ScriptHash, StopLossClose, TraderClose,
}
use utils.{get_address_outputs, get_all_validators_inputs, get_lower_bound}

pub type ManagePositionRedeemer {
  Close { close_price: Int, close_type: CloseType, output_to_user_index: Int }
  AddCollateral { collateral_asset_amount: Int }
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
      Close(current_usd_price, close_type, output_to_user_index) ->
        close_position_valid(
          transaction,
          datum,
          current_usd_price,
          orders_script_hash,
          close_type,
          output_to_user_index,
        )
      LiquidateClose(current_usd_price) ->
        liquidate_close_valid(
          transaction,
          datum,
          orders_script_hash,
          current_usd_price,
        )
      AddCollateral(collateral_asset_amount) ->
        add_collateral_valid(transaction, datum, collateral_asset_amount)
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
  output_to_user_index: Int,
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
    owner_pkh,
    owner_stake_key,
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

  let expected_order_datum =
    OrderDatum {
      action: ClosePositionOrder {
        owner_pkh,
        owner_stake_key,
        send_asset: collateral_asset,
        send_asset_amount,
        strike_collateral_amount,
        pool_asset_profit_loss: collateral_asset_amount - send_asset_amount,
        return_pool_asset_amount: position_asset_amount - send_asset_amount,
      },
    }

  let expected_order_datum_data: Data = expected_order_datum

  expect expected_order_datum_data == orders_datum

  // Validate based on close type
  when close_type is {
    // TraderClose: only owner can close
    TraderClose -> list.has(extra_signatories, datum.owner_pkh)

    // Create expected order datum (same for all close types)
    // In a long position, a loss is when the current price is less than the inital price, so 
    // a stop loss is reached when the price is below or equal to the stop_loss_usd_price
    _ ->
      if close_type == StopLossClose {
        if datum.side == Long {
          current_usd_price <= datum.stop_loss_usd_price
        } else {
          current_usd_price >= datum.stop_loss_usd_price
        }
      } else {
        if datum.side == Long {
          current_usd_price >= datum.take_profit_usd_price
        } else {
          current_usd_price <= datum.take_profit_usd_price
        }
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
  add_collateral_asset_amount: Int,
) -> Bool {
  expect Some(datum) = maybe_datum

  let PositionDatum { collateral_asset, collateral_asset_amount, .. } = datum

  let all_validators_inputs: List<Input> =
    get_all_validators_inputs(transaction)
  expect list.length(all_validators_inputs) == 1

  expect Some(input_from_script) = list.head(all_validators_inputs)

  let outputs_back_to_positions_validator: List<Output> =
    get_address_outputs(transaction, input_from_script.output.address)

  expect Some(output_to_positions_validator) =
    list.head(outputs_back_to_positions_validator)

  expect InlineDatum(output_datum) = output_to_positions_validator.datum

  let input_collateral_asset_amount =
    quantity_of(
      input_from_script.output.value,
      collateral_asset.policy_id,
      collateral_asset.asset_name,
    )

  expect
    quantity_of(
      output_to_positions_validator.value,
      collateral_asset.policy_id,
      collateral_asset.asset_name,
    ) == input_collateral_asset_amount + collateral_asset_amount

  let updated_datum =
    PositionDatum {
      ..datum,
      collateral_asset_amount: collateral_asset_amount + add_collateral_asset_amount,
    }

  let output_datum_data: Data = output_datum
  let expected_datum_data: Data = updated_datum

  expect output_datum_data == expected_datum_data

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

test close_position() {
  let position_datum =
    PositionDatum {
      owner_pkh: trader_pkh,
      owner_stake_key: None,
      entered_at_usd_price: 90,
      position_hash,
      leverage_factor: 10,
      position_asset_amount: 10_000_000,
      stop_loss_usd_price: 98,
      take_profit_usd_price: 0,
      collateral_asset: underlying_asset,
      entered_position_time: 1727453227635,
      maintain_margin_amount: 5,
      hourly_usd_borrow_fee: 90000,
      collateral_asset_amount: 1_000_000,
      side: Long,
    }

  let position_input =
    Input {
      output_reference: out_ref,
      output: Output {
        address: from_script(orders_script_hash),
        value: from_lovelace(1_000_000)
          |> assets.add(position_hash, position_asset_name, 1),
        datum: InlineDatum(position_datum),
        reference_script: None,
      },
    }

  let orders_datum =
    OrderDatum {
      action: ClosePositionOrder {
        owner_pkh: trader_pkh,
        owner_stake_key: None,
        send_asset: underlying_asset,
        send_asset_amount: 1_900_000,
        return_pool_asset_amount: 8_100_000,
        strike_collateral_amount: 0,
        pool_asset_profit_loss: -900_000,
      },
    }

  let mint = assets.from_asset(position_hash, position_asset_name, -1)

  let orders_output =
    Output {
      address: from_script(orders_script_hash),
      value: from_lovelace(1_000_000),
      datum: InlineDatum(orders_datum),
      reference_script: None,
    }

  let transaction =
    Transaction {
      inputs: [position_input],
      reference_inputs: [],
      outputs: [orders_output],
      fee: 0,
      mint,
      certificates: [],
      withdrawals: [],
      validity_range: Interval {
        lower_bound: IntervalBound {
          bound_type: Finite(1727453227635),
          is_inclusive: False,
        },
        upper_bound: IntervalBound {
          bound_type: Finite(1727456400000),
          is_inclusive: False,
        },
      },
      extra_signatories: [trader_pkh],
      redeemers: [],
      datums: dict.empty,
      id: #"0000000000000000000000000000000000000000000000000000000000000000",
      votes: [],
      proposal_procedures: [],
      current_treasury_amount: None,
      treasury_donation: None,
    }

  close_position_valid(
    transaction,
    Some(position_datum),
    100,
    orders_script_hash,
    TraderClose,
    1,
  )
}

test liquidate_close() {
  let position_datum =
    PositionDatum {
      owner_pkh: trader_pkh,
      owner_stake_key: None,
      entered_at_usd_price: 100,
      position_hash,
      leverage_factor: 10,
      position_asset_amount: 10_000_000,
      stop_loss_usd_price: 98,
      take_profit_usd_price: 0,
      collateral_asset: underlying_asset,
      entered_position_time: 1727453227635,
      maintain_margin_amount: 5,
      hourly_usd_borrow_fee: 90000,
      collateral_asset_amount: 1_000_000,
      side: Long,
    }

  let transaction =
    Transaction {
      inputs: [],
      reference_inputs: [],
      outputs: [],
      fee: 0,
      mint: assets.zero,
      certificates: [],
      withdrawals: [],
      validity_range: interval.everything,
      extra_signatories: [],
      redeemers: [],
      datums: dict.empty,
      id: #"0000000000000000000000000000000000000000000000000000000000000000",
      votes: [],
      proposal_procedures: [],
      current_treasury_amount: None,
      treasury_donation: None,
    }

  liquidate_close_valid(
    transaction,
    Some(position_datum),
    orders_script_hash,
    10,
  )
}

test add_collateral() {
  let position_datum =
    PositionDatum {
      owner_pkh: trader_pkh,
      owner_stake_key: None,
      entered_at_usd_price: 100,
      position_hash,
      leverage_factor: 10,
      position_asset_amount: 10_000_000,
      stop_loss_usd_price: 98,
      take_profit_usd_price: 0,
      collateral_asset: underlying_asset,
      entered_position_time: 1727453227635,
      maintain_margin_amount: 5,
      hourly_usd_borrow_fee: 90000,
      collateral_asset_amount: 1_000_000,
      side: Long,
    }

  let transaction =
    Transaction {
      inputs: [],
      reference_inputs: [],
      outputs: [],
      fee: 0,
      mint: assets.zero,
      certificates: [],
      withdrawals: [],
      validity_range: interval.everything,
      extra_signatories: [],
      redeemers: [],
      datums: dict.empty,
      id: #"0000000000000000000000000000000000000000000000000000000000000000",
      votes: [],
      proposal_procedures: [],
      current_treasury_amount: None,
      treasury_donation: None,
    }

  add_collateral_valid(transaction, Some(position_datum), 100)
}

test update_position() {
  let position_datum =
    PositionDatum {
      owner_pkh: trader_pkh,
      owner_stake_key: None,
      entered_at_usd_price: 100,
      position_hash,
      leverage_factor: 10,
      position_asset_amount: 10_000_000,
      stop_loss_usd_price: 98,
      take_profit_usd_price: 0,
      collateral_asset: underlying_asset,
      entered_position_time: 1727453227635,
      maintain_margin_amount: 5,
      hourly_usd_borrow_fee: 90000,
      collateral_asset_amount: 1_000_000,
      side: Long,
    }

  let transaction =
    Transaction {
      inputs: [],
      reference_inputs: [],
      outputs: [],
      fee: 0,
      mint: assets.zero,
      certificates: [],
      withdrawals: [],
      validity_range: interval.everything,
      extra_signatories: [],
      redeemers: [],
      datums: dict.empty,
      id: #"0000000000000000000000000000000000000000000000000000000000000000",
      votes: [],
      proposal_procedures: [],
      current_treasury_amount: None,
      treasury_donation: None,
    }

  update_position_valid(transaction, Some(position_datum), 100, 100)
}
