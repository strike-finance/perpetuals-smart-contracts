use aiken/collection/list
use cardano/address.{Script}
use cardano/assets.{quantity_of}
use cardano/transaction.{
  InlineDatum, Input, Output, Transaction, find_script_outputs,
}
use types.{
  AddressHash, ClosePosition, ContributeLiquidity, OpenPosition, OrdersDatum,
  PositionDatum, WithdrawLiquidity,
}
use utils.{validate_token_mint}

pub fn valid_orders(
  validation_logic: fn(Output, Output) -> Bool,
  redeemer: List<(Int, Int)>,
  tx: Transaction,
  own_validator: AddressHash,
) -> Bool {
  let Transaction { inputs, outputs, .. } = tx
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
          if validation_logic(in_utxo, out_utxo) {
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

pub fn validate_order(input: Output, output: Output) -> Bool {
  expect InlineDatum(input_datum) = input.datum

  expect input_datum_typed: OrdersDatum = input_datum

  when input_datum_typed.action is {
    OpenPosition -> validate_open_position(input, output)
    ClosePosition -> validate_close_position(input, output)
    ContributeLiquidity -> validate_contribute_liquidity(input, output)
    WithdrawLiquidity -> validate_withdraw_liquidity(input, output)
  }
}

// asset is send to positions_contract, datum is not corruped
pub fn validate_open_position(input: Output, output: Output) -> Bool {
  expect InlineDatum(input_datum) = input.datum

  True
}

// asset is consumed 
pub fn validate_close_position(input: Output, output: Output) -> Bool {
  todo
}

pub fn validate_withdraw_liquidity(input: Output, output: Output) -> Bool {
  todo
}

pub fn validate_contribute_liquidity(input: Output, output: Output) -> Bool {
  todo
}

// assets are burned 
pub fn cancel_open_position_order(
  datum: OrdersDatum,
  transaction: Transaction,
) -> Bool {
  let expected_mint =
    (
      datum.positions_asset.policy_id,
      datum.positions_asset.asset_name,
      -datum.position_amount,
    )

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
      position_amount: datum.position_amount,
      leverage_amount: datum.leverage_amount,
      stop_loss_amount: datum.stop_loss_amount,
      positions_asset: datum.positions_asset,
      side: datum.side,
      orders_validator_hash: datum.orders_validator_hash,
    }

  let quantity_of_positions_asset: Int =
    quantity_of(
      output_to_positions.value,
      datum.positions_asset.policy_id,
      datum.positions_asset.asset_name,
    )

  only_one_output_to_positions && output_datum_typed == expected_positions_datum && quantity_of_positions_asset == datum.position_amount
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
      -datum.liquidity_amount,
    )

  let mint_valid: Bool = validate_token_mint(transaction.mint, expected_mint)

  mint_valid
}
