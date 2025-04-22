use aiken/collection/dict
use aiken/collection/list
use aiken/interval.{Finite, Interval, IntervalBound}
use cardano/address.{Script, from_script}
use cardano/assets.{flatten, from_lovelace, quantity_of}
use cardano/transaction.{
  InlineDatum, Input, Output, OutputReference, Transaction,
}
use constants.{position_asset_name}
use math.{
  calculate_accumulative_interest_fee,
  calculate_position_usd_value_based_on_side, reach_liquidation_price,
}
use test_constants.{
  manage_positions_script_hash, orders_script_hash, out_ref,
  test_position_policy_id, trader_pkh, underlying_asset,
}
use types.{
  ClosePositionOrder, CloseType, LiquidateClose, LiquidatePositionOrder, Long,
  OrderDatum, PositionDatum, ScriptHash, StopLossClose, TakeProfitClose,
  TraderClose,
}
use utils.{get_all_validators_inputs, get_upper_bound}

pub type ManagePositionRedeemer {
  Close { close_price: Int, close_type: CloseType, output_to_order_index: Int }
  AddCollateral {
    collateral_asset_amount: Int,
    output_back_to_positions_index: Int,
  }
  PositionUpdate {
    stop_loss: Int,
    take_profit: Int,
    output_back_to_positions_index: Int,
    current_usd_price: Int,
  }
}

