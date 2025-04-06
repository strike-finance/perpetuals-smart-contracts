use aiken/collection/list
use aiken/crypto.{ScriptHash}
use cardano/address.{Address, Script}
use cardano/assets.{Value, match, quantity_of, zero}
use cardano/transaction.{InlineDatum, Input, Output, Transaction}
use constants.{strike_asset_name, strike_policy_id}
use math.{calculate_assets_get_back, calculate_lp_assets_sent}
use types.{
  Asset, AutomatedClosePositionOrder, ClosePositionOrder, ExpectedPoolOutput,
  LiquidatePositionOrder, OpenPositionOrder, OrderDatum, PoolDatum,
  PositionDatum, ProvideLiquidityOrder, WithdrawLiquidityOrder,
}

// Make distinction when closing position, if profit add to pool, if loss remove from pool
pub fn valid_orders(
  indices: List<(Int, Int)>,
  transaction: Transaction,
  own_validator: ScriptHash,
  pool_utxo_value: Value,
  pool_datum: PoolDatum,
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
    AutomatedClosePositionOrder(..) ->
      automated_close_position(
        input_datum_typed,
        output,
        pool_output_value,
        pool_output_datum,
        expected_mint,
      )
    LiquidatePositionOrder(..) ->
      liquidate_position(
        input,
        input_datum_typed,
        pool_output_value,
        pool_output_datum,
        expected_mint,
      )
    ProvideLiquidityOrder(..) ->
      provide_liquidity_valid(
        input,
        input_datum_typed,
        output,
        pool_output_value,
        pool_output_datum,
        expected_mint,
      )
    WithdrawLiquidityOrder(..) ->
      withdraw_liquidy_valid(
        input,
        input_datum_typed,
        output,
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
  expect OpenPositionOrder {
    position_datum: PositionDatum {
      owner_pkh,
      leverage_factor,
      position_hash,
      entered_at_usd_price,
      entered_position_time,
      maintain_margin_amount,
      hourly_usd_borrow_fee,
      stop_loss_usd_price,
      take_profit_usd_price,
      collateral_asset,
      side,
      collateral_asset_amount,
      position_asset_amount,
      owner_stake_key,
    },
    ..
  } = input_datum_typed.action

  let expected_output_datum =
    PositionDatum {
      owner_pkh,
      leverage_factor,
      position_hash,
      entered_at_usd_price,
      entered_position_time,
      maintain_margin_amount,
      hourly_usd_borrow_fee,
      stop_loss_usd_price,
      take_profit_usd_price,
      collateral_asset,
      side,
      collateral_asset_amount,
      position_asset_amount,
      owner_stake_key,
    }

  expect InlineDatum(output_datum) = output.datum

  let expected_output_datum_data: Data = expected_output_datum

  expect output_datum == expected_output_datum_data

  let lended_amount: Int = position_asset_amount - collateral_asset_amount

  let PoolDatum { underlying_asset, .. } = pool_output_datum

  let input_added_lended_amount =
    input.value
      |> assets.add(
          underlying_asset.policy_id,
          underlying_asset.asset_name,
          lended_amount,
        )

  expect match(output.value, input_added_lended_amount, <=)

  expect Script(output_script_hash) = output.address.payment_credential

  expect output_script_hash == position_hash

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
  expect ClosePositionOrder { pool_asset_profit_loss } = datum.action

  let PoolDatum { underlying_asset, liquidity_total_gains_losses, .. } =
    pool_output_datum

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
      liquidity_total_gains_losses: liquidity_total_gains_losses + pool_asset_profit_loss,
    },
    mint: expected_mint,
  }
}

pub fn automated_close_position(
  datum: OrderDatum,
  output: Output,
  pool_output_value: Value,
  pool_output_datum: PoolDatum,
  expected_mint: Value,
) -> ExpectedPoolOutput {
  expect AutomatedClosePositionOrder {
    owner_pkh,
    owner_stake_key,
    send_asset_amount,
    send_asset,
    return_pool_asset_amount,
    pool_asset_profit_loss,
    strike_collateral_amount,
  } = datum.action

  let PoolDatum { underlying_asset, liquidity_total_gains_losses, .. } =
    pool_output_datum

  let owner_address =
    when owner_stake_key is {
      Some(key) ->
        address.from_verification_key(owner_pkh)
          |> address.with_delegation_key(key)
      None -> address.from_verification_key(owner_pkh)
    }

  expect output.address == owner_address

  expect
    quantity_of(output.value, send_asset.policy_id, send_asset.asset_name) == send_asset_amount

  expect
    quantity_of(output.value, strike_policy_id, strike_asset_name) == strike_collateral_amount

  ExpectedPoolOutput {
    value: pool_output_value
      |> assets.add(
          underlying_asset.policy_id,
          underlying_asset.asset_name,
          return_pool_asset_amount,
        ),
    datum: PoolDatum {
      ..pool_output_datum,
      liquidity_total_gains_losses: liquidity_total_gains_losses + pool_asset_profit_loss,
    },
    mint: expected_mint,
  }
}

