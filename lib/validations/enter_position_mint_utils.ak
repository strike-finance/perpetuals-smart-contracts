use aiken/collection/list
use cardano/assets.{PolicyId, quantity_of}
use cardano/transaction.{
  InlineDatum, Input, Output, Transaction, find_script_outputs,
}
use types.{Asset, EnterPositionParams, OrdersDatum, PoolDatum}
use utils.{validate_token_mint}

pub fn enter_long_mint(
  transaction: Transaction,
  params: EnterPositionParams,
  current_price: Int,
  policy_id: PolicyId,
) {
  let outputs_to_orders_address: List<Output> =
    find_script_outputs(transaction.outputs, params.orders_script_hash)

  let only_one_output_to_orders: Bool =
    list.length(outputs_to_orders_address) == 1

  expect Some(output_to_orders_validator) = list.head(outputs_to_orders_address)

  expect InlineDatum(orders_datum) = output_to_orders_validator.datum

  expect orders_datum_typed: OrdersDatum = orders_datum

  let ref_input: List<Input> = transaction.reference_inputs

  expect Some(pool_ref_input) =
    list.find(
      ref_input,
      fn(ref_input: Input) {
        ref_input.output_reference == params.validate_pool_ref
      },
    )

  expect InlineDatum(pool_ref_datum) = pool_ref_input.output.datum
  expect pool_ref_datum_typed: PoolDatum = pool_ref_datum

  let valid_pool_ref: Bool =
    orders_datum_typed.validate_pool_ref == params.validate_pool_ref

  let contains_strike_collateral: Bool =
    quantity_of(
      output_to_orders_validator.value,
      orders_datum_typed.strike_collateral_asset.policy_id,
      orders_datum_typed.strike_collateral_asset.asset_name,
    ) > 0

  let current_price_valid: Bool =
    current_price == orders_datum_typed.entered_at_price

  let signed_by_admin: Bool =
    list.has(transaction.extra_signatories, params.admin_pkh)

  let liquidate_usd_price: Int =
    calculate_long_liquidate_amount(
      orders_datum_typed,
      current_price,
      pool_ref_datum_typed.liquidate_margin,
    )

  let liquidate_usd_price_valid: Bool =
    liquidate_usd_price == orders_datum_typed.liquidate_usd_price

  let collateral_asset_deposited_amount: Int =
    quantity_of(
      output_to_orders_validator.value,
      orders_datum_typed.underlying_asset.policy_id,
      orders_datum_typed.underlying_asset.asset_name,
    ) * orders_datum_typed.leverage_factor

  let expected_mint: (PolicyId, ByteArray, Int) =
    (policy_id, params.long_asset_name, collateral_asset_deposited_amount)

  let mint_valid: Bool = validate_token_mint(transaction.mint, expected_mint)

  expect
    only_one_output_to_orders && valid_pool_ref && current_price_valid && signed_by_admin && liquidate_usd_price_valid && mint_valid

  if contains_strike_collateral {
    let leverage_factor_valid: Bool =
      pool_ref_datum_typed.max_strike_holder_leverage_factor >= orders_datum_typed.leverage_factor

    leverage_factor_valid
  } else {
    let leverage_factor_valid: Bool =
      pool_ref_datum_typed.max_leverage_factor >= orders_datum_typed.leverage_factor

    leverage_factor_valid
  }
}

