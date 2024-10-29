use aiken/collection/dict
use aiken/interval.{Finite, Interval, IntervalBound}
use aiken/primitive/string
use cardano/address.{Script, from_script, from_verification_key}
use cardano/assets.{from_lovelace}
use cardano/transaction.{InlineDatum, Input, NoDatum, Output, Transaction}
use orders
use tests/constants.{
  batcher_license, liquidity_positions_script_hash, lovelace_asset,
  maximum_deadline_range, orders_script_hash, out_ref, pool_asset,
  pool_asset_name, pool_license, pool_script_hash, positions_mint_asset,
  positions_script_hash, stable_collateral_asset, strike_collateral_asset,
  trader_pkh, underlying_asset,
}
use types.{
  Asset, CancelOrders, ClosePositionOrder, Long, OpenPositionOrder, OrdersDatum,
  OrdersParams, OrdersWithdrawRedeemer, PoolDatum, PositionDatum, Short,
}
use utils.{divide, format_stable_if_lovelace}

const pool_datum =
  PoolDatum {
    underlying_asset: lovelace_asset,
    underlying_asset_amount: 1_000_000_000_000_000,
    underlying_asset_lended_amount: 1_000_000,
    underlying_interest_rate: 2,
    stable_collateral_asset,
    max_leverage_factor: 10,
    liquidate_margin: 5,
    max_strike_holder_leverage_factor: 20,
    maintain_margin_amount: 0,
    is_valid_pool_asset: pool_asset,
    earnings_per_share: 0,
    collateral_earnings_per_share: 0,
    stable_collateral_asset_amount: 100_000_000,
  }

const pool_input =
  Input {
    output_reference: out_ref,
    output: Output {
      address: from_script(pool_script_hash),
      value: from_lovelace(1_000_000_000_000_000)
        |> assets.add(pool_license, pool_asset_name, 1)
        |> assets.add(
            pool_datum.underlying_asset.policy_id,
            pool_datum.underlying_asset.asset_name,
            pool_datum.underlying_asset_amount,
          )
        |> assets.add(
            pool_datum.stable_collateral_asset.policy_id,
            pool_datum.stable_collateral_asset.asset_name,
            pool_datum.stable_collateral_asset_amount,
          ),
      datum: InlineDatum(pool_datum),
      reference_script: None,
    },
  }

test cancel_open_position() {
  let orders_datum =
    OrdersDatum {
      owner_address_hash: trader_pkh,
      underlying_asset,
      underlying_asset_amount: 10,
      leverage_factor: 10,
      orders_script_hash,
      positions_script_hash: orders_script_hash,
      positions_mint_asset,
      positions_mint_asset_amount: 10_000_000,
      liquidity_asset: underlying_asset,
      liquidity_asset_amount: 10,
      liquidity_positions_script_hash,
      collateral_asset: lovelace_asset,
      collateral_asset_amount: 1_000_000,
      strike_collateral_asset,
      strike_collateral_asset_amount: 10,
      entered_earnings_per_share: 0,
      entered_collateral_earnings_per_share: 0,
      liquidate_usd_price: 100,
      stop_loss_usd_price: 0,
      take_profit_usd_price: 0,
      order_submission_time: 1727453227635,
      entered_at_usd_price: 100,
      order_submission_usd_price: 100,
      pool_license,
      action: OpenPositionOrder,
      side: Long,
    }

  let orders_input =
    Input {
      output_reference: out_ref,
      output: Output {
        address: from_script(orders_script_hash),
        value: from_lovelace(2_000_000)
          |> assets.add(pool_license, "", 1),
        datum: InlineDatum(orders_datum),
        reference_script: None,
      },
    }

  let mint =
    assets.from_asset(
      orders_datum.positions_mint_asset.policy_id,
      orders_datum.positions_mint_asset.asset_name,
      -orders_datum.positions_mint_asset_amount,
    )

  let tx =
    Transaction {
      inputs: [orders_input],
      reference_inputs: [],
      outputs: [],
      fee: 0,
      mint,
      certificates: [],
      withdrawals: [],
      validity_range: Interval {
        lower_bound: IntervalBound {
          bound_type: Finite(1727453227635),
          is_inclusive: False,
        },
        upper_bound: IntervalBound {
          bound_type: Finite(1727456400000),
          is_inclusive: False,
        },
      },
      extra_signatories: [trader_pkh],
      redeemers: [],
      datums: dict.empty,
      id: #"0000000000000000000000000000000000000000000000000000000000000000",
      votes: [],
      proposal_procedures: [],
      current_treasury_amount: None,
      treasury_donation: None,
    }

  let params =
    OrdersParams {
      batcher_license,
      maximum_deadline_range: 1000,
      underlying_asset_policy_id: underlying_asset.policy_id,
      underlying_asset_name: underlying_asset.asset_name,
    }
  let redeemer = CancelOrders(0)
  orders.orders.spend(params, Some(orders_datum), redeemer, out_ref, tx)
}

