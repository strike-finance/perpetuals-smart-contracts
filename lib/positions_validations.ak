use aiken/builtin
use aiken/collection/list
use aiken/math/rational
use cardano/assets.{PolicyId, Value, match, quantity_of}
use cardano/transaction.{
  InlineDatum, Input, Output, Transaction, find_script_outputs,
}
use constants.{batcher_fee}
use types.{
  Asset, ClosePositionOrder, CloseType, LiquidateClose, LiquidatePositionOrder,
  Long, OpenPositionOrder, OrderDatum, POSIXTime, PoolDatum, PositionDatum,
  PositionSide, PositionsParams, StopLossClose, TakeProfitClose, TraderClose,
}
use utils.{
  get_address_outputs, get_all_validators_inputs, get_lower_bound,
  policy_in_value, validate_token_mint,
}

pub fn close_position(
  transaction: Transaction,
  datum: Option<PositionDatum>,
  current_price: Int,
  orders_script_hash: ByteArray,
  close_type: CloseType,
) -> Bool {
  expect Some(datum) = datum
  let all_validators_inputs: List<Input> =
    get_all_validators_inputs(transaction)
  let only_one_input_from_script: Bool = list.length(all_validators_inputs) == 1

  let outputs_to_orders_validator: List<Output> =
    find_script_outputs(transaction.outputs, orders_script_hash)

  expect Some(output_to_orders_validator) =
    list.head(outputs_to_orders_validator)

  expect InlineDatum(orders_datum) = output_to_orders_validator.datum

  let expected_assets_locked: Value =
    assets.from_lovelace(batcher_fee)
      |> assets.add(
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

  let assets_match: Bool =
    match(output_to_orders_validator.value, expected_assets_locked, >=)

  expect assets_match && only_one_input_from_script

  if close_type == TraderClose {
    let signed_by_owner: Bool =
      list.has(transaction.extra_signatories, datum.owner_address_hash)

    let expected_order_datum =
      OrderDatum {
        action: ClosePositionOrder {
          underlying_asset: datum.underlying_asset,
          owner_address_hash: datum.owner_address_hash,
          positions_script_hash: datum.positions_script_hash,
          order_submission_usd_price: current_price,
          leverage_factor: datum.leverage_factor,
          liquidate_usd_price: datum.liquidate_usd_price,
          entered_at_usd_price: datum.entered_at_usd_price,
          stop_loss_usd_price: datum.stop_loss_usd_price,
          take_profit_usd_price: datum.take_profit_usd_price,
          last_pay_lend_time: datum.last_pay_lend_time,
          positions_mint_asset: datum.positions_mint_asset,
          positions_mint_asset_amount: datum.positions_mint_asset_amount,
          collateral_asset: datum.collateral_asset,
          collateral_asset_amount: datum.collateral_asset_amount,
          strike_collateral_asset: datum.strike_collateral_asset,
          strike_collateral_asset_amount: datum.strike_collateral_asset_amount,
          side: datum.side,
        },
      }

    let expected_order_datum_data: Data =
      builtin.serialise_data(expected_order_datum)

    let orders_datum_valid: Bool = expected_order_datum_data == orders_datum

    signed_by_owner && orders_datum_valid
  } else if close_type == StopLossClose {
    let expected_order_datum =
      OrderDatum {
        action: ClosePositionOrder {
          underlying_asset: datum.underlying_asset,
          owner_address_hash: datum.owner_address_hash,
          positions_script_hash: datum.positions_script_hash,
          order_submission_usd_price: current_price,
          leverage_factor: datum.leverage_factor,
          liquidate_usd_price: datum.liquidate_usd_price,
          entered_at_usd_price: datum.entered_at_usd_price,
          stop_loss_usd_price: datum.stop_loss_usd_price,
          take_profit_usd_price: datum.take_profit_usd_price,
          last_pay_lend_time: datum.last_pay_lend_time,
          positions_mint_asset: datum.positions_mint_asset,
          positions_mint_asset_amount: datum.positions_mint_asset_amount,
          collateral_asset: datum.collateral_asset,
          collateral_asset_amount: datum.collateral_asset_amount,
          strike_collateral_asset: datum.strike_collateral_asset,
          strike_collateral_asset_amount: datum.strike_collateral_asset_amount,
          side: datum.side,
        },
      }

    let expected_order_datum_data: Data =
      builtin.serialise_data(expected_order_datum)

    let orders_datum_valid: Bool = expected_order_datum_data == orders_datum

    let stop_loss_reached: Bool = price_reached_stop_loss(current_price, datum)

    stop_loss_reached && orders_datum_valid
  } else if close_type == TakeProfitClose {
    let expected_order_datum =
      OrderDatum {
        action: ClosePositionOrder {
          underlying_asset: datum.underlying_asset,
          owner_address_hash: datum.owner_address_hash,
          positions_script_hash: datum.positions_script_hash,
          order_submission_usd_price: current_price,
          leverage_factor: datum.leverage_factor,
          liquidate_usd_price: datum.liquidate_usd_price,
          entered_at_usd_price: datum.entered_at_usd_price,
          stop_loss_usd_price: datum.stop_loss_usd_price,
          take_profit_usd_price: datum.take_profit_usd_price,
          last_pay_lend_time: datum.last_pay_lend_time,
          positions_mint_asset: datum.positions_mint_asset,
          positions_mint_asset_amount: datum.positions_mint_asset_amount,
          collateral_asset: datum.collateral_asset,
          collateral_asset_amount: datum.collateral_asset_amount,
          strike_collateral_asset: datum.strike_collateral_asset,
          strike_collateral_asset_amount: datum.strike_collateral_asset_amount,
          side: datum.side,
        },
      }

    let expected_order_datum_data: Data =
      builtin.serialise_data(expected_order_datum)

    let orders_datum_valid: Bool = expected_order_datum_data == orders_datum

    let take_profit_reached: Bool =
      price_reached_take_profit(current_price, datum)

    take_profit_reached && orders_datum_valid
  } else if close_type == LiquidateClose {
    let expected_order_datum =
      OrderDatum {
        action: LiquidatePositionOrder {
          collateral_asset: datum.collateral_asset,
          collateral_asset_amount: datum.collateral_asset_amount,
          positions_mint_asset: datum.positions_mint_asset,
          positions_mint_asset_amount: datum.positions_mint_asset_amount,
          strike_collateral_asset: datum.strike_collateral_asset,
          strike_collateral_asset_amount: datum.strike_collateral_asset_amount,
          side: datum.side,
        },
      }

    let expected_order_datum_data: Data =
      builtin.serialise_data(expected_order_datum)

    let orders_datum_valid: Bool = expected_order_datum_data == orders_datum

    let liquidate_reached: Bool = price_reached_liquidate(current_price, datum)

    liquidate_reached && orders_datum_valid
  } else {
    False
  }
}

// assets are not consumed, user signed transaction, only stop lose is updated 
pub fn update_stop_loss(
  transaction: Transaction,
  datum: Option<PositionDatum>,
  stop_loss_usd_price: Int,
) -> Bool {
  expect Some(input_datum) = datum

  let all_validators_inputs: List<Input> =
    get_all_validators_inputs(transaction)
  let only_one_input_from_script: Bool = list.length(all_validators_inputs) == 1

  expect Some(input_from_script) = list.head(all_validators_inputs)

  let outputs_back_to_positions_validator: List<Output> =
    get_address_outputs(transaction, input_from_script.output.address)

  expect Some(output_to_positions_validator) =
    list.head(outputs_back_to_positions_validator)

  expect InlineDatum(output_datum) = output_to_positions_validator.datum

  let expected_assets_locked: Value =
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
          input_datum.positions_mint_asset.policy_id,
          input_datum.positions_mint_asset.asset_name,
          input_datum.positions_mint_asset_amount,
        )

  let assets_locked_valid: Bool =
    match(output_to_positions_validator.value, expected_assets_locked, >=)

  let expected_output_datum =
    PositionDatum {
      owner_address_hash: input_datum.owner_address_hash,
      positions_script_hash: input_datum.positions_script_hash,
      entered_at_usd_price: input_datum.entered_at_usd_price,
      underlying_asset: input_datum.underlying_asset,
      leverage_factor: input_datum.leverage_factor,
      positions_mint_asset: input_datum.positions_mint_asset,
      positions_mint_asset_amount: input_datum.positions_mint_asset_amount,
      collateral_asset: input_datum.collateral_asset,
      collateral_asset_amount: input_datum.collateral_asset_amount,
      strike_collateral_asset: input_datum.strike_collateral_asset,
      strike_collateral_asset_amount: input_datum.strike_collateral_asset_amount,
      liquidate_usd_price: input_datum.liquidate_usd_price,
      stop_loss_usd_price,
      take_profit_usd_price: input_datum.take_profit_usd_price,
      last_pay_lend_time: input_datum.last_pay_lend_time,
      side: input_datum.side,
    }

  let expected_output_datum_data: Data =
    builtin.serialise_data(expected_output_datum)

  let output_datum_valid: Bool = expected_output_datum_data == output_datum

  only_one_input_from_script && output_datum_valid && assets_locked_valid
}

