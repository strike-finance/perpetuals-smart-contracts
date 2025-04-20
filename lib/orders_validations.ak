use aiken/collection/list
use aiken/crypto.{ScriptHash}
use cardano/address.{Address, Script}
use cardano/assets.{Value, quantity_of, zero}
use cardano/transaction.{InlineDatum, Input, Output, Transaction}
use constants.{position_asset_name}
use math.{calculate_assets_get_back, calculate_lp_assets_sent}
use types.{
  Asset, ClosePositionOrder, ExpectedPoolOutput, LimitOrder,
  LiquidatePositionOrder, Long, OpenPositionOrder, OrderDatum, PoolDatum,
  PositionDatum, ProvideLiquidityOrder, WithdrawLiquidityOrder,
}

// Make distinction when closing position, if profit add to pool, if loss remove from pool
pub fn valid_orders(
  indices: List<(Int, Int)>,
  transaction: Transaction,
  own_validator: ScriptHash,
  underlying_asset_amount: Int,
  pool_datum: PoolDatum,
  current_usd_price: Int,
) -> ExpectedPoolOutput {
  let Transaction { inputs, outputs, .. } = transaction
  let script_input_count =
    list.foldr(
      inputs,
      0,
      fn(i, count) {
        let Input { output, .. } = i
        when output.address.payment_credential is {
          Script(script) ->
            if script == own_validator {
              count + 1
            } else {
              count
            }
          _ -> count
        }
      },
    )

  let (
    _,
    _,
    input_index_count,
    expected_underlying_asset_amount,
    expected_pool_output_datum,
    expected_mint,
  ) =
    list.foldl(
      indices,
      (-1, -1, 0, underlying_asset_amount, pool_datum, zero),
      fn(curr, acc) {
        let (
          in0,
          out0,
          count,
          expected_underlying_asset_amount,
          expected_pool_output_datum,
          expected_mint,
        ) = acc
        let (in1, out1) = curr

        if in1 > in0 && out1 > out0 {
          expect Some(in_utxo) = inputs |> list.at(in1)
          expect Some(out_utxo) = outputs |> list.at(out1)
          let ExpectedPoolOutput {
            underlying_asset_amount: updated_underlying_asset_amount,
            datum: updated_datum,
            mint: updated_expected_mint,
          } =
            validate_individual_order(
              in_utxo.output,
              out_utxo,
              expected_underlying_asset_amount,
              expected_pool_output_datum,
              expected_mint,
              current_usd_price,
            )

          (
            in1,
            out1,
            count + 1,
            updated_underlying_asset_amount,
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
      underlying_asset_amount: expected_underlying_asset_amount,
      datum: expected_pool_output_datum,
      mint: expected_mint,
    }

  expected_pool_output
}

pub fn validate_individual_order(
  input: Output,
  output: Output,
  underlying_asset_amount: Int,
  pool_output_datum: PoolDatum,
  expected_mint: Value,
  current_usd_price: Int,
) -> ExpectedPoolOutput {
  expect InlineDatum(input_datum) = input.datum

  expect input_datum_typed: OrderDatum = input_datum

  when input_datum_typed.action is {
    OpenPositionOrder(..) ->
      open_position(
        input_datum_typed,
        output,
        underlying_asset_amount,
        pool_output_datum,
        expected_mint,
        current_usd_price,
      )
    ClosePositionOrder(..) ->
      close_position(
        input_datum_typed,
        output,
        underlying_asset_amount,
        pool_output_datum,
        expected_mint,
      )
    LiquidatePositionOrder(..) ->
      liquidate_position(
        input_datum_typed,
        underlying_asset_amount,
        pool_output_datum,
        expected_mint,
      )
    ProvideLiquidityOrder(..) ->
      provide_liquidity_valid(
        input,
        input_datum_typed,
        output,
        underlying_asset_amount,
        pool_output_datum,
        expected_mint,
      )
    WithdrawLiquidityOrder(..) ->
      withdraw_liquidy_valid(
        input,
        input_datum_typed,
        output,
        underlying_asset_amount,
        pool_output_datum,
        expected_mint,
      )
  }
}

pub fn open_position(
  input_datum_typed: OrderDatum,
  output: Output,
  underlying_asset_amount: Int,
  pool_output_datum: PoolDatum,
  expected_mint: Value,
  current_usd_price: Int,
) -> ExpectedPoolOutput {
  expect OpenPositionOrder {
    position_datum: PositionDatum {
      owner_pkh,
      position_policy_id,
      manage_positions_script_hash,
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
    open_position_type,
  } = input_datum_typed.action

  let expected_output_datum =
    PositionDatum {
      owner_pkh,
      position_policy_id,
      manage_positions_script_hash,
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

  expect quantity_of(output.value, position_policy_id, position_asset_name) == 1

  expect Script(output_script_hash) = output.address.payment_credential

  expect output_script_hash == manage_positions_script_hash

  expect
    when open_position_type == LimitOrder is {
      True ->
        if side == Long {
          current_usd_price <= entered_at_usd_price
        } else {
          current_usd_price >= entered_at_usd_price
        }
      _ -> True
    }

  ExpectedPoolOutput {
    underlying_asset_amount,
    datum: PoolDatum {
      ..pool_output_datum,
      total_lended_amount: pool_output_datum.total_lended_amount + lended_amount,
    },
    mint: expected_mint,
  }
}

pub fn close_position(
  datum: OrderDatum,
  output: Output,
  underlying_asset_amount: Int,
  pool_output_datum: PoolDatum,
  expected_mint: Value,
) -> ExpectedPoolOutput {
  expect ClosePositionOrder {
    owner_pkh,
    owner_stake_key,
    send_asset,
    send_asset_amount,
    pool_asset_profit_loss,
    position_policy_id,
    borrowed_amount,
  } = datum.action

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

  ExpectedPoolOutput {
    underlying_asset_amount: underlying_asset_amount - send_asset_amount,
    datum: PoolDatum {
      ..pool_output_datum,
      liquidity_total_asset_amount: pool_output_datum.liquidity_total_asset_amount + pool_asset_profit_loss,
      total_lended_amount: pool_output_datum.total_lended_amount - borrowed_amount,
    },
    mint: expected_mint
      |> assets.add(position_policy_id, position_asset_name, -1),
  }
}

// Since all assets is already in pool, and user's position got liquidated, no assets from pool is sent
pub fn liquidate_position(
  datum: OrderDatum,
  underlying_asset_amount: Int,
  pool_output_datum: PoolDatum,
  expected_mint: Value,
) -> ExpectedPoolOutput {
  expect LiquidatePositionOrder { profit, lended_amount, position_policy_id } =
    datum.action

  ExpectedPoolOutput {
    underlying_asset_amount,
    datum: PoolDatum {
      ..pool_output_datum,
      liquidity_total_asset_amount: pool_output_datum.liquidity_total_asset_amount + profit,
      total_lended_amount: pool_output_datum.total_lended_amount - lended_amount,
    },
    mint: expected_mint
      |> assets.add(position_policy_id, position_asset_name, -1),
  }
}

fn provide_liquidity_valid(
  input: Output,
  input_datum_typed: OrderDatum,
  output: Output,
  underlying_asset_amount: Int,
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
    underlying_asset_amount: underlying_asset_amount + liquidity_amount,
    datum: PoolDatum {
      ..pool_output_datum,
      liquidity_total_lp_minted: liquidity_total_lp_minted + lp_tokens_sent,
      liquidity_total_asset_amount: liquidity_total_asset_amount + liquidity_amount,
    },
    mint: expected_mint
      |> assets.add(lp_asset.policy_id, lp_asset.asset_name, lp_tokens_sent),
  }
}

fn withdraw_liquidy_valid(
  input: Output,
  input_datum_typed: OrderDatum,
  output: Output,
  underlying_asset_amount: Int,
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

  expect assets_sent == expected_assets_sent

  let owner_address =
    when owner_stake_key is {
      Some(key) ->
        address.from_verification_key(owner_pkh)
          |> address.with_delegation_key(key)
      None -> address.from_verification_key(owner_pkh)
    }

  expect owner_address == output.address

  ExpectedPoolOutput {
    underlying_asset_amount: underlying_asset_amount - assets_sent,
    datum: PoolDatum {
      ..pool_output_datum,
      liquidity_total_lp_minted: liquidity_total_lp_minted - lp_tokens_deposited,
      liquidity_total_asset_amount: liquidity_total_asset_amount - assets_sent,
    },
    mint: expected_mint
      |> assets.add(lp_asset.policy_id, lp_asset.asset_name, -lp_tokens_deposited),
  }
}
