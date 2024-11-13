use aiken/collection/list
use aiken/crypto.{ScriptHash}
use cardano/address.{Address, Script, VerificationKey}
use cardano/assets.{
  AssetName, PolicyId, Value, flatten, match, quantity_of, zero,
}
use cardano/transaction.{InlineDatum, Input, Output, Transaction}
use constants.{strike_asset_name, strike_policy_id}
use types.{
  Asset, ClosePositionOrder, ExpectedPoolOutput, LiquidatePositionOrder, Long,
  LongCloseOrder, OpenPositionOrder, OrderDatum, PoolDatum, PositionDatum,
  ShortCloseOrder,
}
use utils.{get_all_validators_inputs, get_collateral_asset}

pub fn valid_orders(
  indices: List<(Int, Int)>,
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
        output,
        pool_output_value,
        pool_output_datum,
        expected_mint,
        burn_address,
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
    owner_address_hash,
    position_hash,
    leverage_factor,
    side,
    order_submission_time,
    order_submission_usd_price,
    maintain_margin_amount,
    hourly_usd_borrow_fee,
    position_asset_amount,
  } = input_datum_typed.action

  let PoolDatum { underlying_asset, stable_asset, .. } = pool_output_datum

  let collateral_asset =
    get_collateral_asset(
      underlying_asset.policy_id,
      underlying_asset.asset_name,
      stable_asset.policy_id,
      stable_asset.asset_name,
      side,
    )

  let expected_output_datum =
    PositionDatum {
      owner_address_hash,
      position_hash,
      entered_at_usd_price: order_submission_usd_price,
      leverage_factor,
      position_asset_amount,
      stop_loss_usd_price: 0,
      take_profit_usd_price: 0,
      entered_position_time: order_submission_time,
      maintain_margin_amount,
      collateral_asset,
      hourly_usd_borrow_fee,
      side,
    }

  let assets_locked_valid = match(output.value, input.value, >=)

  expect InlineDatum(output_datum) = output.datum

  expect output_datum_typed: PositionDatum = output_datum

  expect Script(output_script_hash) = output.address.payment_credential

  let output_script_hash_valid = output_script_hash == position_hash

  let lended_amount: Int = position_asset_amount / leverage_factor

  let datum_valid = output_datum_typed == expected_output_datum

  expect assets_locked_valid && datum_valid && output_script_hash_valid

  ExpectedPoolOutput {
    value: pool_output_value,
    datum: PoolDatum {
      ..pool_output_datum,
      underlying_asset_lended_amount: pool_output_datum.underlying_asset_lended_amount + lended_amount,
    },
    mint: expected_mint,
  }
}

pub fn close_position(
  datum: OrderDatum,
  output: Output,
  pool_output_value: Value,
  pool_output_datum: PoolDatum,
  expected_mint: Value,
) -> ExpectedPoolOutput {
  expect ClosePositionOrder {
    owner_address_hash,
    side,
    position_hash,
    return_amount,
    ..
  } = datum.action

  let PoolDatum { underlying_asset, stable_asset, .. } = pool_output_datum

  expect VerificationKey(output_owner_address_hash) =
    output.address.payment_credential

  let output_is_to_owner = owner_address_hash == output_owner_address_hash

  let mint = assets.add(expected_mint, position_hash, owner_address_hash, -1)

  expect output_is_to_owner

  if side == Long {
    expect LongCloseOrder { asset_amount } = return_amount

    let estimated_return =
      assets.from_asset(
        pool_output_datum.underlying_asset.policy_id,
        pool_output_datum.underlying_asset.asset_name,
        asset_amount,
      )

    expect match(output.value, estimated_return, <=)

    ExpectedPoolOutput {
      value: pool_output_value
        |> assets.add(
            underlying_asset.policy_id,
            underlying_asset.asset_name,
            asset_amount,
          ),
      datum: pool_output_datum,
      mint,
    }
  } else {
    expect ShortCloseOrder { collateral_amount, asset_amount } = return_amount

    let estimated_return =
      assets.from_asset(
        underlying_asset.policy_id,
        underlying_asset.asset_name,
        asset_amount,
      )
        |> assets.add(
            stable_asset.policy_id,
            stable_asset.asset_name,
            collateral_amount,
          )

    expect match(output.value, estimated_return, <=)

    ExpectedPoolOutput {
      value: pool_output_value
        |> assets.add(
            stable_asset.policy_id,
            stable_asset.asset_name,
            collateral_amount,
          )
        |> assets.add(
            underlying_asset.policy_id,
            underlying_asset.asset_name,
            asset_amount,
          ),
      datum: pool_output_datum,
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
  burn_address: ScriptHash,
) -> ExpectedPoolOutput {
  expect LiquidatePositionOrder {
    position_hash,
    side,
    owner_address_hash,
    position_asset_amount,
    leverage_factor,
  } = input_datum_typed.action

  let strike_is_burnt = is_strike_collateral_asset_burnt(burn_address, output)

  expect strike_is_burnt

  let updated_mint =
    assets.add(expected_mint, position_hash, owner_address_hash, -1)

  let lended_amount: Int = position_asset_amount / leverage_factor

  let updated_datum =
    PoolDatum {
      ..pool_output_datum,
      underlying_asset_lended_amount: pool_output_datum.underlying_asset_lended_amount - lended_amount,
    }

  if side == Long {
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
      datum: updated_datum,
      mint: updated_mint,
    }
  } else {
    let collateral_asset_amount: Int =
      quantity_of(
        input.value,
        pool_output_datum.stable_asset.policy_id,
        pool_output_datum.stable_asset.asset_name,
      )

    let updated_value =
      assets.add(
        pool_output_value,
        pool_output_datum.stable_asset.policy_id,
        pool_output_datum.stable_asset.asset_name,
        collateral_asset_amount,
      )

    ExpectedPoolOutput {
      value: updated_value,
      datum: updated_datum,
      mint: updated_mint,
    }
  }
}

pub fn cancel_open_position_valid(
  datum: OrderDatum,
  transaction: Transaction,
) -> Bool {
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

pub fn cancel_close_position_valid(
  datum: OrderDatum,
  transaction: Transaction,
  output_index: Int,
  underlying_asset_policy_id: PolicyId,
  underlying_asset_name: AssetName,
  stable_asset_policy_id: PolicyId,
  stable_asset_name: AssetName,
) -> Bool {
  expect ClosePositionOrder {
    owner_address_hash,
    position_hash,
    leverage_factor,
    entered_at_usd_price,
    stop_loss_usd_price,
    take_profit_usd_price,
    entered_position_time,
    position_asset_amount,
    maintain_margin_amount,
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

  let collateral_asset =
    get_collateral_asset(
      underlying_asset_policy_id,
      underlying_asset_name,
      stable_asset_policy_id,
      stable_asset_name,
      side,
    )

  let expected_positions_datum =
    PositionDatum {
      owner_address_hash,
      position_hash,
      entered_at_usd_price,
      leverage_factor,
      position_asset_amount,
      stop_loss_usd_price,
      take_profit_usd_price,
      entered_position_time,
      hourly_usd_borrow_fee,
      collateral_asset,
      maintain_margin_amount,
      side,
    }

  let expected_positions_datum_data: Data = expected_positions_datum

  let datum_match = expected_positions_datum_data == output_datum

  let assets_locked_valid =
    match(output_to_positions.value, output_to_positions.value, >=)

  let signed_by_owner =
    list.has(transaction.extra_signatories, owner_address_hash)

  output_script_hash_valid && datum_match && assets_locked_valid && signed_by_owner && only_one_input_from_script
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
