use aiken/collection/list
use aiken/crypto.{ScriptHash}
use cardano/address.{Address, Script, VerificationKey}
use cardano/assets.{Value, flatten, match, zero}
use cardano/transaction.{InlineDatum, Input, Output, Transaction}
use constants.{strike_asset_name, strike_policy_id}
use types.{
  Asset, ClosePositionCalculate, ClosePositionOrder, ExpectedPoolOutput,
  LiquidatePositionOrder, Long, OpenPositionOrder, OrderDatum, PoolDatum,
  PositionDatum, PositionSide,
}
use utils.{divide, format_stable_if_lovelace, get_all_validators_inputs}

pub fn valid_orders(
  validation_logic: fn(Output, Output, Value, PoolDatum, Value, ScriptHash) ->
    ExpectedPoolOutput,
  redeemer: List<(Int, Int)>,
  transaction: Transaction,
  own_validator: ScriptHash,
  pool_utxo: Output,
  pool_datum: PoolDatum,
  burn_address: ScriptHash,
) -> ExpectedPoolOutput {
  let Transaction { inputs, outputs, .. } = transaction
  let (script_inputs, script_input_count) =
    list.foldr(
      inputs,
      ([], 0),
      fn(i, acc_tuple) {
        let Input { output, .. } = i
        when output.address.payment_credential is {
          Script(script) ->
            if script == own_validator {
              let (acc, count) = acc_tuple
              ([output, ..acc], count + 1)
            } else {
              acc_tuple
            }
          _ -> acc_tuple
        }
      },
    )

  let indices: List<(Int, Int)> = redeemer
  let (
    _,
    _,
    input_index_count,
    expected_pool_output_value,
    expected_pool_output_datum,
    expected_mint,
  ) =
    list.foldl(
      indices,
      (-1, -1, 0, pool_utxo.value, pool_datum, zero),
      fn(curr, acc) {
        let (
          in0,
          out0,
          count,
          expected_pool_output_value,
          expected_pool_output_datum,
          expected_mint,
        ) = acc
        let (in1, out1) = curr
        if in1 > in0 && out1 > out0 {
          expect Some(in_utxo) = script_inputs |> list.at(in1)
          expect Some(out_utxo) = outputs |> list.at(out1)
          let ExpectedPoolOutput {
            value: updated_value,
            datum: updated_datum,
            mint: updated_expected_mint,
          } =
            validation_logic(
              in_utxo,
              out_utxo,
              expected_pool_output_value,
              expected_pool_output_datum,
              expected_mint,
              burn_address,
            )

          (
            in1,
            out1,
            count + 1,
            updated_value,
            updated_datum,
            updated_expected_mint,
          )
        } else {
          fail @"Input and output indices must be in ascending orders"
        }
      },
    )

  expect script_input_count == input_index_count

  let expected_pool_output =
    ExpectedPoolOutput {
      value: expected_pool_output_value,
      datum: expected_pool_output_datum,
      mint: expected_mint,
    }

  expected_pool_output
}

pub fn validate_individual_order(
  input: Output,
  output: Output,
  pool_output_value: Value,
  pool_output_datum: PoolDatum,
  expected_mint: Value,
  burn_address: ScriptHash,
) -> ExpectedPoolOutput {
  expect InlineDatum(input_datum) = input.datum

  expect input_datum_typed: OrderDatum = input_datum

  when input_datum_typed.action is {
    OpenPositionOrder(..) ->
      open_position(
        input_datum_typed,
        output,
        pool_output_value,
        pool_output_datum,
        expected_mint,
      )
    ClosePositionOrder(..) ->
      close_position(
        input_datum_typed,
        output,
        pool_output_value,
        pool_output_datum,
        expected_mint,
      )
    LiquidatePositionOrder(..) ->
      liquidate_position(
        input_datum_typed,
        output,
        pool_output_value,
        pool_output_datum,
        expected_mint,
        burn_address,
      )
  }
}