// assets are not consumed, user signed transaction, only stop lose is updated 
pub fn update_take_profit(
  transaction: Transaction,
  datum: Option<PositionDatum>,
  take_profit_usd_price: Int,
) -> Bool {
  expect Some(input_datum) = datum

  let all_validators_inputs: List<Input> =
    get_all_validators_inputs(transaction)
  let only_one_input_from_script: Bool = list.length(all_validators_inputs) == 1

  expect Some(input_from_script) = list.head(all_validators_inputs)

  let outputs_back_to_positions_validator: List<Output> =
    get_address_outputs(transaction, input_from_script.output.address)
  let only_one_output_to_positions_validator: Bool =
    list.length(outputs_back_to_positions_validator) == 1

  expect Some(output_to_positions_validator) =
    list.head(outputs_back_to_positions_validator)

  expect InlineDatum(output_datum) = output_to_positions_validator.datum

  let expected_assets_locked: Value =
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
          input_datum.positions_mint_asset.policy_id,
          input_datum.positions_mint_asset.asset_name,
          input_datum.positions_mint_asset_amount,
        )

  let assets_locked_valid: Bool =
    match(output_to_positions_validator.value, expected_assets_locked, >=)

  let expected_output_datum =
    PositionDatum {
      owner_address_hash: input_datum.owner_address_hash,
      positions_script_hash: input_datum.positions_script_hash,
      entered_at_usd_price: input_datum.entered_at_usd_price,
      underlying_asset: input_datum.underlying_asset,
      leverage_factor: input_datum.leverage_factor,
      positions_mint_asset: input_datum.positions_mint_asset,
      positions_mint_asset_amount: input_datum.positions_mint_asset_amount,
      collateral_asset: input_datum.collateral_asset,
      collateral_asset_amount: input_datum.collateral_asset_amount,
      strike_collateral_asset: input_datum.strike_collateral_asset,
      strike_collateral_asset_amount: input_datum.strike_collateral_asset_amount,
      liquidate_usd_price: input_datum.liquidate_usd_price,
      stop_loss_usd_price: input_datum.stop_loss_usd_price,
      take_profit_usd_price,
      last_pay_lend_time: input_datum.last_pay_lend_time,
      side: input_datum.side,
    }

  let expected_output_datum_data: Data =
    builtin.serialise_data(expected_output_datum)

  let output_datum_valid: Bool = expected_output_datum_data == output_datum

  only_one_input_from_script && only_one_output_to_positions_validator && output_datum_valid && assets_locked_valid
}

