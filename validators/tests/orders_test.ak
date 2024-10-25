use aiken/collection/dict
use aiken/interval.{Finite, Interval, IntervalBound}
use cardano/address.{from_script}
use cardano/assets.{from_lovelace}
use cardano/transaction.{InlineDatum, Input, Output, Transaction}
use orders
use tests/constants.{
  batcher_license, liquidity_positions_script_hash, lovelace_asset,
  orders_script_hash, out_ref, pool_license, positions_mint_asset,
  strike_collateral_asset, trader_pkh, underlying_asset,
}
use types.{
  Asset, CancelOrders, ClosePositionOrder, Long, OpenPositionOrder, OrdersDatum,
  OrdersParams, PositionDatum,
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
// test cancel_provide_liquidity() {
//   let orders_datum =
//     OrdersDatum {
//       owner_address_hash: trader_pkh,
//       underlying_asset,
//       underlying_asset_amount: 10,
//       leverage_factor: 10,
//       orders_script_hash,
//       positions_script_hash: orders_script_hash,
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
//       action: ClosePositionOrder,
//       side: Long,
//     }

//   let orders_input =
//     Input {
//       output_reference: out_ref,
//       output: Output {
//         address: from_script(orders_script_hash),
//         value: from_lovelace(2_000_000)
//           |> assets.add(pool_license, "", 1),
//         datum: InlineDatum(orders_datum),
//         reference_script: None,
//       },
//     }

//   let mint =
//     assets.from_asset(
//       orders_datum.positions_mint_asset.policy_id,
//       orders_datum.positions_mint_asset.asset_name,
//       -orders_datum.positions_mint_asset_amount,
//     )

//   let tx =
//     Transaction {
//       inputs: [orders_input],
//       reference_inputs: [],
//       outputs: [],
//       fee: 0,
//       mint,
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
//       maximum_deadline_range: 1000,
//       underlying_asset_policy_id: underlying_asset.policy_id,
//       underlying_asset_name: underlying_asset.asset_name,
//     }
//   let redeemer = CancelOrders
//   orders.orders.spend(params, Some(orders_datum), redeemer, out_ref, tx)
// }

// test cancel_withdraw_liquidity() {
//   let orders_datum =
//     OrdersDatum {
//       owner_address_hash: trader_pkh,
//       underlying_asset,
//       underlying_asset_amount: 10,
//       leverage_factor: 10,
//       orders_script_hash,
//       positions_script_hash: orders_script_hash,
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
//       action: ClosePositionOrder,
//       side: Long,
//     }

//   let orders_input =
//     Input {
//       output_reference: out_ref,
//       output: Output {
//         address: from_script(orders_script_hash),
//         value: from_lovelace(2_000_000)
//           |> assets.add(pool_license, "", 1),
//         datum: InlineDatum(orders_datum),
//         reference_script: None,
//       },
//     }

//   let mint =
//     assets.from_asset(
//       orders_datum.positions_mint_asset.policy_id,
//       orders_datum.positions_mint_asset.asset_name,
//       -orders_datum.positions_mint_asset_amount,
//     )

//   let tx =
//     Transaction {
//       inputs: [orders_input],
//       reference_inputs: [],
//       outputs: [],
//       fee: 0,
//       mint,
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
//       maximum_deadline_range: 1000,
//       underlying_asset_policy_id: underlying_asset.policy_id,
//       underlying_asset_name: underlying_asset.asset_name,
//     }
//   let redeemer = CancelOrders
//   orders.orders.spend(params, Some(orders_datum), redeemer, out_ref, tx)
// }