pub fn open_position(
  input_datum_typed: OrderDatum,
  output: Output,
  pool_output_value: Value,
  pool_output_datum: PoolDatum,
  expected_mint: Value,
) -> ExpectedPoolOutput {
  expect OpenPositionOrder {
    underlying_asset,
    owner_address_hash,
    position_hash,
    leverage_factor,
    side,
    order_submission_time,
    order_submission_usd_price,
    collateral_asset,
    collateral_asset_amount,
    strike_asset_amount,
    margin_requirement,
    hourly_usd_borrow_fee,
    position_asset_amount,
  } = input_datum_typed.action

  let expected_output_datum =
    PositionDatum {
      owner_address_hash,
      position_hash,
      entered_at_usd_price: order_submission_usd_price,
      underlying_asset,
      leverage_factor,
      position_asset_amount,
      collateral_asset,
      collateral_asset_amount,
      strike_asset_amount,
      stop_loss_usd_price: 0,
      take_profit_usd_price: 0,
      margin_requirement,
      last_pay_lend_time: order_submission_time,
      hourly_usd_borrow_fee,
      side,
    }

  let expected_output_assets =
    assets.from_asset(position_hash, owner_address_hash, 1)
      |> assets.add(
          collateral_asset.policy_id,
          collateral_asset.asset_name,
          collateral_asset_amount,
        )
      |> assets.add(strike_policy_id, strike_asset_name, strike_asset_amount)

  let assets_locked_valid = match(output.value, expected_output_assets, >=)

  expect InlineDatum(output_datum) = output.datum

  expect output_datum_typed: PositionDatum = output_datum

  expect Script(output_script_hash) = output.address.payment_credential

  let output_script_hash_valid = output_script_hash == position_hash

  let lended_amount: Int = position_asset_amount / leverage_factor

  let updated_pool_datum =
    PoolDatum {
      underlying_asset: pool_output_datum.underlying_asset,
      underlying_asset_amount: pool_output_datum.underlying_asset_amount,
      underlying_asset_lended_amount: pool_output_datum.underlying_asset_lended_amount + lended_amount,
      underlying_interest_rate: pool_output_datum.underlying_interest_rate,
      margin_requirement: pool_output_datum.margin_requirement,
      stable_collateral_asset: pool_output_datum.stable_collateral_asset,
      stable_collateral_asset_amount: pool_output_datum.stable_collateral_asset_amount,
      max_leverage_factor: pool_output_datum.max_leverage_factor,
      max_strike_holder_leverage_factor: pool_output_datum.max_strike_holder_leverage_factor,
      maintain_margin_amount: pool_output_datum.maintain_margin_amount,
      is_valid_pool_asset: pool_output_datum.is_valid_pool_asset,
      earnings_per_share: pool_output_datum.earnings_per_share,
      collateral_earnings_per_share: pool_output_datum.collateral_earnings_per_share,
    }

  let datum_valid = output_datum_typed == expected_output_datum

  expect assets_locked_valid && datum_valid && output_script_hash_valid

  ExpectedPoolOutput {
    value: pool_output_value,
    datum: updated_pool_datum,
    mint: expected_mint,
  }
}

pub fn close_position(
  input_datum_typed: OrderDatum,
  output: Output,
  pool_output_value: Value,
  pool_output_datum: PoolDatum,
  expected_mint: Value,
) -> ExpectedPoolOutput {
  expect ClosePositionOrder {
    owner_address_hash,
    order_submission_usd_price,
    entered_at_usd_price,
    collateral_asset,
    collateral_asset_amount,
    strike_asset_amount,
    side,
    position_hash,
    position_asset_amount,
    ..
  } = input_datum_typed.action

  let current_position_value: Int =
    order_submission_usd_price * position_asset_amount

  let entry_position_value: Int = entered_at_usd_price * position_asset_amount

  let expected_asset_amount_send_to_user: Int =
    calculate_profit(side, current_position_value, entry_position_value)

  expect VerificationKey(output_owner_address_hash) =
    output.address.payment_credential

  let output_is_to_owner = owner_address_hash == output_owner_address_hash

  let mint = assets.add(expected_mint, position_hash, owner_address_hash, -1)

  let estimated_return =
    calculate_return(
      collateral_asset,
      collateral_asset_amount,
      strike_asset_amount,
      expected_asset_amount_send_to_user,
      order_submission_usd_price,
      pool_output_value,
      pool_output_datum,
      side,
    )

  let assets_locked_valid =
    match(output.value, estimated_return.expected_asset_send_to_owner, >=)

  expect output_is_to_owner && assets_locked_valid

  ExpectedPoolOutput {
    value: estimated_return.value,
    datum: estimated_return.datum,
    mint,
  }
}

pub fn liquidate_position(
  input_datum_typed: OrderDatum,
  output: Output,
  pool_output_value: Value,
  pool_output_datum: PoolDatum,
  expected_mint: Value,
  burn_address: ScriptHash,
) -> ExpectedPoolOutput {
  expect LiquidatePositionOrder {
    collateral_asset,
    collateral_asset_amount,
    position_hash,
    side,
    owner_address_hash,
    strike_asset_amount,
  } = input_datum_typed.action

  let updated_value =
    assets.add(
      pool_output_value,
      collateral_asset.policy_id,
      collateral_asset.asset_name,
      collateral_asset_amount,
    )

  let updated_mint =
    assets.add(expected_mint, position_hash, owner_address_hash, -1)

  let strike_is_burnt =
    is_strike_collateral_asset_burnt(strike_asset_amount, burn_address, output)

  expect strike_is_burnt

  if side == Long {
    let updated_datum =
      PoolDatum {
        ..pool_output_datum,
        underlying_asset_amount: pool_output_datum.underlying_asset_amount + collateral_asset_amount,
      }

    ExpectedPoolOutput {
      value: updated_value,
      datum: updated_datum,
      mint: updated_mint,
    }
  } else {
    let updated_datum =
      PoolDatum {
        ..pool_output_datum,
        stable_collateral_asset_amount: pool_output_datum.stable_collateral_asset_amount + collateral_asset_amount,
      }
    ExpectedPoolOutput {
      value: updated_value,
      datum: updated_datum,
      mint: updated_mint,
    }
  }
}