test cancel_close_position() {
  let orders_datum =
    OrdersDatum {
      owner_address_hash: trader_pkh,
      underlying_asset,
      underlying_asset_amount: 10,
      leverage_factor: 10,
      orders_script_hash,
      positions_script_hash: orders_script_hash,
      positions_mint_asset,
      positions_mint_asset_amount: 10_000_000,
      liquidity_asset: underlying_asset,
      liquidity_asset_amount: 10,
      liquidity_positions_script_hash,
      collateral_asset: lovelace_asset,
      collateral_asset_amount: 1_000_000,
      strike_collateral_asset,
      strike_collateral_asset_amount: 10,
      entered_earnings_per_share: 0,
      entered_collateral_earnings_per_share: 0,
      liquidate_usd_price: 100,
      stop_loss_usd_price: 0,
      take_profit_usd_price: 0,
      order_submission_time: 1727453227635,
      entered_at_usd_price: 100,
      order_submission_usd_price: 100,
      pool_license,
      action: ClosePositionOrder,
      side: Long,
    }

  let orders_input =
    Input {
      output_reference: out_ref,
      output: Output {
        address: from_script(orders_script_hash),
        value: from_lovelace(2_000_000)
          |> assets.add(
              orders_datum.positions_mint_asset.policy_id,
              orders_datum.positions_mint_asset.asset_name,
              orders_datum.positions_mint_asset_amount,
            )
          |> assets.add(
              orders_datum.collateral_asset.policy_id,
              orders_datum.collateral_asset.asset_name,
              orders_datum.collateral_asset_amount,
            )
          |> assets.add(
              orders_datum.strike_collateral_asset.policy_id,
              orders_datum.strike_collateral_asset.asset_name,
              orders_datum.strike_collateral_asset_amount,
            ),
        datum: InlineDatum(orders_datum),
        reference_script: None,
      },
    }

  let positions_datum =
    PositionDatum {
      owner_address_hash: orders_datum.owner_address_hash,
      entered_at_usd_price: orders_datum.entered_at_usd_price,
      underlying_asset: orders_datum.underlying_asset,
      leverage_factor: orders_datum.leverage_factor,
      positions_mint_asset: orders_datum.positions_mint_asset,
      positions_mint_asset_amount: orders_datum.positions_mint_asset_amount,
      collateral_asset: orders_datum.collateral_asset,
      collateral_asset_amount: orders_datum.collateral_asset_amount,
      strike_collateral_asset: orders_datum.strike_collateral_asset,
      strike_collateral_asset_amount: orders_datum.strike_collateral_asset_amount,
      liquidate_usd_price: orders_datum.liquidate_usd_price,
      stop_loss_usd_price: orders_datum.stop_loss_usd_price,
      take_profit_usd_price: orders_datum.take_profit_usd_price,
      last_pay_lend_time: orders_datum.order_submission_time,
      pool_license: orders_datum.pool_license,
      side: orders_datum.side,
    }

  let position_output =
    Output {
      address: from_script(orders_script_hash),
      value: from_lovelace(2_000_000)
        |> assets.add(
            orders_datum.positions_mint_asset.policy_id,
            orders_datum.positions_mint_asset.asset_name,
            orders_datum.positions_mint_asset_amount,
          )
        |> assets.add(
            orders_datum.collateral_asset.policy_id,
            orders_datum.collateral_asset.asset_name,
            orders_datum.collateral_asset_amount,
          )
        |> assets.add(
            orders_datum.strike_collateral_asset.policy_id,
            orders_datum.strike_collateral_asset.asset_name,
            orders_datum.strike_collateral_asset_amount,
          ),
      datum: InlineDatum(positions_datum),
      reference_script: None,
    }

  let tx =
    Transaction {
      inputs: [orders_input],
      reference_inputs: [],
      outputs: [position_output],
      fee: 0,
      mint: assets.zero,
      certificates: [],
      withdrawals: [],
      validity_range: Interval {
        lower_bound: IntervalBound {
          bound_type: Finite(1727453227635),
          is_inclusive: False,
        },
        upper_bound: IntervalBound {
          bound_type: Finite(1727456400000),
          is_inclusive: False,
        },
      },
      extra_signatories: [trader_pkh],
      redeemers: [],
      datums: dict.empty,
      id: #"0000000000000000000000000000000000000000000000000000000000000000",
      votes: [],
      proposal_procedures: [],
      current_treasury_amount: None,
      treasury_donation: None,
    }

  let params =
    OrdersParams {
      batcher_license,
      maximum_deadline_range: 1000,
      underlying_asset_policy_id: underlying_asset.policy_id,
      underlying_asset_name: underlying_asset.asset_name,
    }
  let redeemer = CancelOrders(0)
  orders.orders.spend(params, Some(orders_datum), redeemer, out_ref, tx)
}