pub fn enter_short_mint(
  transaction: Transaction,
  params: EnterPositionParams,
  current_price: Int,
  policy_id: PolicyId,
) {
  let outputs_to_orders_address: List<Output> =
    find_script_outputs(transaction.outputs, params.orders_script_hash)

  let only_one_output_to_orders: Bool =
    list.length(outputs_to_orders_address) == 1

  expect Some(output_to_orders_validator) = list.head(outputs_to_orders_address)

  expect InlineDatum(orders_datum) = output_to_orders_validator.datum

  expect orders_datum_typed: OrdersDatum = orders_datum

  let ref_input: List<Input> = transaction.reference_inputs

  expect Some(pool_ref_input) =
    list.find(
      ref_input,
      fn(ref_input: Input) {
        ref_input.output_reference == params.validate_pool_ref
      },
    )

  expect InlineDatum(pool_ref_datum) = pool_ref_input.output.datum
  expect pool_ref_datum_typed: PoolDatum = pool_ref_datum

  let valid_pool_ref: Bool =
    orders_datum_typed.validate_pool_ref == params.validate_pool_ref

  let current_price_valid: Bool =
    current_price == orders_datum_typed.entered_at_price

  let signed_by_admin: Bool =
    list.has(transaction.extra_signatories, params.admin_pkh)

  let expected_usd_collateral: Int =
    get_expected_usd_collateral(orders_datum_typed, current_price)

  let expected_minted_amount =
    orders_datum_typed.positions_asset_amount * orders_datum_typed.leverage_factor

  let collateral_asset_deposited_amount: Int =
    quantity_of(
      output_to_orders_validator.value,
      orders_datum_typed.stable_collateral_asset.policy_id,
      orders_datum_typed.stable_collateral_asset.asset_name,
    )

  let contains_strike_collateral: Bool =
    quantity_of(
      output_to_orders_validator.value,
      orders_datum_typed.strike_collateral_asset.policy_id,
      orders_datum_typed.strike_collateral_asset.asset_name,
    ) > 0

  let expected_mint: (PolicyId, ByteArray, Int) =
    (policy_id, params.short_asset_name, expected_minted_amount)

  let mint_valid = validate_token_mint(transaction.mint, expected_mint)

  let expected_usd_collateral_valid: Bool =
    collateral_asset_deposited_amount >= expected_usd_collateral

  let liquidate_usd_price: Int =
    calculate_short_liquidate_amount(
      orders_datum_typed,
      current_price,
      pool_ref_datum_typed.liquidate_margin,
    )

  let liquidate_usd_price_valid: Bool =
    orders_datum_typed.liquidate_usd_price >= liquidate_usd_price

  expect
    mint_valid && only_one_output_to_orders && valid_pool_ref && current_price_valid && signed_by_admin && expected_usd_collateral_valid && liquidate_usd_price_valid

  if contains_strike_collateral {
    let leverage_factor_valid: Bool =
      pool_ref_datum_typed.max_strike_holder_leverage_factor >= orders_datum_typed.leverage_factor
    leverage_factor_valid
  } else {
    let leverage_factor_valid: Bool =
      pool_ref_datum_typed.max_leverage_factor >= orders_datum_typed.leverage_factor
    leverage_factor_valid
  }
}

fn get_expected_usd_collateral(orders_datum: OrdersDatum, current_price: Int) {
  if orders_datum.underlying_asset.policy_id == "" {
    let collateral_amount = lovelace_to_ada(orders_datum.positions_asset_amount)
    collateral_amount * current_price * orders_datum.leverage_factor
  } else {
    orders_datum.positions_asset_amount * current_price * orders_datum.leverage_factor
  }
}

fn lovelace_to_ada(lovelace: Int) -> Int {
  lovelace / 1_000_000
}

fn calculate_long_liquidate_amount(
  orders_datum: OrdersDatum,
  current_price: Int,
  liquidate_margin: Int,
) {
  let formatted_liquidate_margin = liquidate_margin / 1000
  current_price * (
    1 - ( 1 - formatted_liquidate_margin ) / orders_datum.leverage_factor
  )
}

fn calculate_short_liquidate_amount(
  orders_datum: OrdersDatum,
  current_price: Int,
  liquidate_margin: Int,
) {
  let formatted_liquidate_margin = liquidate_margin / 1000
  current_price * (
    1 + ( 1 - formatted_liquidate_margin ) / orders_datum.leverage_factor
  )
}