pub fn cancel_open_position(datum: OrderDatum, transaction: Transaction) -> Bool {
  expect OpenPositionOrder { owner_address_hash, position_hash, .. } =
    datum.action

  let signed_by_owner =
    list.has(transaction.extra_signatories, owner_address_hash)

  let only_one_input_from_script =
    list.length(get_all_validators_inputs(transaction)) == 1

  let expected_burnt = [(position_hash, owner_address_hash, -1)]

  let mint_valid: Bool = expected_burnt == flatten(transaction.mint)

  signed_by_owner && only_one_input_from_script && mint_valid
}

pub fn cancel_close_position(
  datum: OrderDatum,
  transaction: Transaction,
  output_index: Int,
) -> Bool {
  expect ClosePositionOrder {
    underlying_asset,
    owner_address_hash,
    position_hash,
    leverage_factor,
    entered_at_usd_price,
    stop_loss_usd_price,
    take_profit_usd_price,
    last_pay_lend_time,
    position_asset_amount,
    collateral_asset,
    collateral_asset_amount,
    strike_asset_amount,
    margin_requirement,
    hourly_usd_borrow_fee,
    side,
    ..
  } = datum.action

  let inputs_from_scripts = get_all_validators_inputs(transaction)

  let only_one_input_from_script: Bool = list.length(inputs_from_scripts) == 1

  expect Some(output_to_positions) = list.at(transaction.outputs, output_index)

  expect InlineDatum(output_datum) = output_to_positions.datum

  expect Script(output_script_hash) =
    output_to_positions.address.payment_credential

  let output_script_hash_valid = output_script_hash == position_hash

  let expected_positions_datum =
    PositionDatum {
      owner_address_hash,
      position_hash,
      underlying_asset,
      entered_at_usd_price,
      leverage_factor,
      position_asset_amount,
      collateral_asset,
      collateral_asset_amount,
      strike_asset_amount,
      stop_loss_usd_price,
      take_profit_usd_price,
      last_pay_lend_time,
      hourly_usd_borrow_fee,
      margin_requirement,
      side,
    }

  let expected_positions_datum_data: Data = expected_positions_datum

  let datum_match = expected_positions_datum_data == output_datum

  let expected_assets_sent_back: Value =
    assets.from_asset(position_hash, owner_address_hash, 1)
      |> assets.add(
          collateral_asset.policy_id,
          collateral_asset.asset_name,
          collateral_asset_amount,
        )
      |> assets.add(strike_policy_id, strike_asset_name, strike_asset_amount)
  let assets_locked_valid =
    match(output_to_positions.value, expected_assets_sent_back, >=)

  let signed_by_owner =
    list.has(transaction.extra_signatories, owner_address_hash)

  output_script_hash_valid && datum_match && assets_locked_valid && signed_by_owner && only_one_input_from_script
}

fn calculate_profit(
  side: PositionSide,
  current_position_value: Int,
  entry_position_value: Int,
) -> Int {
  if side == Long {
    current_position_value - entry_position_value
  } else {
    entry_position_value - current_position_value
  }
}

fn calculate_return(
  collateral_asset: Asset,
  collateral_asset_amount: Int,
  strike_asset_amount: Int,
  expected_asset_amount_send_to_user: Int,
  current_usd_price: Int,
  pool_output_value: Value,
  pool_output_datum: PoolDatum,
  side: PositionSide,
) -> ClosePositionCalculate {
  if side == Long {
    calculate_long_return_asset_amount(
      collateral_asset,
      collateral_asset_amount,
      strike_asset_amount,
      expected_asset_amount_send_to_user,
      current_usd_price,
      pool_output_value,
      pool_output_datum,
    )
  } else {
    calculate_short_return_asset_amount(
      collateral_asset,
      collateral_asset_amount,
      strike_asset_amount,
      expected_asset_amount_send_to_user,
      current_usd_price,
      pool_output_value,
      pool_output_datum,
    )
  }
}