test open_position() {
  let orders_datum =
    OrdersDatum {
      owner_address_hash: trader_pkh,
      underlying_asset,
      underlying_asset_amount: 10,
      leverage_factor: 10,
      orders_script_hash,
      positions_script_hash,
      positions_mint_asset,
      positions_mint_asset_amount: 10_000_000,
      liquidity_asset: underlying_asset,
      liquidity_asset_amount: 10,
      liquidity_positions_script_hash,
      collateral_asset: lovelace_asset,
      collateral_asset_amount: 1_000_000,
      strike_collateral_asset,
      strike_collateral_asset_amount: 10,
      entered_earnings_per_share: 0,
      entered_collateral_earnings_per_share: 0,
      liquidate_usd_price: 100,
      stop_loss_usd_price: 0,
      take_profit_usd_price: 0,
      order_submission_time: 1727453227635,
      entered_at_usd_price: 100,
      order_submission_usd_price: 100,
      pool_license,
      action: OpenPositionOrder,
      side: Long,
    }

  let orders_input =
    Input {
      output_reference: out_ref,
      output: Output {
        address: from_script(orders_script_hash),
        value: from_lovelace(2_000_000)
          |> assets.add(
              orders_datum.positions_mint_asset.policy_id,
              orders_datum.positions_mint_asset.asset_name,
              orders_datum.positions_mint_asset_amount,
            )
          |> assets.add(
              orders_datum.collateral_asset.policy_id,
              orders_datum.collateral_asset.asset_name,
              orders_datum.collateral_asset_amount,
            )
          |> assets.add(
              orders_datum.strike_collateral_asset.policy_id,
              orders_datum.strike_collateral_asset.asset_name,
              orders_datum.strike_collateral_asset_amount,
            ),
        datum: InlineDatum(orders_datum),
        reference_script: None,
      },
    }

  let positions_datum =
    PositionDatum {
      owner_address_hash: orders_datum.owner_address_hash,
      entered_at_usd_price: orders_datum.entered_at_usd_price,
      underlying_asset: orders_datum.underlying_asset,
      leverage_factor: orders_datum.leverage_factor,
      positions_mint_asset: orders_datum.positions_mint_asset,
      positions_mint_asset_amount: orders_datum.positions_mint_asset_amount,
      collateral_asset: orders_datum.collateral_asset,
      collateral_asset_amount: orders_datum.collateral_asset_amount,
      strike_collateral_asset: orders_datum.strike_collateral_asset,
      strike_collateral_asset_amount: orders_datum.strike_collateral_asset_amount,
      liquidate_usd_price: orders_datum.liquidate_usd_price,
      stop_loss_usd_price: orders_datum.stop_loss_usd_price,
      take_profit_usd_price: orders_datum.take_profit_usd_price,
      last_pay_lend_time: orders_datum.order_submission_time,
      pool_license: orders_datum.pool_license,
      side: orders_datum.side,
    }

  let position_output =
    Output {
      address: from_script(positions_script_hash),
      value: from_lovelace(2_000_000)
        |> assets.add(
            orders_datum.positions_mint_asset.policy_id,
            orders_datum.positions_mint_asset.asset_name,
            orders_datum.positions_mint_asset_amount,
          )
        |> assets.add(
            orders_datum.collateral_asset.policy_id,
            orders_datum.collateral_asset.asset_name,
            orders_datum.collateral_asset_amount,
          )
        |> assets.add(
            orders_datum.strike_collateral_asset.policy_id,
            orders_datum.strike_collateral_asset.asset_name,
            orders_datum.strike_collateral_asset_amount,
          ),
      datum: InlineDatum(positions_datum),
      reference_script: None,
    }

  let lended_amount =
    orders_datum.positions_mint_asset_amount / orders_datum.leverage_factor

  let pool_output_datum =
    PoolDatum {
      underlying_asset: pool_datum.underlying_asset,
      underlying_asset_amount: pool_datum.underlying_asset_amount,
      underlying_asset_lended_amount: pool_datum.underlying_asset_lended_amount + lended_amount,
      underlying_interest_rate: pool_datum.underlying_interest_rate,
      stable_collateral_asset: pool_datum.stable_collateral_asset,
      max_leverage_factor: pool_datum.max_leverage_factor,
      liquidate_margin: pool_datum.liquidate_margin,
      max_strike_holder_leverage_factor: pool_datum.max_strike_holder_leverage_factor,
      maintain_margin_amount: pool_datum.maintain_margin_amount,
      is_valid_pool_asset: pool_datum.is_valid_pool_asset,
      earnings_per_share: pool_datum.earnings_per_share,
      collateral_earnings_per_share: pool_datum.collateral_earnings_per_share,
      stable_collateral_asset_amount: pool_datum.stable_collateral_asset_amount,
    }

  let pool_output =
    Output {
      address: from_script(pool_script_hash),
      value: pool_input.output.value,
      datum: InlineDatum(pool_output_datum),
      reference_script: None,
    }

  let input_batcher =
    Input {
      output_reference: out_ref,
      output: Output {
        address: from_script(#""),
        value: assets.add(
          assets.zero,
          batcher_license,
          string.to_bytearray(@"1727715600000"),
          1,
        ),
        datum: NoDatum,
        reference_script: None,
      },
    }

  let tx =
    Transaction {
      inputs: [orders_input, pool_input, input_batcher],
      reference_inputs: [],
      outputs: [position_output, pool_output],
      fee: 0,
      mint: assets.zero,
      certificates: [],
      withdrawals: [],
      validity_range: Interval {
        lower_bound: IntervalBound {
          bound_type: Finite(1727453227635),
          is_inclusive: False,
        },
        upper_bound: IntervalBound {
          bound_type: Finite(1727456400000),
          is_inclusive: False,
        },
      },
      extra_signatories: [trader_pkh],
      redeemers: [],
      datums: dict.empty,
      id: #"0000000000000000000000000000000000000000000000000000000000000000",
      votes: [],
      proposal_procedures: [],
      current_treasury_amount: None,
      treasury_donation: None,
    }

  let params =
    OrdersParams {
      batcher_license,
      maximum_deadline_range,
      underlying_asset_policy_id: underlying_asset.policy_id,
      underlying_asset_name: underlying_asset.asset_name,
    }

  let credential = Script(orders_script_hash)

  let redeemer =
    OrdersWithdrawRedeemer {
      indexer: [(0, 0)],
      pool_utxo_index: (1, 1),
      batcher_index: 2,
    }

  orders.orders.withdraw(params, redeemer, credential, tx)
}

test close_profit_long_position() {
  let orders_datum =
    OrdersDatum {
      owner_address_hash: trader_pkh,
      underlying_asset,
      underlying_asset_amount: 10,
      leverage_factor: 10,
      orders_script_hash,
      positions_script_hash,
      positions_mint_asset,
      positions_mint_asset_amount: 10_000_000,
      liquidity_asset: underlying_asset,
      liquidity_asset_amount: 10,
      liquidity_positions_script_hash,
      collateral_asset: lovelace_asset,
      collateral_asset_amount: 1_000_000,
      strike_collateral_asset,
      strike_collateral_asset_amount: 10,
      entered_earnings_per_share: 0,
      entered_collateral_earnings_per_share: 0,
      liquidate_usd_price: 100,
      stop_loss_usd_price: 0,
      take_profit_usd_price: 0,
      order_submission_time: 1727453227635,
      entered_at_usd_price: 70,
      order_submission_usd_price: 90,
      pool_license,
      action: ClosePositionOrder,
      side: Long,
    }

  let orders_input =
    Input {
      output_reference: out_ref,
      output: Output {
        address: from_script(orders_script_hash),
        value: from_lovelace(2_000_000)
          |> assets.add(
              orders_datum.positions_mint_asset.policy_id,
              orders_datum.positions_mint_asset.asset_name,
              orders_datum.positions_mint_asset_amount,
            )
          |> assets.add(
              orders_datum.collateral_asset.policy_id,
              orders_datum.collateral_asset.asset_name,
              orders_datum.collateral_asset_amount,
            )
          |> assets.add(
              orders_datum.strike_collateral_asset.policy_id,
              orders_datum.strike_collateral_asset.asset_name,
              orders_datum.strike_collateral_asset_amount,
            ),
        datum: InlineDatum(orders_datum),
        reference_script: None,
      },
    }

  let estimated_profit =
    orders_datum.order_submission_usd_price * orders_datum.positions_mint_asset_amount - orders_datum.entered_at_usd_price * orders_datum.positions_mint_asset_amount
  let gain_asset_amount =
    divide(estimated_profit, orders_datum.order_submission_usd_price)

  let trader_output =
    Output {
      address: from_verification_key(trader_pkh),
      value: from_lovelace(2_000_000)
        |> assets.add(
            orders_datum.collateral_asset.policy_id,
            orders_datum.collateral_asset.asset_name,
            orders_datum.collateral_asset_amount + gain_asset_amount,
          )
        |> assets.add(
            orders_datum.strike_collateral_asset.policy_id,
            orders_datum.strike_collateral_asset.asset_name,
            orders_datum.strike_collateral_asset_amount,
          ),
      datum: NoDatum,
      reference_script: None,
    }

  let pool_output_datum =
    PoolDatum {
      underlying_asset: pool_datum.underlying_asset,
      underlying_asset_amount: pool_datum.underlying_asset_amount - gain_asset_amount,
      underlying_asset_lended_amount: pool_datum.underlying_asset_lended_amount,
      underlying_interest_rate: pool_datum.underlying_interest_rate,
      stable_collateral_asset: pool_datum.stable_collateral_asset,
      max_leverage_factor: pool_datum.max_leverage_factor,
      liquidate_margin: pool_datum.liquidate_margin,
      max_strike_holder_leverage_factor: pool_datum.max_strike_holder_leverage_factor,
      maintain_margin_amount: pool_datum.maintain_margin_amount,
      is_valid_pool_asset: pool_datum.is_valid_pool_asset,
      earnings_per_share: pool_datum.earnings_per_share,
      collateral_earnings_per_share: pool_datum.collateral_earnings_per_share,
      stable_collateral_asset_amount: pool_datum.stable_collateral_asset_amount,
    }

  let pool_output =
    Output {
      address: from_script(pool_script_hash),
      value: pool_input.output.value
        |> assets.add(
            pool_datum.underlying_asset.policy_id,
            pool_datum.underlying_asset.asset_name,
            -gain_asset_amount,
          ),
      datum: InlineDatum(pool_output_datum),
      reference_script: None,
    }

  let input_batcher =
    Input {
      output_reference: out_ref,
      output: Output {
        address: from_script(#""),
        value: assets.add(
          assets.zero,
          batcher_license,
          string.to_bytearray(@"1727715600000"),
          1,
        ),
        datum: NoDatum,
        reference_script: None,
      },
    }

  let mint =
    assets.from_asset(
      orders_datum.positions_mint_asset.policy_id,
      orders_datum.positions_mint_asset.asset_name,
      -orders_datum.positions_mint_asset_amount,
    )

  let tx =
    Transaction {
      inputs: [orders_input, pool_input, input_batcher],
      reference_inputs: [],
      outputs: [trader_output, pool_output],
      fee: 0,
      mint,
      certificates: [],
      withdrawals: [],
      validity_range: Interval {
        lower_bound: IntervalBound {
          bound_type: Finite(1727453227635),
          is_inclusive: False,
        },
        upper_bound: IntervalBound {
          bound_type: Finite(1727456400000),
          is_inclusive: False,
        },
      },
      extra_signatories: [trader_pkh],
      redeemers: [],
      datums: dict.empty,
      id: #"0000000000000000000000000000000000000000000000000000000000000000",
      votes: [],
      proposal_procedures: [],
      current_treasury_amount: None,
      treasury_donation: None,
    }

  let params =
    OrdersParams {
      batcher_license,
      maximum_deadline_range,
      underlying_asset_policy_id: underlying_asset.policy_id,
      underlying_asset_name: underlying_asset.asset_name,
    }

  let credential = Script(orders_script_hash)

  let redeemer =
    OrdersWithdrawRedeemer {
      indexer: [(0, 0)],
      pool_utxo_index: (1, 1),
      batcher_index: 2,
    }

  orders.orders.withdraw(params, redeemer, credential, tx)
}

test close_profit_short_position() {
  let orders_datum =
    OrdersDatum {
      owner_address_hash: trader_pkh,
      underlying_asset,
      underlying_asset_amount: 10,
      leverage_factor: 10,
      orders_script_hash,
      positions_script_hash,
      positions_mint_asset,
      positions_mint_asset_amount: 10_000_000,
      liquidity_asset: underlying_asset,
      liquidity_asset_amount: 10,
      liquidity_positions_script_hash,
      collateral_asset: stable_collateral_asset,
      collateral_asset_amount: 1_000_000,
      strike_collateral_asset,
      strike_collateral_asset_amount: 10,
      entered_earnings_per_share: 0,
      entered_collateral_earnings_per_share: 0,
      liquidate_usd_price: 100,
      stop_loss_usd_price: 0,
      take_profit_usd_price: 0,
      order_submission_time: 1727453227635,
      entered_at_usd_price: 70,
      order_submission_usd_price: 60,
      pool_license,
      action: ClosePositionOrder,
      side: Short,
    }

  let orders_input =
    Input {
      output_reference: out_ref,
      output: Output {
        address: from_script(orders_script_hash),
        value: from_lovelace(2_000_000)
          |> assets.add(
              orders_datum.positions_mint_asset.policy_id,
              orders_datum.positions_mint_asset.asset_name,
              orders_datum.positions_mint_asset_amount,
            )
          |> assets.add(
              orders_datum.collateral_asset.policy_id,
              orders_datum.collateral_asset.asset_name,
              orders_datum.collateral_asset_amount,
            )
          |> assets.add(
              orders_datum.strike_collateral_asset.policy_id,
              orders_datum.strike_collateral_asset.asset_name,
              orders_datum.strike_collateral_asset_amount,
            ),
        datum: InlineDatum(orders_datum),
        reference_script: None,
      },
    }

  let estimated_profit =
    orders_datum.entered_at_usd_price * orders_datum.positions_mint_asset_amount - orders_datum.order_submission_usd_price * orders_datum.positions_mint_asset_amount
  let gain_asset_amount =
    divide(estimated_profit, orders_datum.order_submission_usd_price)

  let trader_output =
    Output {
      address: from_verification_key(trader_pkh),
      value: assets.from_asset(
        orders_datum.collateral_asset.policy_id,
        orders_datum.collateral_asset.asset_name,
        orders_datum.collateral_asset_amount,
      )
        |> assets.add(
            orders_datum.strike_collateral_asset.policy_id,
            orders_datum.strike_collateral_asset.asset_name,
            orders_datum.strike_collateral_asset_amount,
          )
        |> assets.add(
            pool_datum.underlying_asset.policy_id,
            pool_datum.underlying_asset.asset_name,
            gain_asset_amount,
          ),
      datum: NoDatum,
      reference_script: None,
    }

  let pool_output_datum =
    PoolDatum {
      underlying_asset: pool_datum.underlying_asset,
      underlying_asset_amount: pool_datum.underlying_asset_amount - gain_asset_amount,
      underlying_asset_lended_amount: pool_datum.underlying_asset_lended_amount,
      underlying_interest_rate: pool_datum.underlying_interest_rate,
      stable_collateral_asset: pool_datum.stable_collateral_asset,
      max_leverage_factor: pool_datum.max_leverage_factor,
      liquidate_margin: pool_datum.liquidate_margin,
      max_strike_holder_leverage_factor: pool_datum.max_strike_holder_leverage_factor,
      maintain_margin_amount: pool_datum.maintain_margin_amount,
      is_valid_pool_asset: pool_datum.is_valid_pool_asset,
      earnings_per_share: pool_datum.earnings_per_share,
      collateral_earnings_per_share: pool_datum.collateral_earnings_per_share,
      stable_collateral_asset_amount: pool_datum.stable_collateral_asset_amount,
    }

  let pool_output =
    Output {
      address: from_script(pool_script_hash),
      value: pool_input.output.value
        |> assets.add(
            pool_datum.underlying_asset.policy_id,
            pool_datum.underlying_asset.asset_name,
            gain_asset_amount,
          ),
      datum: InlineDatum(pool_output_datum),
      reference_script: None,
    }

  let input_batcher =
    Input {
      output_reference: out_ref,
      output: Output {
        address: from_script(#""),
        value: assets.add(
          assets.zero,
          batcher_license,
          string.to_bytearray(@"1727715600000"),
          1,
        ),
        datum: NoDatum,
        reference_script: None,
      },
    }

  let mint =
    assets.from_asset(
      orders_datum.positions_mint_asset.policy_id,
      orders_datum.positions_mint_asset.asset_name,
      -orders_datum.positions_mint_asset_amount,
    )

  let tx =
    Transaction {
      inputs: [orders_input, pool_input, input_batcher],
      reference_inputs: [],
      outputs: [trader_output, pool_output],
      fee: 0,
      mint,
      certificates: [],
      withdrawals: [],
      validity_range: Interval {
        lower_bound: IntervalBound {
          bound_type: Finite(1727453227635),
          is_inclusive: False,
        },
        upper_bound: IntervalBound {
          bound_type: Finite(1727456400000),
          is_inclusive: False,
        },
      },
      extra_signatories: [trader_pkh],
      redeemers: [],
      datums: dict.empty,
      id: #"0000000000000000000000000000000000000000000000000000000000000000",
      votes: [],
      proposal_procedures: [],
      current_treasury_amount: None,
      treasury_donation: None,
    }

  let params =
    OrdersParams {
      batcher_license,
      maximum_deadline_range,
      underlying_asset_policy_id: underlying_asset.policy_id,
      underlying_asset_name: underlying_asset.asset_name,
    }

  let credential = Script(orders_script_hash)

  let redeemer =
    OrdersWithdrawRedeemer {
      indexer: [(0, 0)],
      pool_utxo_index: (1, 1),
      batcher_index: 2,
    }

  orders.orders.withdraw(params, redeemer, credential, tx)
}

test close_loss_long_position() {
  let orders_datum =
    OrdersDatum {
      owner_address_hash: trader_pkh,
      underlying_asset,
      underlying_asset_amount: 10,
      leverage_factor: 10,
      orders_script_hash,
      positions_script_hash,
      positions_mint_asset,
      positions_mint_asset_amount: 10_000_000,
      liquidity_asset: underlying_asset,
      liquidity_asset_amount: 10,
      liquidity_positions_script_hash,
      collateral_asset: lovelace_asset,
      collateral_asset_amount: 10_000_000,
      strike_collateral_asset,
      strike_collateral_asset_amount: 10,
      entered_earnings_per_share: 0,
      entered_collateral_earnings_per_share: 0,
      liquidate_usd_price: 100,
      stop_loss_usd_price: 0,
      take_profit_usd_price: 0,
      order_submission_time: 1727453227635,
      entered_at_usd_price: 100,
      order_submission_usd_price: 90,
      pool_license,
      action: ClosePositionOrder,
      side: Long,
    }

  let orders_input =
    Input {
      output_reference: out_ref,
      output: Output {
        address: from_script(orders_script_hash),
        value: from_lovelace(2_000_000)
          |> assets.add(
              orders_datum.positions_mint_asset.policy_id,
              orders_datum.positions_mint_asset.asset_name,
              orders_datum.positions_mint_asset_amount,
            )
          |> assets.add(
              orders_datum.collateral_asset.policy_id,
              orders_datum.collateral_asset.asset_name,
              orders_datum.collateral_asset_amount,
            )
          |> assets.add(
              orders_datum.strike_collateral_asset.policy_id,
              orders_datum.strike_collateral_asset.asset_name,
              orders_datum.strike_collateral_asset_amount,
            ),
        datum: InlineDatum(orders_datum),
        reference_script: None,
      },
    }

  let estimated_profit =
    orders_datum.order_submission_usd_price * orders_datum.positions_mint_asset_amount - orders_datum.entered_at_usd_price * orders_datum.positions_mint_asset_amount

  let loss_asset_amount =
    divide(-estimated_profit, orders_datum.order_submission_usd_price)

  let positions_datum =
    PositionDatum {
      owner_address_hash: orders_datum.owner_address_hash,
      entered_at_usd_price: orders_datum.entered_at_usd_price,
      underlying_asset: orders_datum.underlying_asset,
      leverage_factor: orders_datum.leverage_factor,
      positions_mint_asset: orders_datum.positions_mint_asset,
      positions_mint_asset_amount: orders_datum.positions_mint_asset_amount,
      collateral_asset: orders_datum.collateral_asset,
      collateral_asset_amount: orders_datum.collateral_asset_amount,
      strike_collateral_asset: orders_datum.strike_collateral_asset,
      strike_collateral_asset_amount: orders_datum.strike_collateral_asset_amount,
      liquidate_usd_price: orders_datum.liquidate_usd_price,
      stop_loss_usd_price: orders_datum.stop_loss_usd_price,
      take_profit_usd_price: orders_datum.take_profit_usd_price,
      last_pay_lend_time: orders_datum.order_submission_time,
      pool_license: orders_datum.pool_license,
      side: orders_datum.side,
    }

  let position_output =
    Output {
      address: from_verification_key(trader_pkh),
      value: assets.from_asset(
        orders_datum.collateral_asset.policy_id,
        orders_datum.collateral_asset.asset_name,
        orders_datum.collateral_asset_amount - loss_asset_amount,
      )
        |> assets.add(
            orders_datum.strike_collateral_asset.policy_id,
            orders_datum.strike_collateral_asset.asset_name,
            orders_datum.strike_collateral_asset_amount,
          ),
      datum: InlineDatum(positions_datum),
      reference_script: None,
    }

  let pool_output_datum =
    PoolDatum {
      underlying_asset: pool_datum.underlying_asset,
      underlying_asset_amount: pool_datum.underlying_asset_amount + loss_asset_amount,
      underlying_asset_lended_amount: pool_datum.underlying_asset_lended_amount,
      underlying_interest_rate: pool_datum.underlying_interest_rate,
      stable_collateral_asset: pool_datum.stable_collateral_asset,
      max_leverage_factor: pool_datum.max_leverage_factor,
      liquidate_margin: pool_datum.liquidate_margin,
      max_strike_holder_leverage_factor: pool_datum.max_strike_holder_leverage_factor,
      maintain_margin_amount: pool_datum.maintain_margin_amount,
      is_valid_pool_asset: pool_datum.is_valid_pool_asset,
      earnings_per_share: pool_datum.earnings_per_share,
      collateral_earnings_per_share: pool_datum.collateral_earnings_per_share,
      stable_collateral_asset_amount: pool_datum.stable_collateral_asset_amount,
    }

  let pool_output =
    Output {
      address: from_script(pool_script_hash),
      value: pool_input.output.value
        |> assets.add(
            pool_datum.underlying_asset.policy_id,
            pool_datum.underlying_asset.asset_name,
            loss_asset_amount,
          ),
      datum: InlineDatum(pool_output_datum),
      reference_script: None,
    }

  let input_batcher =
    Input {
      output_reference: out_ref,
      output: Output {
        address: from_script(#""),
        value: assets.add(
          assets.zero,
          batcher_license,
          string.to_bytearray(@"1727715600000"),
          1,
        ),
        datum: NoDatum,
        reference_script: None,
      },
    }

  let mint =
    assets.from_asset(
      orders_datum.positions_mint_asset.policy_id,
      orders_datum.positions_mint_asset.asset_name,
      -orders_datum.positions_mint_asset_amount,
    )

  let tx =
    Transaction {
      inputs: [orders_input, pool_input, input_batcher],
      reference_inputs: [],
      outputs: [position_output, pool_output],
      fee: 0,
      mint,
      certificates: [],
      withdrawals: [],
      validity_range: Interval {
        lower_bound: IntervalBound {
          bound_type: Finite(1727453227635),
          is_inclusive: False,
        },
        upper_bound: IntervalBound {
          bound_type: Finite(1727456400000),
          is_inclusive: False,
        },
      },
      extra_signatories: [trader_pkh],
      redeemers: [],
      datums: dict.empty,
      id: #"0000000000000000000000000000000000000000000000000000000000000000",
      votes: [],
      proposal_procedures: [],
      current_treasury_amount: None,
      treasury_donation: None,
    }

  let params =
    OrdersParams {
      batcher_license,
      maximum_deadline_range,
      underlying_asset_policy_id: underlying_asset.policy_id,
      underlying_asset_name: underlying_asset.asset_name,
    }

  let credential = Script(orders_script_hash)

  let redeemer =
    OrdersWithdrawRedeemer {
      indexer: [(0, 0)],
      pool_utxo_index: (1, 1),
      batcher_index: 2,
    }

  orders.orders.withdraw(params, redeemer, credential, tx)
}

test close_loss_short_position() {
  let orders_datum =
    OrdersDatum {
      owner_address_hash: trader_pkh,
      underlying_asset,
      underlying_asset_amount: 10,
      leverage_factor: 10,
      orders_script_hash,
      positions_script_hash,
      positions_mint_asset,
      positions_mint_asset_amount: 1_000_000,
      liquidity_asset: underlying_asset,
      liquidity_asset_amount: 10,
      liquidity_positions_script_hash,
      collateral_asset: stable_collateral_asset,
      collateral_asset_amount: 10_000_000,
      strike_collateral_asset,
      strike_collateral_asset_amount: 10,
      entered_earnings_per_share: 0,
      entered_collateral_earnings_per_share: 0,
      liquidate_usd_price: 100,
      stop_loss_usd_price: 0,
      take_profit_usd_price: 0,
      order_submission_time: 1727453227635,
      entered_at_usd_price: 100,
      order_submission_usd_price: 105,
      pool_license,
      action: ClosePositionOrder,
      side: Short,
    }

  let orders_input =
    Input {
      output_reference: out_ref,
      output: Output {
        address: from_script(orders_script_hash),
        value: from_lovelace(2_000_000)
          |> assets.add(
              orders_datum.positions_mint_asset.policy_id,
              orders_datum.positions_mint_asset.asset_name,
              orders_datum.positions_mint_asset_amount,
            )
          |> assets.add(
              orders_datum.collateral_asset.policy_id,
              orders_datum.collateral_asset.asset_name,
              orders_datum.collateral_asset_amount,
            )
          |> assets.add(
              orders_datum.strike_collateral_asset.policy_id,
              orders_datum.strike_collateral_asset.asset_name,
              orders_datum.strike_collateral_asset_amount,
            ),
        datum: InlineDatum(orders_datum),
        reference_script: None,
      },
    }

  let estimated_loss =
    orders_datum.entered_at_usd_price * orders_datum.positions_mint_asset_amount - orders_datum.order_submission_usd_price * orders_datum.positions_mint_asset_amount

  let formatted_loss_asset_amount =
    format_stable_if_lovelace(orders_datum, -estimated_loss)

  let positions_datum =
    PositionDatum {
      owner_address_hash: orders_datum.owner_address_hash,
      entered_at_usd_price: orders_datum.entered_at_usd_price,
      underlying_asset: orders_datum.underlying_asset,
      leverage_factor: orders_datum.leverage_factor,
      positions_mint_asset: orders_datum.positions_mint_asset,
      positions_mint_asset_amount: orders_datum.positions_mint_asset_amount,
      collateral_asset: orders_datum.collateral_asset,
      collateral_asset_amount: orders_datum.collateral_asset_amount,
      strike_collateral_asset: orders_datum.strike_collateral_asset,
      strike_collateral_asset_amount: orders_datum.strike_collateral_asset_amount,
      liquidate_usd_price: orders_datum.liquidate_usd_price,
      stop_loss_usd_price: orders_datum.stop_loss_usd_price,
      take_profit_usd_price: orders_datum.take_profit_usd_price,
      last_pay_lend_time: orders_datum.order_submission_time,
      pool_license: orders_datum.pool_license,
      side: orders_datum.side,
    }

  let position_output =
    Output {
      address: from_verification_key(trader_pkh),
      value: assets.from_asset(
        orders_datum.collateral_asset.policy_id,
        orders_datum.collateral_asset.asset_name,
        orders_datum.collateral_asset_amount - formatted_loss_asset_amount,
      )
        |> assets.add(
            orders_datum.strike_collateral_asset.policy_id,
            orders_datum.strike_collateral_asset.asset_name,
            orders_datum.strike_collateral_asset_amount,
          ),
      datum: InlineDatum(positions_datum),
      reference_script: None,
    }

  let pool_output_datum =
    PoolDatum {
      underlying_asset: pool_datum.underlying_asset,
      underlying_asset_amount: pool_datum.underlying_asset_amount,
      underlying_asset_lended_amount: pool_datum.underlying_asset_lended_amount,
      underlying_interest_rate: pool_datum.underlying_interest_rate,
      stable_collateral_asset: pool_datum.stable_collateral_asset,
      max_leverage_factor: pool_datum.max_leverage_factor,
      liquidate_margin: pool_datum.liquidate_margin,
      max_strike_holder_leverage_factor: pool_datum.max_strike_holder_leverage_factor,
      maintain_margin_amount: pool_datum.maintain_margin_amount,
      is_valid_pool_asset: pool_datum.is_valid_pool_asset,
      earnings_per_share: pool_datum.earnings_per_share,
      collateral_earnings_per_share: pool_datum.collateral_earnings_per_share,
      stable_collateral_asset_amount: pool_datum.stable_collateral_asset_amount + formatted_loss_asset_amount,
    }

  let pool_output =
    Output {
      address: from_script(pool_script_hash),
      value: pool_input.output.value
        |> assets.add(
            pool_datum.underlying_asset.policy_id,
            pool_datum.underlying_asset.asset_name,
            formatted_loss_asset_amount,
          ),
      datum: InlineDatum(pool_output_datum),
      reference_script: None,
    }

  let input_batcher =
    Input {
      output_reference: out_ref,
      output: Output {
        address: from_script(#""),
        value: assets.add(
          assets.zero,
          batcher_license,
          string.to_bytearray(@"1727715600000"),
          1,
        ),
        datum: NoDatum,
        reference_script: None,
      },
    }

  let mint =
    assets.from_asset(
      orders_datum.positions_mint_asset.policy_id,
      orders_datum.positions_mint_asset.asset_name,
      -orders_datum.positions_mint_asset_amount,
    )

  let tx =
    Transaction {
      inputs: [orders_input, pool_input, input_batcher],
      reference_inputs: [],
      outputs: [position_output, pool_output],
      fee: 0,
      mint,
      certificates: [],
      withdrawals: [],
      validity_range: Interval {
        lower_bound: IntervalBound {
          bound_type: Finite(1727453227635),
          is_inclusive: False,
        },
        upper_bound: IntervalBound {
          bound_type: Finite(1727456400000),
          is_inclusive: False,
        },
      },
      extra_signatories: [trader_pkh],
      redeemers: [],
      datums: dict.empty,
      id: #"0000000000000000000000000000000000000000000000000000000000000000",
      votes: [],
      proposal_procedures: [],
      current_treasury_amount: None,
      treasury_donation: None,
    }

  let params =
    OrdersParams {
      batcher_license,
      maximum_deadline_range,
      underlying_asset_policy_id: underlying_asset.policy_id,
      underlying_asset_name: underlying_asset.asset_name,
    }

  let credential = Script(orders_script_hash)

  let redeemer =
    OrdersWithdrawRedeemer {
      indexer: [(0, 0)],
      pool_utxo_index: (1, 1),
      batcher_index: 2,
    }

  orders.orders.withdraw(params, redeemer, credential, tx)
}
// test liquidate_position() {
//   let orders_datum =
//     OrdersDatum {
//       owner_address_hash: trader_pkh,
//       underlying_asset,
//       underlying_asset_amount: 10,
//       leverage_factor: 10,
//       orders_script_hash,
//       positions_script_hash,
//       positions_mint_asset,
//       positions_mint_asset_amount: 10_000_000,
//       liquidity_asset: underlying_asset,
//       liquidity_asset_amount: 10,
//       liquidity_positions_script_hash,
//       collateral_asset: lovelace_asset,
//       collateral_asset_amount: 1_000_000,
//       strike_collateral_asset,
//       strike_collateral_asset_amount: 10,
//       entered_earnings_per_share: 0,
//       entered_collateral_earnings_per_share: 0,
//       liquidate_usd_price: 100,
//       stop_loss_usd_price: 0,
//       take_profit_usd_price: 0,
//       order_submission_time: 1727453227635,
//       entered_at_usd_price: 100,
//       order_submission_usd_price: 100,
//       pool_license,
//       action: OpenPositionOrder,
//       side: Long,
//     }

//   let orders_input =
//     Input {
//       output_reference: out_ref,
//       output: Output {
//         address: from_script(orders_script_hash),
//         value: from_lovelace(2_000_000)
//           |> assets.add(
//               orders_datum.positions_mint_asset.policy_id,
//               orders_datum.positions_mint_asset.asset_name,
//               orders_datum.positions_mint_asset_amount,
//             )
//           |> assets.add(
//               orders_datum.collateral_asset.policy_id,
//               orders_datum.collateral_asset.asset_name,
//               orders_datum.collateral_asset_amount,
//             )
//           |> assets.add(
//               orders_datum.strike_collateral_asset.policy_id,
//               orders_datum.strike_collateral_asset.asset_name,
//               orders_datum.strike_collateral_asset_amount,
//             ),
//         datum: InlineDatum(orders_datum),
//         reference_script: None,
//       },
//     }

//   let positions_datum =
//     PositionDatum {
//       owner_address_hash: orders_datum.owner_address_hash,
//       entered_at_usd_price: orders_datum.entered_at_usd_price,
//       underlying_asset: orders_datum.underlying_asset,
//       leverage_factor: orders_datum.leverage_factor,
//       positions_mint_asset: orders_datum.positions_mint_asset,
//       positions_mint_asset_amount: orders_datum.positions_mint_asset_amount,
//       collateral_asset: orders_datum.collateral_asset,
//       collateral_asset_amount: orders_datum.collateral_asset_amount,
//       strike_collateral_asset: orders_datum.strike_collateral_asset,
//       strike_collateral_asset_amount: orders_datum.strike_collateral_asset_amount,
//       liquidate_usd_price: orders_datum.liquidate_usd_price,
//       stop_loss_usd_price: orders_datum.stop_loss_usd_price,
//       take_profit_usd_price: orders_datum.take_profit_usd_price,
//       last_pay_lend_time: orders_datum.order_submission_time,
//       pool_license: orders_datum.pool_license,
//       side: orders_datum.side,
//     }

//   let position_output =
//     Output {
//       address: from_script(positions_script_hash),
//       value: from_lovelace(2_000_000)
//         |> assets.add(
//             orders_datum.positions_mint_asset.policy_id,
//             orders_datum.positions_mint_asset.asset_name,
//             orders_datum.positions_mint_asset_amount,
//           )
//         |> assets.add(
//             orders_datum.collateral_asset.policy_id,
//             orders_datum.collateral_asset.asset_name,
//             orders_datum.collateral_asset_amount,
//           )
//         |> assets.add(
//             orders_datum.strike_collateral_asset.policy_id,
//             orders_datum.strike_collateral_asset.asset_name,
//             orders_datum.strike_collateral_asset_amount,
//           ),
//       datum: InlineDatum(positions_datum),
//       reference_script: None,
//     }

//   let lended_amount =
//     orders_datum.positions_mint_asset_amount / orders_datum.leverage_factor

//   let pool_output_datum =
//     PoolDatum {
//       underlying_asset: pool_datum.underlying_asset,
//       underlying_asset_amount: pool_datum.underlying_asset_amount,
//       underlying_asset_lended_amount: pool_datum.underlying_asset_lended_amount + lended_amount,
//       underlying_interest_rate: pool_datum.underlying_interest_rate,
//       stable_collateral_asset: pool_datum.stable_collateral_asset,
//       max_leverage_factor: pool_datum.max_leverage_factor,
//       liquidate_margin: pool_datum.liquidate_margin,
//       max_strike_holder_leverage_factor: pool_datum.max_strike_holder_leverage_factor,
//       maintain_margin_amount: pool_datum.maintain_margin_amount,
//       is_valid_pool_asset: pool_datum.is_valid_pool_asset,
//       earnings_per_share: pool_datum.earnings_per_share,
//       collateral_earnings_per_share: pool_datum.collateral_earnings_per_share,
//       stable_collateral_asset_amount: pool_datum.stable_collateral_asset_amount,
//     }

//   let pool_output =
//     Output {
//       address: from_script(pool_script_hash),
//       value: pool_input.output.value,
//       datum: InlineDatum(pool_output_datum),
//       reference_script: None,
//     }

//   let input_batcher =
//     Input {
//       output_reference: out_ref,
//       output: Output {
//         address: from_script(#""),
//         value: assets.add(
//           assets.zero,
//           batcher_license,
//           string.to_bytearray(@"1727715600000"),
//           1,
//         ),
//         datum: NoDatum,
//         reference_script: None,
//       },
//     }

//   let tx =
//     Transaction {
//       inputs: [orders_input, pool_input, input_batcher],
//       reference_inputs: [],
//       outputs: [position_output, pool_output],
//       fee: 0,
//       mint: assets.zero,
//       certificates: [],
//       withdrawals: [],
//       validity_range: Interval {
//         lower_bound: IntervalBound {
//           bound_type: Finite(1727453227635),
//           is_inclusive: False,
//         },
//         upper_bound: IntervalBound {
//           bound_type: Finite(1727456400000),
//           is_inclusive: False,
//         },
//       },
//       extra_signatories: [trader_pkh],
//       redeemers: [],
//       datums: dict.empty,
//       id: #"0000000000000000000000000000000000000000000000000000000000000000",
//       votes: [],
//       proposal_procedures: [],
//       current_treasury_amount: None,
//       treasury_donation: None,
//     }

//   let params =
//     OrdersParams {
//       batcher_license,
//       maximum_deadline_range,
//       underlying_asset_policy_id: underlying_asset.policy_id,
//       underlying_asset_name: underlying_asset.asset_name,
//     }

//   let credential = Script(orders_script_hash)

//   let redeemer =
//     OrdersWithdrawRedeemer {
//       indexer: [(0, 0)],
//       pool_utxo_index: (1, 1),
//       batcher_index: 2,
//       current_price: 100,
//     }

//   orders.orders.withdraw(params, redeemer, credential, tx)
// }
