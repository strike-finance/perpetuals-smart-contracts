use aiken/collection/list
use aiken/crypto.{ScriptHash}
use cardano/address.{Address, Script}
use cardano/assets.{Value, match, quantity_of, zero}
use cardano/transaction.{InlineDatum, Input, Output, Transaction}
use constants.{
  long_lp_name, position_asset_name, short_lp_name, strike_asset_name,
  strike_policy_id,
}
use math.{calculate_assets_get_back, calculate_lp_assets_sent}
use types.{
  Asset, ClosePositionOrder, ExpectedPoolOutput, LiquidatePositionOrder, Long,
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
  expect OpenPositionOrder{position_datum: PositionDatum {
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
  }} = input_datum_typed.action

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

  if side == Long {
    ExpectedPoolOutput {
      value: pool_output_value
        |> assets.add(
            pool_output_datum.underlying_asset.policy_id,
            pool_output_datum.underlying_asset.asset_name,
            -lended_amount,
          ),
      datum: PoolDatum {
        ..pool_output_datum,
        long_total_asset_amount: pool_output_datum.long_total_asset_amount - lended_amount,
        long_available_asset_amount: pool_output_datum.long_available_asset_amount - lended_amount,
      },
      mint: expected_mint,
    }
  } else {
    ExpectedPoolOutput {
      value: pool_output_value
        |> assets.add(
            pool_output_datum.underlying_asset.policy_id,
            pool_output_datum.underlying_asset.asset_name,
            -lended_amount,
          ),
      datum: PoolDatum {
        ..pool_output_datum,
        short_total_asset_amount: pool_output_datum.short_total_asset_amount - lended_amount,
        short_available_asset_amount: pool_output_datum.short_available_asset_amount - lended_amount,
      },
      mint: expected_mint,
    }
  }
}

pub fn close_position(
  input: Output,
  datum: OrderDatum,
  pool_output_value: Value,
  pool_output_datum: PoolDatum,
  expected_mint: Value,
) -> ExpectedPoolOutput {
  expect ClosePositionOrder { position_hash, underlying_asset_amount, side } =
    datum.action

  let PoolDatum { underlying_asset, .. } = pool_output_datum

  let mint = assets.add(expected_mint, position_hash, position_asset_name, -1)

  let return_pool_asset_amount =
    quantity_of(
      input.value,
      underlying_asset.policy_id,
      underlying_asset.asset_name,
    )

  if side == Long {
    ExpectedPoolOutput {
      value: pool_output_value
        |> assets.add(
            underlying_asset.policy_id,
            underlying_asset.asset_name,
            return_pool_asset_amount,
          ),
      datum: PoolDatum {
        ..pool_output_datum,
        long_total_asset_amount: pool_output_datum.long_total_asset_amount + underlying_asset_amount,
      },
      mint,
    }
  } else {
    ExpectedPoolOutput {
      value: pool_output_value
        |> assets.add(
            underlying_asset.policy_id,
            underlying_asset.asset_name,
            -return_pool_asset_amount,
          ),
      datum: PoolDatum {
        ..pool_output_datum,
        short_total_asset_amount: pool_output_datum.short_total_asset_amount + underlying_asset_amount,
      },
      mint,
    }
  }
}

