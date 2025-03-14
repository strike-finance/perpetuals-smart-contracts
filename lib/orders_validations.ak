use aiken/collection/list
use aiken/crypto.{ScriptHash}
use cardano/address.{Address, Script}
use cardano/assets.{Value, match, quantity_of, zero}
use cardano/transaction.{InlineDatum, Input, Output, Transaction}
use constants.{position_asset_name, strike_asset_name, strike_policy_id}
use types.{
  Asset, ClosePositionOrder, ExpectedPoolOutput, LiquidatePositionOrder,
  OpenPositionOrder, OrderDatum, PoolDatum, PositionDatum, ProvideLiquidityOrder,
  WithdrawLiquidityOrder,
}

pub fn valid_orders(
  indices: List<(Int, Int)>,
  transaction: Transaction,
  own_validator: ScriptHash,
  pool_utxo_value: Value,
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
      (-1, -1, 0, pool_utxo_value, pool_datum, zero),
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
            validate_individual_order(
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
        input,
        input_datum_typed,
        output,
        pool_output_value,
        pool_output_datum,
        expected_mint,
      )
    ClosePositionOrder(..) ->
      close_position(
        input,
        input_datum_typed,
        pool_output_value,
        pool_output_datum,
        expected_mint,
      )
    LiquidatePositionOrder(..) ->
      liquidate_position(
        input,
        input_datum_typed,
        output,
        pool_output_value,
        pool_output_datum,
        expected_mint,
        burn_address,
      )
    ProvideLiquidityOrder(..) ->
      provide_liquidity_valid(
        pool_output_value,
        pool_output_datum,
        expected_mint,
      )
    WithdrawLiquidityOrder(..) ->
      withdraw_liquidy_valid(
        pool_output_value,
        pool_output_datum,
        expected_mint,
      )
  }
}

pub fn open_position(
  input: Output,
  input_datum_typed: OrderDatum,
  output: Output,
  pool_output_value: Value,
  pool_output_datum: PoolDatum,
  expected_mint: Value,
) -> ExpectedPoolOutput {
  expect OpenPositionOrder{position_datum: PositionDatum {
    owner_address_hash,
    leverage_factor,
    position_hash,
    entered_at_usd_price,
    entered_position_time,
    position_asset_amount,
    maintain_margin_amount,
    hourly_usd_borrow_fee,
    stop_loss_usd_price,
    take_profit_usd_price,
    collateral_asset,
    side,
  }} = input_datum_typed.action

  let expected_output_datum =
    PositionDatum {
      owner_address_hash,
      position_hash,
      entered_at_usd_price,
      leverage_factor,
      position_asset_amount,
      stop_loss_usd_price,
      take_profit_usd_price,
      entered_position_time,
      maintain_margin_amount,
      hourly_usd_borrow_fee,
      collateral_asset,
      side,
    }

  let collateral_amount = position_asset_amount / leverage_factor

  let lended_amount: Int = position_asset_amount - collateral_amount

  let input_added_lended_amount =
    input.value
      |> assets.add(
          pool_output_datum.underlying_asset.policy_id,
          pool_output_datum.underlying_asset.asset_name,
          lended_amount,
        )

  expect match(output.value, input_added_lended_amount, <=)

  expect InlineDatum(output_datum) = output.datum

  expect output_datum_typed: PositionDatum = output_datum

  expect Script(output_script_hash) = output.address.payment_credential

  expect output_script_hash == position_hash

  expect output_datum_typed == expected_output_datum

  ExpectedPoolOutput {
    value: pool_output_value
      |> assets.add(
          pool_output_datum.underlying_asset.policy_id,
          pool_output_datum.underlying_asset.asset_name,
          -lended_amount,
        ),
    datum: pool_output_datum,
    mint: expected_mint,
  }
}

pub fn close_position(
  input: Output,
  datum: OrderDatum,
  pool_output_value: Value,
  pool_output_datum: PoolDatum,
  expected_mint: Value,
) -> ExpectedPoolOutput {
  expect ClosePositionOrder { position_hash, underlying_asset_gain_loss } =
    datum.action

  let PoolDatum { underlying_asset, .. } = pool_output_datum

  let mint = assets.add(expected_mint, position_hash, position_asset_name, -1)

  let return_pool_asset_amount =
    quantity_of(
      input.value,
      underlying_asset.policy_id,
      underlying_asset.asset_name,
    )

  ExpectedPoolOutput {
    value: pool_output_value
      |> assets.add(
          underlying_asset.policy_id,
          underlying_asset.asset_name,
          return_pool_asset_amount,
        ),
    datum: PoolDatum {
      ..pool_output_datum,
      total_underlying_asset_amount: pool_output_datum.total_underlying_asset_amount + underlying_asset_gain_loss,
    },
    mint,
  }
}

pub fn liquidate_position(
  input: Output,
  input_datum_typed: OrderDatum,
  output: Output,
  pool_output_value: Value,
  pool_output_datum: PoolDatum,
  expected_mint: Value,
  burn_address: ScriptHash,
) -> ExpectedPoolOutput {
  expect LiquidatePositionOrder { position_hash, underlying_asset_gain } =
    input_datum_typed.action

  let strike_is_burnt = is_strike_collateral_asset_burnt(burn_address, output)

  expect strike_is_burnt

  let updated_mint =
    assets.add(expected_mint, position_hash, position_asset_name, -1)

  let collateral_asset_amount: Int =
    quantity_of(
      input.value,
      pool_output_datum.underlying_asset.policy_id,
      pool_output_datum.underlying_asset.asset_name,
    )

  let updated_value =
    assets.add(
      pool_output_value,
      pool_output_datum.underlying_asset.policy_id,
      pool_output_datum.underlying_asset.asset_name,
      collateral_asset_amount,
    )

  ExpectedPoolOutput {
    value: updated_value,
    datum: PoolDatum {
      ..pool_output_datum,
      total_underlying_asset_amount: pool_output_datum.total_underlying_asset_amount + underlying_asset_gain,
    },
    mint: updated_mint,
  }
}

fn provide_liquidity_valid(
  pool_output_value: Value,
  pool_output_datum: PoolDatum,
  expected_mint: Value,
) -> ExpectedPoolOutput {
  ExpectedPoolOutput {
    value: pool_output_value,
    datum: pool_output_datum,
    mint: expected_mint,
  }
}

fn withdraw_liquidy_valid(
  pool_output_value: Value,
  pool_output_datum: PoolDatum,
  expected_mint: Value,
) -> ExpectedPoolOutput {
  ExpectedPoolOutput {
    value: pool_output_value,
    datum: pool_output_datum,
    mint: expected_mint,
  }
}

fn is_strike_collateral_asset_burnt(
  expected_burn_address: ScriptHash,
  output: Output,
) -> Bool {
  let strike_asset_amount: Int =
    quantity_of(output.value, strike_policy_id, strike_asset_name)

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
