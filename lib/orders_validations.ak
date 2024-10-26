use aiken/collection/list
use aiken/crypto.{ScriptHash}
use cardano/address.{Address, Script, VerificationKey, from_verification_key}
use cardano/assets.{Value, match, quantity_of}
use cardano/transaction.{
  InlineDatum, Input, Output, Transaction, find_script_outputs,
}
use types.{
  Asset, ClosePositionCalculate, ClosePositionOrder, ExpectedPoolOutput,
  LiquidatePositionOrder, LiquidityPositionDatum, Long, OpenPositionOrder,
  OrdersDatum, PoolDatum, PositionDatum, ProvideLiquidityOrder,
  WithdrawLiquidityOrder,
}
use utils.{
  divide, get_all_validators_inputs, policy_in_value, validate_token_mint,
}

pub fn valid_orders(
  validation_logic: fn(Output, Output, Transaction, Value, PoolDatum) ->
    ExpectedPoolOutput,
  redeemer: List<(Int, Int)>,
  transaction: Transaction,
  own_validator: ScriptHash,
  pool_utxo: Output,
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

  let indices: List<(Int, Int)> = redeemer
  let (
    _,
    _,
    input_index_count,
    expected_pool_output_value,
    expected_pool_output_datum,
  ) =
    list.foldl(
      indices,
      (-1, -1, 0, pool_utxo.value, pool_datum),
      fn(curr, acc) {
        let (
          in0,
          out0,
          count,
          expected_pool_output_value,
          expected_pool_output_datum,
        ) = acc
        let (in1, out1) = curr
        if in1 > in0 && out1 > out0 {
          expect Some(in_utxo) = script_inputs |> list.at(in1)
          expect Some(out_utxo) = outputs |> list.at(out1)
          let ExpectedPoolOutput { value: updated_value, datum: updated_datum } =
            validation_logic(
              in_utxo,
              out_utxo,
              transaction,
              expected_pool_output_value,
              expected_pool_output_datum,
            )

          (in1, out1, count + 1, updated_value, updated_datum)
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
    }

  expected_pool_output
}

pub fn validate_individual_order(
  input: Output,
  output: Output,
  transaction: Transaction,
  pool_output_value: Value,
  pool_output_datum: PoolDatum,
) -> ExpectedPoolOutput {
  expect InlineDatum(input_datum) = input.datum

  expect input_datum_typed: OrdersDatum = input_datum

  when input_datum_typed.action is {
    OpenPositionOrder ->
      open_position(input, output, pool_output_value, pool_output_datum)
    ClosePositionOrder ->
      close_position(
        input,
        output,
        transaction,
        pool_output_value,
        pool_output_datum,
      )
    ProvideLiquidityOrder ->
      contribute_liquidity(input, output, pool_output_value, pool_output_datum)
    WithdrawLiquidityOrder ->
      withdraw_liquidity(
        input,
        output,
        transaction,
        pool_output_value,
        pool_output_datum,
      )
    LiquidatePositionOrder ->
      liquidate_position(
        input,
        transaction,
        pool_output_value,
        pool_output_datum,
      )
  }
}

// asset is send to positions_contract, datum is not corruped, is sent to the correct validator
pub fn open_position(
  input: Output,
  output: Output,
  pool_output_value: Value,
  pool_output_datum: PoolDatum,
) -> ExpectedPoolOutput {
  expect InlineDatum(input_datum) = input.datum

  expect input_datum_typed: OrdersDatum = input_datum

  let expected_output_datum =
    PositionDatum {
      owner_address_hash: input_datum_typed.owner_address_hash,
      entered_at_usd_price: input_datum_typed.order_submission_usd_price,
      underlying_asset: input_datum_typed.underlying_asset,
      leverage_factor: input_datum_typed.leverage_factor,
      positions_mint_asset: input_datum_typed.positions_mint_asset,
      positions_mint_asset_amount: input_datum_typed.positions_mint_asset_amount,
      collateral_asset: input_datum_typed.collateral_asset,
      collateral_asset_amount: input_datum_typed.collateral_asset_amount,
      strike_collateral_asset: input_datum_typed.strike_collateral_asset,
      strike_collateral_asset_amount: input_datum_typed.strike_collateral_asset_amount,
      stop_loss_usd_price: input_datum_typed.stop_loss_usd_price,
      take_profit_usd_price: input_datum_typed.take_profit_usd_price,
      liquidate_usd_price: input_datum_typed.liquidate_usd_price,
      last_pay_lend_time: input_datum_typed.order_submission_time,
      pool_license: input_datum_typed.pool_license,
      side: input_datum_typed.side,
    }

  let expected_output_assets =
    assets.from_asset(
      input_datum_typed.positions_mint_asset.policy_id,
      input_datum_typed.positions_mint_asset.asset_name,
      input_datum_typed.positions_mint_asset_amount,
    )
      |> assets.add(
          input_datum_typed.collateral_asset.policy_id,
          input_datum_typed.collateral_asset.asset_name,
          input_datum_typed.collateral_asset_amount,
        )
      |> assets.add(
          input_datum_typed.strike_collateral_asset.policy_id,
          input_datum_typed.strike_collateral_asset.asset_name,
          input_datum_typed.strike_collateral_asset_amount,
        )

  let assets_locked_valid = match(output.value, expected_output_assets, >=)

  expect InlineDatum(output_datum) = output.datum

  expect output_datum_typed: PositionDatum = output_datum

  expect Script(output_script_hash) = output.address.payment_credential

  let output_script_hash_valid =
    output_script_hash == input_datum_typed.positions_script_hash

  let lended_amount: Int =
    input_datum_typed.positions_mint_asset_amount / input_datum_typed.leverage_factor

  let updated_pool_datum =
    PoolDatum {
      underlying_asset: pool_output_datum.underlying_asset,
      underlying_asset_amount: pool_output_datum.underlying_asset_amount,
      underlying_asset_lended_amount: pool_output_datum.underlying_asset_lended_amount + lended_amount,
      underlying_interest_rate: pool_output_datum.underlying_interest_rate,
      liquidate_margin: pool_output_datum.liquidate_margin,
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

  ExpectedPoolOutput { value: pool_output_value, datum: updated_pool_datum }
}

// correct asset is consumed, asset is sent to user, asset is burned
pub fn close_position(
  input: Output,
  output: Output,
  transaction: Transaction,
  pool_output_value: Value,
  pool_output_datum: PoolDatum,
) -> ExpectedPoolOutput {
  expect InlineDatum(input_datum) = input.datum

  expect input_datum_typed: OrdersDatum = input_datum

  let formatted_underlying_asset =
    to_ada_if_lovelace(
      input_datum_typed.underlying_asset,
      input_datum_typed.underlying_asset_amount,
    )

  let current_position_value: Int =
    input_datum_typed.order_submission_usd_price * formatted_underlying_asset

  let entry_position_value: Int =
    input_datum_typed.order_submission_usd_price * formatted_underlying_asset

  let expected_asset_amount_send_to_user: Int =
    calculate_profit(
      input_datum_typed,
      current_position_value,
      entry_position_value,
    )

  let expected_mint =
    (
      input_datum_typed.positions_mint_asset.policy_id,
      input_datum_typed.positions_mint_asset.asset_name,
      -input_datum_typed.positions_mint_asset_amount,
    )

  let mint_valid: Bool = validate_token_mint(transaction.mint, expected_mint)

  expect VerificationKey(owner_address_hash) = output.address.payment_credential

  let output_is_to_owner =
    owner_address_hash == input_datum_typed.owner_address_hash

  let estimated_return =
    calculate_return(
      input_datum_typed,
      expected_asset_amount_send_to_user,
      input_datum_typed.order_submission_usd_price,
      pool_output_value,
      pool_output_datum,
    )

  let assets_locked_valid =
    match(output.value, estimated_return.expected_asset_send_to_owner, >=)

  expect mint_valid && output_is_to_owner && assets_locked_valid

  ExpectedPoolOutput {
    value: estimated_return.expected_pool_output.value,
    datum: estimated_return.expected_pool_output.datum,
  }
}

pub fn withdraw_liquidity(
  input: Output,
  output: Output,
  transaction: Transaction,
  pool_output_value: Value,
  pool_output_datum: PoolDatum,
) -> ExpectedPoolOutput {
  expect InlineDatum(input_datum) = input.datum

  expect orders_datum_typed: OrdersDatum = input_datum

  let ref_input: List<Input> = transaction.reference_inputs

  expect Some(Input {
    output: Output { value: batcher_value, datum: pool_ref_datum, .. },
    ..
  }) = list.head(ref_input)

  let policy_is_in_transaction =
    policy_in_value(orders_datum_typed.pool_license, batcher_value)

  expect InlineDatum(pool_ref_datum) = pool_ref_datum
  expect pool_ref_datum_typed: PoolDatum = pool_ref_datum

  let address: Address =
    from_verification_key(orders_datum_typed.owner_address_hash)

  let output_is_to_owner = output.address == address

  let expected_mint =
    (
      orders_datum_typed.liquidity_asset.policy_id,
      orders_datum_typed.liquidity_asset.asset_name,
      orders_datum_typed.liquidity_asset_amount * -1,
    )

  let mint_valid: Bool = validate_token_mint(transaction.mint, expected_mint)

  let expected_earnings: Int =
    orders_datum_typed.liquidity_asset_amount * pool_ref_datum_typed.earnings_per_share

  let expected_collateral_earnings: Int =
    orders_datum_typed.liquidity_asset_amount * pool_ref_datum_typed.collateral_earnings_per_share

  let asset_sent_to_owner_valid =
    quantity_of(
      output.value,
      orders_datum_typed.liquidity_asset.policy_id,
      orders_datum_typed.liquidity_asset.asset_name,
    ) == orders_datum_typed.liquidity_asset_amount + expected_earnings

  let expected_collateral_earnings_valid =
    quantity_of(
      output.value,
      orders_datum_typed.collateral_asset.policy_id,
      orders_datum_typed.collateral_asset.asset_name,
    ) == expected_collateral_earnings

  expect
    output_is_to_owner && mint_valid && asset_sent_to_owner_valid && expected_collateral_earnings_valid && policy_is_in_transaction

  ExpectedPoolOutput { value: pool_output_value, datum: pool_output_datum }
}

// The logic in the main function checks if the asset is being added to the pooled utxo
pub fn contribute_liquidity(
  _input: Output,
  _output: Output,
  pool_output_value: Value,
  pool_output_datum: PoolDatum,
) -> ExpectedPoolOutput {
  ExpectedPoolOutput { value: pool_output_value, datum: pool_output_datum }
}

pub fn liquidate_position(
  input: Output,
  transaction: Transaction,
  pool_output_value: Value,
  pool_output_datum: PoolDatum,
) -> ExpectedPoolOutput {
  expect InlineDatum(orders_datum) = input.datum

  expect orders_datum_typed: OrdersDatum = orders_datum

  let updated_value =
    assets.add(
      pool_output_value,
      orders_datum_typed.collateral_asset.policy_id,
      orders_datum_typed.collateral_asset.asset_name,
      orders_datum_typed.collateral_asset_amount,
    )

  let expected_mint =
    (
      orders_datum_typed.collateral_asset.policy_id,
      orders_datum_typed.collateral_asset.asset_name,
      orders_datum_typed.collateral_asset_amount,
    )

  let mint_valid = validate_token_mint(transaction.mint, expected_mint)

  expect mint_valid

  if orders_datum_typed.side == Long {
    let updated_datum =
      PoolDatum {
        ..pool_output_datum,
        underlying_asset_amount: pool_output_datum.underlying_asset_amount + orders_datum_typed.collateral_asset_amount,
      }

    ExpectedPoolOutput { value: updated_value, datum: updated_datum }
  } else {
    let updated_datum =
      PoolDatum {
        ..pool_output_datum,
        stable_collateral_asset_amount: pool_output_datum.stable_collateral_asset_amount + orders_datum_typed.collateral_asset_amount,
      }

    ExpectedPoolOutput { value: updated_value, datum: updated_datum }
  }
}

pub fn cancel_open_position(
  datum: OrdersDatum,
  transaction: Transaction,
) -> Bool {
  let signed_by_owner =
    list.has(transaction.extra_signatories, datum.owner_address_hash)

  let only_one_input_from_script =
    list.length(get_all_validators_inputs(transaction)) == 1

  let expected_mint =
    (
      datum.positions_mint_asset.policy_id,
      datum.positions_mint_asset.asset_name,
      -datum.positions_mint_asset_amount,
    )

  let mint_valid: Bool = validate_token_mint(transaction.mint, expected_mint)

  signed_by_owner && only_one_input_from_script && mint_valid
}

pub fn cancel_close_position(
  datum: OrdersDatum,
  transaction: Transaction,
  output_index: Int,
) -> Bool {
  let inputs_from_scripts = get_all_validators_inputs(transaction)

  let only_one_input_from_script: Bool = list.length(inputs_from_scripts) == 1

  expect Some(output_to_positions) = list.at(transaction.outputs, output_index)

  expect InlineDatum(output_datum) = output_to_positions.datum

  expect output_datum_typed: PositionDatum = output_datum

  let expected_positions_datum =
    PositionDatum {
      owner_address_hash: datum.owner_address_hash,
      underlying_asset: datum.underlying_asset,
      entered_at_usd_price: datum.order_submission_usd_price,
      leverage_factor: datum.leverage_factor,
      positions_mint_asset: datum.positions_mint_asset,
      positions_mint_asset_amount: datum.positions_mint_asset_amount,
      collateral_asset: datum.collateral_asset,
      collateral_asset_amount: datum.collateral_asset_amount,
      strike_collateral_asset: datum.strike_collateral_asset,
      strike_collateral_asset_amount: datum.strike_collateral_asset_amount,
      liquidate_usd_price: datum.liquidate_usd_price,
      stop_loss_usd_price: datum.stop_loss_usd_price,
      take_profit_usd_price: datum.take_profit_usd_price,
      last_pay_lend_time: datum.order_submission_time,
      pool_license: datum.pool_license,
      side: datum.side,
    }

  let datum_match = output_datum_typed == expected_positions_datum

  let expected_assets_sent_back: Value =
    assets.from_asset(
      datum.positions_mint_asset.policy_id,
      datum.positions_mint_asset.asset_name,
      datum.positions_mint_asset_amount,
    )
      |> assets.add(
          datum.collateral_asset.policy_id,
          datum.collateral_asset.asset_name,
          datum.collateral_asset_amount,
        )
      |> assets.add(
          datum.strike_collateral_asset.policy_id,
          datum.strike_collateral_asset.asset_name,
          datum.strike_collateral_asset_amount,
        )
  let assets_locked_valid =
    match(output_to_positions.value, expected_assets_sent_back, >=)

  let signed_by_owner =
    list.has(transaction.extra_signatories, datum.owner_address_hash)

  datum_match && assets_locked_valid && only_one_input_from_script && signed_by_owner
}

pub fn cancel_contribute_liquidity(
  datum: OrdersDatum,
  transaction: Transaction,
) -> Bool {
  let expected_mint =
    (
      datum.liquidity_asset.policy_id,
      datum.liquidity_asset.asset_name,
      -datum.liquidity_asset_amount,
    )

  let mint_valid: Bool = validate_token_mint(transaction.mint, expected_mint)

  let signed_by_owner: Bool =
    list.has(transaction.extra_signatories, datum.owner_address_hash)

  mint_valid && signed_by_owner
}

pub fn cancel_withdraw_liquidity(
  datum: OrdersDatum,
  transaction: Transaction,
) -> Bool {
  let inputs_from_scripts: List<Input> = get_all_validators_inputs(transaction)

  let only_one_input_from_script: Bool = list.length(inputs_from_scripts) == 1

  let outputs_to_liquidity_position: List<Output> =
    find_script_outputs(
      transaction.outputs,
      datum.liquidity_positions_script_hash,
    )

  expect Some(output_to_liquidity_position) =
    list.head(outputs_to_liquidity_position)
  expect InlineDatum(output_datum) = output_to_liquidity_position.datum

  expect liquidity_position_datum_typed: LiquidityPositionDatum = output_datum

  let signed_by_owner: Bool =
    list.has(transaction.extra_signatories, datum.owner_address_hash)

  let expected_liquidity_position_datum =
    LiquidityPositionDatum {
      owner_address_hash: datum.owner_address_hash,
      entered_earnings_per_share: datum.entered_earnings_per_share,
      entered_collateral_earnings_per_share: datum.entered_collateral_earnings_per_share,
    }

  let expected_assets_locked =
    assets.from_asset(
      datum.liquidity_asset.policy_id,
      datum.liquidity_asset.asset_name,
      datum.liquidity_asset_amount,
    )

  let assets_locked_valid =
    match(output_to_liquidity_position.value, expected_assets_locked, >=)

  only_one_input_from_script && signed_by_owner && liquidity_position_datum_typed == expected_liquidity_position_datum && assets_locked_valid
}

fn calculate_profit(
  input_datum: OrdersDatum,
  current_position_value: Int,
  entry_position_value: Int,
) -> Int {
  if input_datum.side == Long {
    current_position_value - entry_position_value
  } else {
    entry_position_value - current_position_value
  }
}

fn calculate_return(
  input_datum: OrdersDatum,
  expected_asset_amount_send_to_user: Int,
  current_usd_price: Int,
  pool_output_value: Value,
  pool_output_datum: PoolDatum,
) -> ClosePositionCalculate {
  if input_datum.side == Long {
    calculate_long_return_asset_amount(
      input_datum,
      expected_asset_amount_send_to_user,
      current_usd_price,
      pool_output_value,
      pool_output_datum,
    )
  } else {
    calculate_short_return_asset_amount(
      input_datum,
      expected_asset_amount_send_to_user,
      current_usd_price,
      pool_output_value,
      pool_output_datum,
    )
  }
}

fn calculate_long_return_asset_amount(
  input_datum: OrdersDatum,
  usd_value: Int,
  current_price: Int,
  pool_output_value: Value,
  pool_output_datum: PoolDatum,
) -> ClosePositionCalculate {
  if usd_value > 0 {
    let expected_asset_sent = divide(usd_value, current_price)

    let formatted_asset_sent =
      to_lovelace_if_ada(input_datum.underlying_asset, expected_asset_sent)

    let expected_assets_locked =
      assets.from_asset(
        input_datum.collateral_asset.policy_id,
        input_datum.collateral_asset.asset_name,
        input_datum.collateral_asset_amount + formatted_asset_sent,
      )
        |> assets.add(
            input_datum.strike_collateral_asset.policy_id,
            input_datum.strike_collateral_asset.asset_name,
            input_datum.strike_collateral_asset_amount,
          )

    let updated_value =
      assets.add(
        pool_output_value,
        input_datum.underlying_asset.policy_id,
        input_datum.underlying_asset.asset_name,
        -formatted_asset_sent,
      )

    let updated_datum =
      PoolDatum {
        ..pool_output_datum,
        underlying_asset_amount: pool_output_datum.underlying_asset_amount + formatted_asset_sent,
      }

    ClosePositionCalculate {
      expected_asset_send_to_owner: expected_assets_locked,
      expected_pool_output: ExpectedPoolOutput {
        value: updated_value,
        datum: updated_datum,
      },
    }
  } else {
    let expected_assets_payed = divide(-usd_value, current_price)

    let formatted_assets_payed =
      to_lovelace_if_ada(input_datum.underlying_asset, expected_assets_payed)

    let expected_assets_locked =
      assets.from_asset(
        input_datum.collateral_asset.policy_id,
        input_datum.collateral_asset.asset_name,
        input_datum.collateral_asset_amount - formatted_assets_payed,
      )
        |> assets.add(
            input_datum.strike_collateral_asset.policy_id,
            input_datum.strike_collateral_asset.asset_name,
            input_datum.strike_collateral_asset_amount,
          )

    let updated_value =
      assets.add(
        pool_output_value,
        input_datum.underlying_asset.policy_id,
        input_datum.underlying_asset.asset_name,
        -formatted_assets_payed,
      )

    let updated_datum =
      PoolDatum {
        ..pool_output_datum,
        underlying_asset_amount: pool_output_datum.underlying_asset_amount + formatted_assets_payed,
      }

    ClosePositionCalculate {
      expected_asset_send_to_owner: expected_assets_locked,
      expected_pool_output: ExpectedPoolOutput {
        value: updated_value,
        datum: updated_datum,
      },
    }
  }
}

fn calculate_short_return_asset_amount(
  input_datum: OrdersDatum,
  usd_value: Int,
  current_usd_price: Int,
  pool_output_value: Value,
  pool_output_datum: PoolDatum,
) -> ClosePositionCalculate {
  if usd_value > 0 {
    let expected_assets_sent = divide(usd_value, current_usd_price)

    let formatted_assets_sent =
      to_lovelace_if_ada(input_datum.underlying_asset, expected_assets_sent)

    let expected_assets_locked =
      assets.from_asset(
        input_datum.collateral_asset.policy_id,
        input_datum.collateral_asset.asset_name,
        input_datum.collateral_asset_amount,
      )
        |> assets.add(
            input_datum.strike_collateral_asset.policy_id,
            input_datum.strike_collateral_asset.asset_name,
            input_datum.strike_collateral_asset_amount,
          )
        |> assets.add(
            input_datum.underlying_asset.policy_id,
            input_datum.underlying_asset.asset_name,
            formatted_assets_sent,
          )

    let updated_value =
      assets.add(
        pool_output_value,
        input_datum.underlying_asset.policy_id,
        input_datum.underlying_asset.asset_name,
        -formatted_assets_sent,
      )

    let updated_datum =
      PoolDatum {
        ..pool_output_datum,
        underlying_asset_amount: pool_output_datum.underlying_asset_amount - formatted_assets_sent,
      }

    ClosePositionCalculate {
      expected_asset_send_to_owner: expected_assets_locked,
      expected_pool_output: ExpectedPoolOutput {
        value: updated_value,
        datum: updated_datum,
      },
    }
  } else {
    let formatted_usd_payed = usd_value * -1

    let expected_assets_locked =
      assets.from_asset(
        input_datum.collateral_asset.policy_id,
        input_datum.collateral_asset.asset_name,
        input_datum.collateral_asset_amount - formatted_usd_payed,
      )
        |> assets.add(
            input_datum.strike_collateral_asset.policy_id,
            input_datum.strike_collateral_asset.asset_name,
            input_datum.strike_collateral_asset_amount,
          )

    let updated_value =
      assets.add(
        pool_output_value,
        input_datum.underlying_asset.policy_id,
        input_datum.underlying_asset.asset_name,
        formatted_usd_payed,
      )

    let updated_datum =
      PoolDatum {
        ..pool_output_datum,
        underlying_asset_amount: pool_output_datum.underlying_asset_amount + formatted_usd_payed,
      }

    ClosePositionCalculate {
      expected_asset_send_to_owner: expected_assets_locked,
      expected_pool_output: ExpectedPoolOutput {
        value: updated_value,
        datum: updated_datum,
      },
    }
  }
}

fn to_lovelace_if_ada(asset: Asset, amount: Int) -> Int {
  if asset.policy_id == "" {
    amount * 1_000_000
  } else {
    amount
  }
}

fn to_ada_if_lovelace(asset: Asset, amount: Int) -> Int {
  if asset.policy_id == "" {
    amount * 1_000_000
  } else {
    amount
  }
}