pub fn liquidate_position(
  input: Output,
  datum: OrderDatum,
  pool_output_value: Value,
  pool_output_datum: PoolDatum,
  expected_mint: Value,
) -> ExpectedPoolOutput {
  expect LiquidatePositionOrder { profit } = datum.action

  let PoolDatum { liquidity_total_gains_losses, .. } = pool_output_datum

  let asset_amount_returned: Int =
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
      asset_amount_returned,
    )

  ExpectedPoolOutput {
    value: updated_value,
    datum: PoolDatum {
      ..pool_output_datum,
      liquidity_total_gains_losses: liquidity_total_gains_losses + profit,
    },
    mint: expected_mint,
  }
}

fn provide_liquidity_valid(
  input: Output,
  input_datum_typed: OrderDatum,
  output: Output,
  pool_output_value: Value,
  pool_output_datum: PoolDatum,
  expected_mint: Value,
) -> ExpectedPoolOutput {
  expect ProvideLiquidityOrder { owner_pkh, owner_stake_key, liquidity_asset } =
    input_datum_typed.action

  let PoolDatum {
    lp_asset,
    liquidity_total_asset_amount,
    liquidity_total_lp_minted,
    ..
  } = pool_output_datum

  let liquidity_amount =
    quantity_of(
      input.value,
      liquidity_asset.policy_id,
      liquidity_asset.asset_name,
    )

  let expected_lp_token_sent =
    calculate_lp_assets_sent(
      liquidity_total_asset_amount,
      liquidity_total_lp_minted,
      liquidity_amount,
    )

  let lp_tokens_sent =
    quantity_of(output.value, lp_asset.policy_id, lp_asset.asset_name)

  expect lp_tokens_sent <= expected_lp_token_sent

  let owner_address =
    when owner_stake_key is {
      Some(key) ->
        address.from_verification_key(owner_pkh)
          |> address.with_delegation_key(key)
      None -> address.from_verification_key(owner_pkh)
    }

  expect owner_address == output.address

  ExpectedPoolOutput {
    value: pool_output_value,
    datum: PoolDatum {
      ..pool_output_datum,
      liquidity_total_lp_minted: liquidity_total_lp_minted + lp_tokens_sent,
      liquidity_total_asset_amount: liquidity_total_asset_amount + liquidity_amount,
    },
    mint: expected_mint,
  }
}

fn withdraw_liquidy_valid(
  input: Output,
  input_datum_typed: OrderDatum,
  output: Output,
  pool_output_value: Value,
  pool_output_datum: PoolDatum,
  expected_mint: Value,
) -> ExpectedPoolOutput {
  expect WithdrawLiquidityOrder { owner_pkh, owner_stake_key } =
    input_datum_typed.action

  let PoolDatum {
    underlying_asset,
    liquidity_total_lp_minted,
    lp_asset,
    liquidity_total_asset_amount,
    ..
  } = pool_output_datum

  let lp_tokens_deposited =
    quantity_of(input.value, lp_asset.policy_id, lp_asset.asset_name)

  let expected_assets_sent =
    calculate_assets_get_back(
      liquidity_total_asset_amount,
      liquidity_total_lp_minted,
      lp_tokens_deposited,
    )

  let assets_sent =
    quantity_of(
      output.value,
      underlying_asset.policy_id,
      underlying_asset.asset_name,
    )

  expect assets_sent <= expected_assets_sent

  let owner_address =
    when owner_stake_key is {
      Some(key) ->
        address.from_verification_key(owner_pkh)
          |> address.with_delegation_key(key)
      None -> address.from_verification_key(owner_pkh)
    }

  expect owner_address == output.address

  ExpectedPoolOutput {
    value: pool_output_value,
    datum: PoolDatum {
      ..pool_output_datum,
      liquidity_total_lp_minted: liquidity_total_lp_minted - lp_tokens_deposited,
      liquidity_total_asset_amount: liquidity_total_asset_amount - assets_sent,
    },
    mint: expected_mint,
  }
}
