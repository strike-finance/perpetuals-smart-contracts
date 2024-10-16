use aiken/collection/list
use aiken/crypto.{ScriptHash}
use aiken/math/rational.{new, round}
use cardano/address.{Address, Script, from_verification_key}
use cardano/assets.{quantity_of}
use cardano/transaction.{
  InlineDatum, Input, Output, Transaction, find_script_outputs,
}
use types.{
  OrdersDatum, PoolDatum, PositionDatum, ProcessClosePositionOrder,
  ProcessLiquidateOrder, ProcessOpenPositionOrder, ProcessProvideLiquidityOrder,
  ProcessStopLossOrder, ProcessTakeProfitOrder, ProcessWithdrawLiquidityOrder,
}
use utils.{get_lower_bound, validate_token_mint}

pub fn valid_orders(
  validation_logic: fn(Output, Output, Int, Transaction) -> Bool,
  redeemer: List<(Int, Int)>,
  transaction: Transaction,
  own_validator: ScriptHash,
  current_asset_price: Int,
) -> Bool {
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
  let (_, _, input_index_count) =
    list.foldl(
      indices,
      (-1, -1, 0),
      fn(curr, acc) {
        let (in0, out0, count) = acc
        let (in1, out1) = curr
        if in1 > in0 && out1 > out0 {
          expect Some(in_utxo) = script_inputs |> list.at(in1)
          expect Some(out_utxo) = outputs |> list.at(out1)
          if validation_logic(
            in_utxo,
            out_utxo,
            current_asset_price,
            transaction,
          ) {
            (in1, out1, count + 1)
          } else {
            fail @"Validation failed"
          }
        } else {
          fail @"Input and output indices must be in ascending orders"
        }
      },
    )
  (script_input_count == input_index_count)?
}

pub fn validate_individual_order(
  input: Output,
  output: Output,
  current_asset_price: Int,
  transaction: Transaction,
) -> Bool {
  expect InlineDatum(input_datum) = input.datum

  expect input_datum_typed: OrdersDatum = input_datum

  when input_datum_typed.action is {
    ProcessOpenPositionOrder -> validate_open_position(input, output)
    ProcessClosePositionOrder ->
      validate_close_position(input, output, current_asset_price, transaction)
    ProcessStopLossOrder -> todo
    ProcessTakeProfitOrder -> todo
    ProcessProvideLiquidityOrder -> validate_contribute_liquidity(input, output)
    ProcessWithdrawLiquidityOrder ->
      validate_withdraw_liquidity(input, output, transaction)
    ProcessLiquidateOrder -> False
  }
}

// asset is send to positions_contract, datum is not corruped, is sent to the correct validator
pub fn validate_open_position(input: Output, output: Output) -> Bool {
  expect InlineDatum(input_datum) = input.datum

  expect input_datum_typed: OrdersDatum = input_datum

  let valid_asset_in_output: Bool =
    quantity_of(
      output.value,
      input_datum_typed.positions_asset.policy_id,
      input_datum_typed.positions_asset.asset_name,
    ) == 1

  let expected_output_datum =
    PositionDatum {
      owner_address_hash: input_datum_typed.owner_address_hash,
      entered_at_price: input_datum_typed.entered_at_price,
      underlying_asset: input_datum_typed.underlying_asset,
      leverage_factor: input_datum_typed.leverage_factor,
      positions_asset: input_datum_typed.positions_asset,
      positions_asset_amount: input_datum_typed.positions_asset_amount,
      collateral_asset: input_datum_typed.collateral_asset,
      collateral_asset_amount: input_datum_typed.collateral_asset_amount,
      stop_loss_usd_price: input_datum_typed.stop_loss_usd_price,
      take_profit_usd_price: input_datum_typed.take_profit_usd_price,
      liquidate_usd_price: input_datum_typed.liquidate_usd_price,
      last_pay_lend_time: input_datum_typed.order_submission_time,
      validate_pool_ref: input_datum_typed.validate_pool_ref,
      side: input_datum_typed.side,
    }

  expect InlineDatum(output_datum) = output.datum

  expect output_datum_typed: PositionDatum = output_datum

  let perpetual_address: Address =
    from_verification_key(input_datum_typed.positions_validator_hash)

  let output_is_to_perpetual = output.address == perpetual_address

  valid_asset_in_output && output_datum_typed == expected_output_datum && output_is_to_perpetual
}

// correct asset is consumed, asset is sent to user, asset is burned
pub fn validate_close_position(
  input: Output,
  output: Output,
  current_asset_price: Int,
  transaction: Transaction,
) -> Bool {
  expect InlineDatum(input_datum) = input.datum

  expect input_datum_typed: OrdersDatum = input_datum

  let current_position_amount: Int =
    current_asset_price * input_datum_typed.leverage_factor

  let entry_position_amount: Int =
    input_datum_typed.positions_asset_amount * input_datum_typed.leverage_factor

  let current_time: Int = get_lower_bound(transaction.validity_range)

  let time_passed: Int = current_time - input_datum_typed.order_submission_time

  expect Some(time_passed_rational) = new(time_passed, 3600000)

  let payback_lend_amount: Int =
    round(time_passed_rational) * entry_position_amount * entry_position_amount

  let expected_asset_amount_send_to_user: Int =
    current_position_amount - payback_lend_amount - entry_position_amount

  let expected_mint =
    (
      input_datum_typed.positions_asset.policy_id,
      input_datum_typed.positions_asset.asset_name,
      input_datum_typed.positions_asset_amount * -1,
    )

  let mint_valid: Bool = validate_token_mint(transaction.mint, expected_mint)

  let address: Address =
    from_verification_key(input_datum_typed.owner_address_hash)

  // not sure if a staking credential can alter this
  let output_is_to_owner = output.address == address

  let asset_sent_to_owner_valid =
    quantity_of(
      output.value,
      input_datum_typed.underlying_asset.policy_id,
      input_datum_typed.underlying_asset.asset_name,
    ) == expected_asset_amount_send_to_user

  let collateral_sent_to_owner_valid =
    quantity_of(
      output.value,
      input_datum_typed.collateral_asset.policy_id,
      input_datum_typed.collateral_asset.asset_name,
    ) == input_datum_typed.collateral_asset_amount

  mint_valid && output_is_to_owner && asset_sent_to_owner_valid && collateral_sent_to_owner_valid
}