pub fn pay_lend(
  transaction: Transaction,
  datum: Option<PositionDatum>,
  current_price: Int,
  pool_license: PolicyId,
) -> Bool {
  expect Some(datum) = datum

  let all_validators_inputs: List<Input> =
    get_all_validators_inputs(transaction)

  let ref_input: List<Input> = transaction.reference_inputs

  expect Some(Input {
    output: Output { value: batcher_value, datum: pool_ref_datum, .. },
    ..
  }) = list.head(ref_input)

  let pool_license_in_transaction: Bool =
    policy_in_value(pool_license, batcher_value)

  expect InlineDatum(pool_ref_datum) = pool_ref_datum
  expect pool_ref_datum_typed: PoolDatum = pool_ref_datum

  let only_one_input_from_script: Bool = list.length(all_validators_inputs) == 1

  expect Some(input_from_script) = list.head(all_validators_inputs)

  let outputs_back_to_positions_validator: List<Output> =
    get_address_outputs(transaction, input_from_script.output.address)

  expect Some(output_to_positions_validator) =
    list.head(outputs_back_to_positions_validator)

  expect InlineDatum(output_datum) = output_to_positions_validator.datum

  let expected_output_datum =
    PositionDatum {
      owner_address_hash: datum.owner_address_hash,
      positions_script_hash: datum.positions_script_hash,
      entered_at_usd_price: datum.entered_at_usd_price,
      underlying_asset: datum.underlying_asset,
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
      last_pay_lend_time: datum.last_pay_lend_time + 3_600_000,
      side: datum.side,
    }

  let expected_output_datum_data: Data =
    builtin.serialise_data(expected_output_datum)

  let datum_valid: Bool = expected_output_datum_data == output_datum

  let only_one_output_to_positions_validator: Bool =
    list.length(outputs_back_to_positions_validator) == 1

  let expected_burn_amount: Int =
    calculate_pay_borrow(datum, pool_ref_datum_typed, current_price)

  let expected_mint =
    (
      datum.positions_mint_asset.policy_id,
      datum.positions_mint_asset.asset_name,
      expected_burn_amount * -1,
    )

  let mint_valid: Bool = validate_token_mint(transaction.mint, expected_mint)

  let current_time: POSIXTime = get_lower_bound(transaction.validity_range)

  let one_hour_has_passed: Bool =
    current_time >= datum.last_pay_lend_time + 3_600_000

  let position_mint_asset_amount: Int =
    datum.positions_mint_asset_amount - expected_burn_amount

  let expected_assets_locked: Value =
    assets.from_asset(
      datum.collateral_asset.policy_id,
      datum.collateral_asset.asset_name,
      datum.collateral_asset_amount,
    )
      |> assets.add(
          datum.strike_collateral_asset.policy_id,
          datum.strike_collateral_asset.asset_name,
          datum.strike_collateral_asset_amount,
        )
      |> assets.add(
          datum.positions_mint_asset.policy_id,
          datum.positions_mint_asset.asset_name,
          position_mint_asset_amount,
        )

  let assets_locked_valid: Bool =
    match(output_to_positions_validator.value, expected_assets_locked, ==)

  only_one_input_from_script && only_one_output_to_positions_validator && one_hour_has_passed && datum_valid && mint_valid && assets_locked_valid && pool_license_in_transaction
}