fn calculate_long_return_asset_amount(
  collateral_asset: Asset,
  collateral_asset_amount: Int,
  strike_asset_amount: Int,
  usd_value: Int,
  current_price: Int,
  pool_output_value: Value,
  pool_output_datum: PoolDatum,
) -> ClosePositionCalculate {
  if usd_value > 0 {
    let expected_asset_sent = divide(usd_value, current_price)

    let expected_assets_locked =
      assets.from_asset(
        collateral_asset.policy_id,
        collateral_asset.asset_name,
        collateral_asset_amount + expected_asset_sent,
      )
        |> assets.add(strike_policy_id, strike_asset_name, strike_asset_amount)

    let updated_value =
      assets.add(
        pool_output_value,
        pool_output_datum.underlying_asset.policy_id,
        pool_output_datum.underlying_asset.asset_name,
        -expected_asset_sent,
      )

    let updated_datum =
      PoolDatum {
        ..pool_output_datum,
        underlying_asset_amount: pool_output_datum.underlying_asset_amount - expected_asset_sent,
      }

    ClosePositionCalculate {
      expected_asset_send_to_owner: expected_assets_locked,
      value: updated_value,
      datum: updated_datum,
    }
  } else {
    let expected_assets_payed = divide(-usd_value, current_price)

    let expected_assets_locked =
      assets.from_asset(
        collateral_asset.policy_id,
        collateral_asset.asset_name,
        collateral_asset_amount - expected_assets_payed,
      )
        |> assets.add(strike_policy_id, strike_asset_name, strike_asset_amount)

    let updated_value =
      assets.add(
        pool_output_value,
        pool_output_datum.underlying_asset.policy_id,
        pool_output_datum.underlying_asset.asset_name,
        expected_assets_payed,
      )

    let updated_datum =
      PoolDatum {
        ..pool_output_datum,
        underlying_asset_amount: pool_output_datum.underlying_asset_amount + expected_assets_payed,
      }

    ClosePositionCalculate {
      expected_asset_send_to_owner: expected_assets_locked,
      value: updated_value,
      datum: updated_datum,
    }
  }
}

fn calculate_short_return_asset_amount(
  collateral_asset: Asset,
  collateral_asset_amount: Int,
  strike_asset_amount: Int,
  usd_value: Int,
  current_usd_price: Int,
  pool_output_value: Value,
  pool_output_datum: PoolDatum,
) -> ClosePositionCalculate {
  if usd_value > 0 {
    let expected_assets_sent = divide(usd_value, current_usd_price)

    let expected_assets_locked =
      assets.from_asset(
        collateral_asset.policy_id,
        collateral_asset.asset_name,
        collateral_asset_amount,
      )
        |> assets.add(strike_policy_id, strike_asset_name, strike_asset_amount)
        |> assets.add(
            pool_output_datum.underlying_asset.policy_id,
            pool_output_datum.underlying_asset.asset_name,
            expected_assets_sent,
          )

    let updated_value =
      assets.add(
        pool_output_value,
        pool_output_datum.underlying_asset.policy_id,
        pool_output_datum.underlying_asset.asset_name,
        -expected_assets_sent,
      )

    let updated_datum =
      PoolDatum {
        ..pool_output_datum,
        underlying_asset_amount: pool_output_datum.underlying_asset_amount - expected_assets_sent,
      }

    ClosePositionCalculate {
      expected_asset_send_to_owner: expected_assets_locked,
      value: updated_value,
      datum: updated_datum,
    }
  } else {
    let usd_payed = usd_value * -1

    let formatted_usd_payed =
      format_stable_if_lovelace(pool_output_datum.underlying_asset, usd_payed)

    let expected_assets_locked =
      assets.from_asset(
        collateral_asset.policy_id,
        collateral_asset.asset_name,
        collateral_asset_amount - formatted_usd_payed,
      )
        |> assets.add(strike_policy_id, strike_asset_name, strike_asset_amount)

    let updated_value =
      assets.add(
        pool_output_value,
        pool_output_datum.underlying_asset.policy_id,
        pool_output_datum.underlying_asset.asset_name,
        formatted_usd_payed,
      )

    let updated_datum =
      PoolDatum {
        ..pool_output_datum,
        stable_collateral_asset_amount: pool_output_datum.stable_collateral_asset_amount + formatted_usd_payed,
      }

    ClosePositionCalculate {
      expected_asset_send_to_owner: expected_assets_locked,
      value: updated_value,
      datum: updated_datum,
    }
  }
}

fn is_strike_collateral_asset_burnt(
  strike_asset_amount: Int,
  expected_burn_address: ScriptHash,
  output: Output,
) -> Bool {
  if strike_asset_amount > 0 {
    expect Script(burn_address) = output.address.payment_credential

    let burn_address_valid = expected_burn_address == burn_address

    let expected_assets_locked =
      assets.from_asset(
        strike_policy_id,
        strike_asset_name,
        strike_asset_amount,
      )

    match(output.value, expected_assets_locked, >=) && burn_address_valid
  } else {
    True
  }
}