pub fn liquidate_position(
  input: Output,
  input_datum_typed: OrderDatum,
  output: Output,
  pool_output_value: Value,
  pool_output_datum: PoolDatum,
  expected_mint: Value,
  expected_burn_address: ScriptHash,
) -> ExpectedPoolOutput {
  expect LiquidatePositionOrder { position_hash, underlying_asset_amount, side } =
    input_datum_typed.action

  let strike_asset_amount: Int =
    quantity_of(input.value, strike_policy_id, strike_asset_name)

  let contains_strike_collateral = strike_asset_amount > 0

  expect
    if contains_strike_collateral {
      expect Script(burn_address) = output.address.payment_credential
      expect expected_burn_address == burn_address

      let expected_assets_locked =
        assets.from_asset(
          strike_policy_id,
          strike_asset_name,
          strike_asset_amount,
        )

      match(output.value, expected_assets_locked, >=)
    } else {
      True
    }

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

  if side == Long {
    ExpectedPoolOutput {
      value: updated_value,
      datum: PoolDatum {
        ..pool_output_datum,
        long_total_asset_amount: pool_output_datum.long_total_asset_amount + underlying_asset_amount,
        long_available_asset_amount: pool_output_datum.long_available_asset_amount + underlying_asset_amount,
      },
      mint: updated_mint,
    }
  } else {
    ExpectedPoolOutput {
      value: updated_value,
      datum: PoolDatum {
        ..pool_output_datum,
        short_total_asset_amount: pool_output_datum.short_total_asset_amount + underlying_asset_amount,
        short_available_asset_amount: pool_output_datum.short_total_asset_amount + underlying_asset_amount,
      },
      mint: updated_mint,
    }
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
  expect ProvideLiquidityOrder {
    owner_pkh,
    owner_stake_key,
    long_liquidity_amount,
    short_liquidity_amount,
  } = input_datum_typed.action

  let PoolDatum {
    underlying_asset,
    long_total_asset_amount,
    long_total_lp_minted,
    short_total_asset_amount,
    short_total_lp_minted,
    lp_policy_id,
    ..
  } = pool_output_datum

  expect
    quantity_of(
      input.value,
      underlying_asset.policy_id,
      underlying_asset.asset_name,
    ) >= long_liquidity_amount + short_liquidity_amount

  let (expected_long_lp_token_sent, expected_short_lp_token_sent) =
    (
      calculate_lp_assets_sent(
        long_total_asset_amount,
        long_total_lp_minted,
        long_liquidity_amount,
      ),
      calculate_lp_assets_sent(
        short_total_asset_amount,
        short_total_lp_minted,
        short_liquidity_amount,
      ),
    )

  let (long_lp_token_sent, short_lp_token_sent) =
    (
      quantity_of(output.value, lp_policy_id, long_lp_name),
      quantity_of(output.value, lp_policy_id, short_lp_name),
    )

  expect
    long_lp_token_sent <= expected_long_lp_token_sent && short_lp_token_sent <= expected_short_lp_token_sent

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
      long_total_lp_minted: long_total_lp_minted + long_lp_token_sent,
      long_available_asset_amount: long_total_asset_amount + long_liquidity_amount,
      short_total_lp_minted: short_total_lp_minted + short_lp_token_sent,
      short_available_asset_amount: short_total_asset_amount + short_liquidity_amount,
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
    long_total_asset_amount,
    long_total_lp_minted,
    short_total_asset_amount,
    short_total_lp_minted,
    lp_policy_id,
    underlying_asset,
    ..
  } = pool_output_datum

  let (long_lp_deposited, short_lp_deposited) =
    (
      quantity_of(input.value, lp_policy_id, long_lp_name),
      quantity_of(input.value, lp_policy_id, short_lp_name),
    )

  let (expected_long_assets_sent, expected_short_assets_sent) =
    (
      calculate_assets_get_back(
        long_total_asset_amount,
        long_total_lp_minted,
        long_lp_deposited,
      ),
      calculate_assets_get_back(
        short_total_asset_amount,
        short_total_lp_minted,
        short_lp_deposited,
      ),
    )

  let assets_sent =
    quantity_of(
      output.value,
      underlying_asset.policy_id,
      underlying_asset.asset_name,
    )

  expect assets_sent <= expected_long_assets_sent + expected_short_assets_sent

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
      long_total_lp_minted: long_total_lp_minted - long_lp_deposited,
      long_available_asset_amount: long_total_asset_amount - expected_long_assets_sent,
      short_total_lp_minted: short_total_lp_minted - short_lp_deposited,
      short_available_asset_amount: short_total_asset_amount - expected_short_assets_sent,
    },
    mint: expected_mint,
  }
}