pub fn mint_position(
  transaction: Transaction,
  params: PositionsParams,
  current_price: Int,
  policy_id: PolicyId,
  pool_license: PolicyId,
) {
  let outputs_to_orders_address: List<Output> =
    find_script_outputs(transaction.outputs, params.orders_script_hash)

  let only_one_output_to_orders: Bool =
    list.length(outputs_to_orders_address) == 1

  expect Some(output_to_orders_validator) = list.head(outputs_to_orders_address)

  expect InlineDatum(orders_datum) = output_to_orders_validator.datum

  expect orders_datum_typed: OrderDatum = orders_datum

  let ref_input: List<Input> = transaction.reference_inputs

  expect Some(Input {
    output: Output { value: batcher_value, datum: pool_ref_datum, .. },
    ..
  }) = list.head(ref_input)

  let pool_license_in_transaction: Bool =
    policy_in_value(pool_license, batcher_value)

  expect InlineDatum(pool_ref_datum) = pool_ref_datum
  expect pool_ref_datum_typed: PoolDatum = pool_ref_datum

  expect OpenPositionOrder {
    underlying_asset,
    owner_address_hash,
    leverage_factor,
    side,
    order_submission_time,
    order_submission_usd_price,
    positions_mint_asset,
    positions_mint_asset_amount,
    collateral_asset,
    collateral_asset_amount,
    strike_collateral_asset,
    strike_collateral_asset_amount,
    ..
  } = orders_datum_typed.action

  let expected_mint: (PolicyId, ByteArray, Int) =
    (policy_id, owner_address_hash, positions_mint_asset_amount)

  let mint_valid: Bool = validate_token_mint(transaction.mint, expected_mint)

  let liquidate_usd_price: Int =
    calculate_liquidate_amount(
      leverage_factor,
      current_price,
      pool_ref_datum_typed.liquidate_margin,
      side,
    )

  let expected_assets_locked: Value =
    assets.from_lovelace(batcher_fee)
      |> assets.add(policy_id, owner_address_hash, positions_mint_asset_amount)
      |> assets.add(
          collateral_asset.policy_id,
          collateral_asset.asset_name,
          collateral_asset_amount,
        )
      |> assets.add(
          strike_collateral_asset.policy_id,
          strike_collateral_asset.asset_name,
          strike_collateral_asset_amount,
        )

  let assets_locked_valid: Bool =
    match(output_to_orders_validator.value, expected_assets_locked, >=)

  let minted_assets_amount_valid: Bool =
    minted_assets_amount_valid(
      side,
      positions_mint_asset_amount,
      underlying_asset,
      leverage_factor,
      collateral_asset_amount,
      current_price,
    )

  let is_valid_collateral =
    is_valid_collateral(pool_ref_datum_typed, collateral_asset, side)

  let liquidate_usd_price_valid: Bool =
    liquidate_usd_price >= liquidate_usd_price

  let entered_at_usd_price_valid: Bool =
    current_price == order_submission_usd_price

  let submission_time_valid: Bool =
    get_lower_bound(transaction.validity_range) >= order_submission_time

  let minted_asset_valid: Bool =
    positions_mint_asset.policy_id == policy_id && positions_mint_asset.asset_name == owner_address_hash

  let owner_address_hash_valid: Bool =
    list.has(transaction.extra_signatories, owner_address_hash)
  let underlying_asset_valid: Bool =
    underlying_asset == pool_ref_datum_typed.underlying_asset

  expect
    only_one_output_to_orders && minted_assets_amount_valid && assets_locked_valid && mint_valid && liquidate_usd_price_valid && entered_at_usd_price_valid && submission_time_valid && minted_asset_valid && owner_address_hash_valid && underlying_asset_valid && is_valid_collateral && pool_license_in_transaction

  let contains_strike_collateral: Bool =
    quantity_of(
      output_to_orders_validator.value,
      strike_collateral_asset.policy_id,
      strike_collateral_asset.asset_name,
    ) > 0

  if contains_strike_collateral {
    let leverage_factor_valid: Bool =
      pool_ref_datum_typed.max_strike_holder_leverage_factor >= leverage_factor

    leverage_factor_valid
  } else {
    let leverage_factor_valid: Bool =
      pool_ref_datum_typed.max_leverage_factor >= leverage_factor

    leverage_factor_valid
  }
}