pub fn validate_withdraw_liquidity(
  input: Output,
  output: Output,
  transaction: Transaction,
) -> Bool {
  expect InlineDatum(input_datum) = input.datum

  expect input_datum_typed: OrdersDatum = input_datum

  let ref_input: List<Input> = transaction.reference_inputs

  expect Some(pool_ref_input) =
    list.find(
      ref_input,
      fn(ref_input: Input) {
        ref_input.output_reference == input_datum_typed.validate_pool_ref
      },
    )

  expect InlineDatum(pool_ref_datum) = pool_ref_input.output.datum
  expect pool_ref_datum_typed: PoolDatum = pool_ref_datum

  let address: Address =
    from_verification_key(input_datum_typed.owner_address_hash)

  // not sure if a staking credential can alter this
  let output_is_to_owner = output.address == address

  let expected_mint =
    (
      input_datum_typed.liquidity_asset.policy_id,
      input_datum_typed.liquidity_asset.asset_name,
      input_datum_typed.liquidity_asset_amount * -1,
    )

  let mint_valid: Bool = validate_token_mint(transaction.mint, expected_mint)

  let expected_earnings: Int =
    input_datum_typed.liquidity_asset_amount * pool_ref_datum_typed.earnings_per_share

  let expected_collateral_earnings: Int =
    input_datum_typed.liquidity_asset_amount * pool_ref_datum_typed.collateral_earnings_per_share

  let asset_sent_to_owner_valid =
    quantity_of(
      output.value,
      input_datum_typed.liquidity_asset.policy_id,
      input_datum_typed.liquidity_asset.asset_name,
    ) == input_datum_typed.liquidity_asset_amount + expected_earnings

  let expected_collateral_earnings_valid =
    quantity_of(
      output.value,
      input_datum_typed.collateral_asset.policy_id,
      input_datum_typed.collateral_asset.asset_name,
    ) == expected_collateral_earnings

  output_is_to_owner && mint_valid && asset_sent_to_owner_valid && expected_collateral_earnings_valid
}

// The logic in the main function checks if the asset is being added to the pooled utxo
pub fn validate_contribute_liquidity(_input: Output, _output: Output) -> Bool {
  True
}

// assets are burned 
pub fn cancel_open_position_order(
  datum: OrdersDatum,
  transaction: Transaction,
) -> Bool {
  let expected_mint =
    (datum.positions_asset.policy_id, datum.positions_asset.asset_name, -1)

  let mint_valid: Bool = validate_token_mint(transaction.mint, expected_mint)

  mint_valid
}

// positions send back to positions utxo, datum is not corrupted
pub fn cancel_close_position_order(
  datum: OrdersDatum,
  transaction: Transaction,
) -> Bool {
  let outputs_to_positions: List<Output> =
    find_script_outputs(transaction.outputs, datum.positions_validator_hash)

  expect Some(output_to_positions) = list.head(outputs_to_positions)

  let only_one_output_to_positions: Bool =
    list.length(outputs_to_positions) == 1

  expect InlineDatum(output_datum) = output_to_positions.datum

  expect output_datum_typed: PositionDatum = output_datum

  let expected_positions_datum =
    PositionDatum {
      owner_address_hash: datum.owner_address_hash,
      underlying_asset: datum.underlying_asset,
      entered_at_price: datum.entered_at_price,
      leverage_factor: datum.leverage_factor,
      positions_asset: datum.positions_asset,
      positions_asset_amount: datum.positions_asset_amount,
      collateral_asset: datum.collateral_asset,
      collateral_asset_amount: datum.collateral_asset_amount,
      liquidate_usd_price: datum.liquidate_usd_price,
      stop_loss_usd_price: datum.stop_loss_usd_price,
      take_profit_usd_price: datum.take_profit_usd_price,
      last_pay_lend_time: datum.order_submission_time,
      validate_pool_ref: datum.validate_pool_ref,
      side: datum.side,
    }

  let quantity_of_positions_asset: Int =
    quantity_of(
      output_to_positions.value,
      datum.positions_asset.policy_id,
      datum.positions_asset.asset_name,
    )

  only_one_output_to_positions && output_datum_typed == expected_positions_datum && quantity_of_positions_asset == datum.positions_asset_amount
}

// assets are burned 
pub fn cancel_contribute_liquidity_order(
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

  mint_valid
}

pub fn cancel_withdraw_liquidity_order(
  datum: OrdersDatum,
  transaction: Transaction,
) -> Bool {
  True
}