validator manage_positions(orders_script_hash: ScriptHash) {
  spend(
    datum: Option<PositionDatum>,
    redeemer: ManagePositionRedeemer,
    _own_ref: OutputReference,
    transaction: Transaction,
  ) {
    when redeemer is {
      Close(current_usd_price, close_type, output_to_order_index) ->
        close_position_valid(
          transaction,
          datum,
          current_usd_price,
          orders_script_hash,
          close_type,
          output_to_order_index,
        )
      AddCollateral(collateral_asset_amount, output_back_to_positions_index) ->
        add_collateral_valid(
          transaction,
          datum,
          collateral_asset_amount,
          output_back_to_positions_index,
        )
      PositionUpdate(
        stop_loss,
        take_profit,
        output_back_to_positions_index,
        current_usd_price,
      ) ->
        update_position_valid(
          transaction,
          datum,
          stop_loss,
          take_profit,
          output_back_to_positions_index,
          current_usd_price,
        )
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
  output_to_order_index: Int,
) -> Bool {
  let Transaction { extra_signatories, outputs, .. } = transaction

  expect Some(datum) = maybe_datum

  let PositionDatum {
    entered_at_usd_price,
    side,
    collateral_asset_amount,
    position_asset_amount,
    collateral_asset,
    owner_pkh,
    owner_stake_key,
    maintain_margin_amount,
    entered_position_time,
    hourly_usd_borrow_fee,
    position_policy_id,
    ..
  } = datum

  // Validate basic transaction structure
  let all_validators_inputs = get_all_validators_inputs(transaction)
  expect Some(input_from_script) = list.head(all_validators_inputs)
  expect list.length(all_validators_inputs) == 1

  expect Some(output_to_orders_validator) =
    list.at(outputs, output_to_order_index)
  expect InlineDatum(orders_datum) = output_to_orders_validator.datum

  expect Script(output_to_orders_validator_hash) =
    output_to_orders_validator.address.payment_credential

  expect output_to_orders_validator_hash == orders_script_hash

  let current_time = get_upper_bound(transaction.validity_range)

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

  // Make sure no assets are consumed, user might have added additional collateral, in that case the collateral is in
  // the utxo  
  expect
    quantity_of(
      input_from_script.output.value,
      collateral_asset.policy_id,
      collateral_asset.asset_name,
    ) == quantity_of(
      output_to_orders_validator.value,
      collateral_asset.policy_id,
      collateral_asset.asset_name,
    )

  let reached_liquidation_price =
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

  if reached_liquidation_price {
    let expected_order_datum =
      OrderDatum {
        action: LiquidatePositionOrder {
          profit: collateral_asset_amount,
          lended_amount: position_asset_amount - collateral_asset_amount,
          position_policy_id,
        },
      }

    let expected_order_datum_data: Data = expected_order_datum

    expected_order_datum_data == orders_datum
  } else {
    // Validate based on close type
    when close_type is {
      // TraderClose: only owner can close
      TraderClose -> {
        expect list.has(extra_signatories, datum.owner_pkh)

        let expected_order_datum =
          OrderDatum {
            action: ClosePositionOrder {
              owner_pkh,
              owner_stake_key,
              send_asset: collateral_asset,
              send_asset_amount,
              pool_asset_profit_loss: collateral_asset_amount - send_asset_amount,
              position_policy_id,
              borrowed_amount: position_asset_amount - collateral_asset_amount,
            },
          }

        let expected_order_datum_data: Data = expected_order_datum

        expected_order_datum_data == orders_datum
      }

      // Create expected order datum (same for all close types)
      // In a long position, a loss is when the current price is less than the inital price, so 
      // a stop loss is reached when the price is below or equal to the stop_loss_usd_price
      _ -> {
        let expected_order_datum =
          OrderDatum {
            action: ClosePositionOrder {
              owner_pkh,
              owner_stake_key,
              send_asset: collateral_asset,
              send_asset_amount,
              pool_asset_profit_loss: collateral_asset_amount - send_asset_amount,
              position_policy_id,
              borrowed_amount: position_asset_amount - collateral_asset_amount,
            },
          }

        let expected_order_datum_data: Data = expected_order_datum

        expect expected_order_datum_data == orders_datum

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
  }
}

// Only add asset amount is changed
// Collateral asset needs to be the same in the datum 
// No assets has been consumed
pub fn add_collateral_valid(
  transaction: Transaction,
  maybe_datum: Option<PositionDatum>,
  add_collateral_asset_amount: Int,
  output_back_to_positions_index: Int,
) -> Bool {
  expect Some(datum) = maybe_datum

  let PositionDatum {
    collateral_asset,
    collateral_asset_amount,
    manage_positions_script_hash,
    position_policy_id,
    ..
  } = datum

  let Transaction { outputs, .. } = transaction

  let all_validators_inputs: List<Input> =
    get_all_validators_inputs(transaction)
  expect list.length(all_validators_inputs) == 1

  expect Some(input_from_script) = list.head(all_validators_inputs)

  expect Some(output_to_positions_validator) =
    list.at(outputs, output_back_to_positions_index)

  expect InlineDatum(output_datum) = output_to_positions_validator.datum

  expect Script(output_script_hash) =
    output_to_positions_validator.address.payment_credential

  expect manage_positions_script_hash == output_script_hash

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

  expect
    quantity_of(
      output_to_positions_validator.value,
      position_policy_id,
      position_asset_name,
    ) == 1

  let expected_output_asset =
    when collateral_asset.policy_id == "" is {
      True -> 2
      _ -> 3
    }

  expect
    list.length(flatten(output_to_positions_validator.value)) == expected_output_asset

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
  output_back_to_positions_index: Int,
  current_usd_price: Int,
) -> Bool {
  expect Some(datum) = maybe_datum

  let PositionDatum {
    side,
    owner_pkh,
    collateral_asset,
    manage_positions_script_hash,
    position_policy_id,
    ..
  } = datum

  let Transaction { outputs, .. } = transaction

  let all_validators_inputs: List<Input> =
    get_all_validators_inputs(transaction)

  expect list.length(all_validators_inputs) == 1

  expect Some(input_from_script) = list.head(all_validators_inputs)

  expect Some(output_to_positions_validator) =
    list.at(outputs, output_back_to_positions_index)

  expect InlineDatum(output_datum) = output_to_positions_validator.datum

  expect Script(output_script_hash) =
    output_to_positions_validator.address.payment_credential

  expect manage_positions_script_hash == output_script_hash

  expect
    quantity_of(
      output_to_positions_validator.value,
      position_policy_id,
      position_asset_name,
    ) == 1

  expect
    quantity_of(
      input_from_script.output.value,
      collateral_asset.policy_id,
      collateral_asset.asset_name,
    ) == quantity_of(
      output_to_positions_validator.value,
      collateral_asset.policy_id,
      collateral_asset.asset_name,
    )

  let expected_output_asset =
    when collateral_asset.policy_id == "" is {
      True -> 2
      _ -> 3
    }

  expect
    list.length(flatten(output_to_positions_validator.value)) == expected_output_asset

  expect list.has(transaction.extra_signatories, owner_pkh)

  let expected_output_datum =
    PositionDatum {
      ..datum,
      stop_loss_usd_price: new_stop_loss,
      take_profit_usd_price: new_take_profit,
    }
  let expected_output_datum_data: Data = expected_output_datum
  expect expected_output_datum_data == output_datum

  if side == Long {
    ( current_usd_price >= new_stop_loss || new_stop_loss == 0 ) && (
      current_usd_price <= new_take_profit || new_take_profit == 0
    )
  } else {
    ( current_usd_price <= new_stop_loss || new_stop_loss == 0 ) && (
      current_usd_price >= new_take_profit || new_take_profit == 0
    )
  }
}

test close_position() {
  let position_datum =
    PositionDatum {
      owner_pkh: trader_pkh,
      owner_stake_key: None,
      entered_at_usd_price: 90,
      position_policy_id: test_position_policy_id,
      manage_positions_script_hash,
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
        address: from_script(manage_positions_script_hash),
        value: from_lovelace(1_000_000)
          |> assets.add(test_position_policy_id, position_asset_name, 1),
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
        pool_asset_profit_loss: -900_000,
        position_policy_id: test_position_policy_id,
        borrowed_amount: 9_000_000,
      },
    }

  let mint = assets.from_asset(test_position_policy_id, position_asset_name, -1)

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
    0,
  )
}

test liquidate_close() {
  let position_datum =
    PositionDatum {
      owner_pkh: trader_pkh,
      owner_stake_key: None,
      entered_at_usd_price: 60_000,
      position_policy_id: test_position_policy_id,
      manage_positions_script_hash,
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

  let mint = assets.from_asset(test_position_policy_id, position_asset_name, -1)

  let position_input =
    Input {
      output_reference: out_ref,
      output: Output {
        address: from_script(manage_positions_script_hash),
        value: from_lovelace(1_000_000)
          |> assets.add(test_position_policy_id, position_asset_name, 1),
        datum: InlineDatum(position_datum),
        reference_script: None,
      },
    }

  let output_datum =
    OrderDatum {
      action: LiquidatePositionOrder {
        profit: 1_000_000,
        lended_amount: 9_000_000,
        position_policy_id: test_position_policy_id,
      },
    }

  let order_output =
    Output {
      address: from_script(orders_script_hash),
      value: from_lovelace(1_000_000),
      datum: InlineDatum(output_datum),
      reference_script: None,
    }

  let transaction =
    Transaction {
      inputs: [position_input],
      reference_inputs: [],
      outputs: [order_output],
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
      extra_signatories: [],
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
    20_000,
    orders_script_hash,
    LiquidateClose,
    0,
  )
}

test stop_loss() {
  let position_datum =
    PositionDatum {
      owner_pkh: trader_pkh,
      owner_stake_key: None,
      entered_at_usd_price: 100,
      position_policy_id: test_position_policy_id,
      manage_positions_script_hash,
      position_asset_amount: 10_000_000,
      stop_loss_usd_price: 920000,
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
        address: from_script(manage_positions_script_hash),
        value: from_lovelace(1_000_000)
          |> assets.add(test_position_policy_id, position_asset_name, 1),
        datum: InlineDatum(position_datum),
        reference_script: None,
      },
    }

  let mint = assets.from_asset(test_position_policy_id, position_asset_name, -1)

  let order_datum =
    OrderDatum {
      action: ClosePositionOrder {
        owner_pkh: trader_pkh,
        owner_stake_key: None,
        send_asset: underlying_asset,
        send_asset_amount: 9999010,
        pool_asset_profit_loss: -8999010,
        position_policy_id: test_position_policy_id,
        borrowed_amount: 9_000_000,
      },
    }

  let order_output =
    Output {
      address: from_script(orders_script_hash),
      datum: InlineDatum(order_datum),
      value: from_lovelace(1_000_000),
      reference_script: None,
    }

  let transaction =
    Transaction {
      inputs: [position_input],
      reference_inputs: [],
      outputs: [order_output],
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
      extra_signatories: [],
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
    910000,
    orders_script_hash,
    StopLossClose,
    0,
  )
}

test take_profit() {
  let position_datum =
    PositionDatum {
      owner_pkh: trader_pkh,
      owner_stake_key: None,
      entered_at_usd_price: 100,
      position_policy_id: test_position_policy_id,
      manage_positions_script_hash,
      position_asset_amount: 10_000_000,
      stop_loss_usd_price: 98,
      take_profit_usd_price: 102,
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
        address: from_script(manage_positions_script_hash),
        value: from_lovelace(1_000_000)
          |> assets.add(test_position_policy_id, position_asset_name, 1),
        datum: InlineDatum(position_datum),
        reference_script: None,
      },
    }

  let mint = assets.from_asset(test_position_policy_id, position_asset_name, -1)

  let order_datum =
    OrderDatum {
      action: ClosePositionOrder {
        owner_pkh: trader_pkh,
        owner_stake_key: None,
        send_asset: underlying_asset,
        send_asset_amount: 1176470,
        pool_asset_profit_loss: -176470,
        position_policy_id: test_position_policy_id,
        borrowed_amount: 9_000_000,
      },
    }

  let order_output =
    Output {
      address: from_script(orders_script_hash),
      datum: InlineDatum(order_datum),
      value: from_lovelace(1_000_000),
      reference_script: None,
    }

  let transaction =
    Transaction {
      inputs: [position_input],
      reference_inputs: [],
      outputs: [order_output],
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
      extra_signatories: [],
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
    102,
    orders_script_hash,
    TakeProfitClose,
    0,
  )
}

test add_collateral() {
  let position_datum =
    PositionDatum {
      owner_pkh: trader_pkh,
      owner_stake_key: None,
      entered_at_usd_price: 100,
      position_policy_id: test_position_policy_id,
      manage_positions_script_hash,
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
        address: from_script(manage_positions_script_hash),
        value: from_lovelace(1_000_000)
          |> assets.add(test_position_policy_id, position_asset_name, 1),
        datum: InlineDatum(position_datum),
        reference_script: None,
      },
    }

  let mint = assets.from_asset(test_position_policy_id, position_asset_name, -1)

  let updated_position_datum =
    PositionDatum {
      owner_pkh: trader_pkh,
      owner_stake_key: None,
      entered_at_usd_price: 100,
      position_policy_id: test_position_policy_id,
      manage_positions_script_hash,
      position_asset_amount: 10_000_000,
      stop_loss_usd_price: 98,
      take_profit_usd_price: 0,
      collateral_asset: underlying_asset,
      entered_position_time: 1727453227635,
      maintain_margin_amount: 5,
      hourly_usd_borrow_fee: 90000,
      collateral_asset_amount: 2_000_000,
      side: Long,
    }

  let updated_position_output =
    Output {
      address: from_script(manage_positions_script_hash),
      value: from_lovelace(2_000_000)
        |> assets.add(test_position_policy_id, position_asset_name, 1),
      datum: InlineDatum(updated_position_datum),
      reference_script: None,
    }

  let transaction =
    Transaction {
      inputs: [position_input],
      reference_inputs: [],
      outputs: [updated_position_output],
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

  add_collateral_valid(transaction, Some(position_datum), 1_000_000, 0)
}

test update_position() {
  let position_datum =
    PositionDatum {
      owner_pkh: trader_pkh,
      owner_stake_key: None,
      entered_at_usd_price: 100,
      position_policy_id: test_position_policy_id,
      manage_positions_script_hash,
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
        address: from_script(manage_positions_script_hash),
        value: from_lovelace(1_000_000)
          |> assets.add(test_position_policy_id, position_asset_name, 1),
        datum: InlineDatum(position_datum),
        reference_script: None,
      },
    }

  let updated_position_datum =
    PositionDatum {
      owner_pkh: trader_pkh,
      owner_stake_key: None,
      entered_at_usd_price: 100,
      position_policy_id: test_position_policy_id,
      manage_positions_script_hash,
      position_asset_amount: 10_000_000,
      stop_loss_usd_price: 50,
      take_profit_usd_price: 150,
      collateral_asset: underlying_asset,
      entered_position_time: 1727453227635,
      maintain_margin_amount: 5,
      hourly_usd_borrow_fee: 90000,
      collateral_asset_amount: 1_000_000,
      side: Long,
    }

  let updated_position_output =
    Output {
      address: from_script(manage_positions_script_hash),
      value: from_lovelace(1_000_000)
        |> assets.add(test_position_policy_id, position_asset_name, 1),
      datum: InlineDatum(updated_position_datum),
      reference_script: None,
    }

  let transaction =
    Transaction {
      inputs: [position_input],
      reference_inputs: [],
      outputs: [updated_position_output],
      fee: 0,
      mint: assets.zero,
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

  update_position_valid(transaction, Some(position_datum), 50, 150, 0, 100)
}