fn is_valid_collateral(
  pool_ref: PoolDatum,
  collateral_asset: Asset,
  side: PositionSide,
) -> Bool {
  if side == Long {
    collateral_asset == pool_ref.underlying_asset
  } else {
    collateral_asset == pool_ref.stable_collateral_asset
  }
}

fn minted_assets_amount_valid(
  position_side: PositionSide,
  positions_mint_asset_amount: Int,
  underlying_asset: Asset,
  leverage_factor: Int,
  collateral_asset_amount: Int,
  current_price: Int,
) -> Bool {
  if position_side == Long {
    positions_mint_asset_amount / leverage_factor <= collateral_asset_amount
  } else {
    let formatted_assets =
      minted_assets_to_ada(
        underlying_asset,
        leverage_factor,
        positions_mint_asset_amount,
      )

    formatted_assets <= collateral_asset_amount / current_price
  }
}

fn minted_assets_to_ada(
  underlying_asset: Asset,
  leverage_factor: Int,
  positions_mint_asset_amount: Int,
) -> Int {
  if underlying_asset.policy_id == "" {
    positions_mint_asset_amount / leverage_factor / 1_000_000
  } else {
    positions_mint_asset_amount / leverage_factor
  }
}

fn calculate_liquidate_amount(
  leverage_factor: Int,
  current_price: Int,
  liquidate_margin: Int,
  position_side: PositionSide,
) {
  if position_side == Long {
    let formatted_liquidate_margin = liquidate_margin / 100
    current_price * ( 1 - ( 1 - formatted_liquidate_margin ) / leverage_factor )
  } else {
    let formatted_liquidate_margin = liquidate_margin / 100
    current_price * ( 1 + ( 1 - formatted_liquidate_margin ) / leverage_factor )
  }
}

fn price_reached_stop_loss(current_price: Int, datum: PositionDatum) -> Bool {
  if datum.side == Long {
    current_price <= datum.stop_loss_usd_price
  } else {
    current_price >= datum.stop_loss_usd_price
  }
}

fn price_reached_take_profit(current_price: Int, datum: PositionDatum) -> Bool {
  if datum.side == Long {
    current_price >= datum.take_profit_usd_price
  } else {
    current_price <= datum.take_profit_usd_price
  }
}

fn price_reached_liquidate(current_price: Int, datum: PositionDatum) -> Bool {
  if datum.side == Long {
    current_price <= datum.liquidate_usd_price
  } else {
    current_price >= datum.liquidate_usd_price
  }
}

fn calculate_pay_borrow(
  position_datum: PositionDatum,
  pool_datum: PoolDatum,
  current_price: Int,
) -> Int {
  expect Some(utilization) =
    rational.new(
      pool_datum.underlying_asset_lended_amount,
      pool_datum.underlying_asset_amount,
    )

  let utilization_percentage = rational.ceil(utilization)

  let current_position_usd_value =
    position_datum.positions_mint_asset_amount * current_price

  let pay_borrow_usd_amount =
    utilization_percentage * pool_datum.underlying_interest_rate * current_position_usd_value / 100

  expect Some(token_amount) = rational.new(pay_borrow_usd_amount, current_price)

  rational.ceil(token_amount)
}
