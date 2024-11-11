use aiken/collection/dict
use aiken/interval.{Finite, Interval, IntervalBound}
use aiken/primitive/string
use cardano/address.{Script, from_script, from_verification_key}
use cardano/assets.{from_lovelace}
use cardano/transaction.{InlineDatum, Input, NoDatum, Output, Transaction}
use orders
use tests/constants.{
  batcher_license, burn_address, maximum_deadline_range, orders_script_hash,
  out_ref, pool_asset, pool_asset_name, pool_license, pool_script_hash,
  position_hash, positions_mint_asset, positions_script_hash, stable_asset,
  strike_collateral_asset, trader_pkh, underlying_asset,
}
use types.{
  Asset, CancelOrders, ClosePositionOrder, LiquidatePositionOrder, Long,
  LongCloseOrder, OpenPositionOrder, OrderDatum, OrdersParams,
  OrdersWithdrawRedeemer, PoolDatum, PositionDatum, Short,
}
use utils.{divide}

const pool_datum =
  PoolDatum {
    underlying_asset,
    underlying_asset_amount: 1_000_000_000_000_000,
    underlying_asset_lended_amount: 1_000_000,
    underlying_interest_rate: 2,
    stable_asset,
    max_leverage_factor: 10,
    margin_requirement: 5,
    max_strike_holder_leverage_factor: 20,
    maintain_margin_amount: 0,
    is_valid_pool_asset: pool_asset,
    earnings_per_share: 0,
    collateral_earnings_per_share: 0,
    stable_asset_amount: 100_000_000,
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
            pool_datum.stable_asset.policy_id,
            pool_datum.stable_asset.asset_name,
            pool_datum.stable_asset_amount,
          ),
      datum: InlineDatum(pool_datum),
      reference_script: None,
    },
  }

test cancel_open_position_valid() {
  let orders_datum =
    OrderDatum {
      action: OpenPositionOrder {
        owner_address_hash: trader_pkh,
        position_hash,
        leverage_factor: 10,
        position_asset_amount: 10_000_000,
        margin_requirement: 100,
        hourly_usd_borrow_fee: 20,
        order_submission_usd_price: 100,
        order_submission_time: 1727453227635,
        side: Long,
      },
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

  let mint = assets.from_asset(position_hash, trader_pkh, -1)

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
      stable_asset_policy_id: stable_asset.policy_id,
      stable_asset_name: stable_asset.asset_name,
      burn_address,
    }
  let redeemer = CancelOrders(0)
  orders.orders.spend(params, Some(orders_datum), redeemer, out_ref, tx)
}

test cancel_close_position_valid() {
  let orders_datum =
    OrderDatum {
      action: ClosePositionOrder {
        owner_address_hash: trader_pkh,
        position_hash,
        leverage_factor: 10,
        order_submission_usd_price: 100,
        hourly_usd_borrow_fee: 100,
        entered_at_usd_price: 100,
        stop_loss_usd_price: 0,
        take_profit_usd_price: 0,
        position_asset_amount: 10_000_000,
        margin_requirement: 10,
        side: Long,
        entered_position_time: 100,
        return_amount: LongCloseOrder { asset_amount: 100 },
      },
    }
  expect ClosePositionOrder {
    owner_address_hash,
    position_hash,
    leverage_factor,
    hourly_usd_borrow_fee,
    entered_at_usd_price,
    stop_loss_usd_price,
    take_profit_usd_price,
    position_asset_amount,
    margin_requirement,
    side,
    entered_position_time,
    ..
  } = orders_datum.action

  let orders_input =
    Input {
      output_reference: out_ref,
      output: Output {
        address: from_script(orders_script_hash),
        value: from_lovelace(2_000_000)
          |> assets.add(position_hash, trader_pkh, 1)
          |> assets.add(
              underlying_asset.policy_id,
              underlying_asset.asset_name,
              100,
            )
          |> assets.add(
              strike_collateral_asset.policy_id,
              strike_collateral_asset.asset_name,
              100,
            ),
        datum: InlineDatum(orders_datum),
        reference_script: None,
      },
    }

  let positions_datum =
    PositionDatum {
      owner_address_hash,
      position_hash,
      entered_at_usd_price,
      leverage_factor,
      position_asset_amount,
      margin_requirement,
      stop_loss_usd_price,
      take_profit_usd_price,
      entered_position_time,
      hourly_usd_borrow_fee,
      collateral_asset: underlying_asset,
      side,
    }

  let position_output =
    Output {
      address: from_script(position_hash),
      value: from_lovelace(2_000_000)
        |> assets.add(position_hash, trader_pkh, 1)
        |> assets.add(underlying_asset.policy_id, underlying_asset.asset_name, 100)
        |> assets.add(
            strike_collateral_asset.policy_id,
            strike_collateral_asset.asset_name,
            100,
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
      stable_asset_policy_id: stable_asset.policy_id,
      stable_asset_name: stable_asset.asset_name,
      burn_address,
    }
  let redeemer = CancelOrders(0)
  orders.orders.spend(params, Some(orders_datum), redeemer, out_ref, tx)
}

test open_position() {
  let orders_datum =
    OrderDatum {
      action: OpenPositionOrder {
        owner_address_hash: trader_pkh,
        position_hash,
        leverage_factor: 10,
        order_submission_time: 1727453227635,
        order_submission_usd_price: 100,
        position_asset_amount: 10_000_000,
        margin_requirement: 100,
        hourly_usd_borrow_fee: 100,
        side: Long,
      },
    }

  expect OpenPositionOrder {
    owner_address_hash,
    position_hash,
    leverage_factor,
    order_submission_time,
    order_submission_usd_price,
    position_asset_amount,
    margin_requirement,
    hourly_usd_borrow_fee,
    side,
  } = orders_datum.action

  let orders_input =
    Input {
      output_reference: out_ref,
      output: Output {
        address: from_script(orders_script_hash),
        value: from_lovelace(2_000_000)
          |> assets.add(position_hash, trader_pkh, 1)
          |> assets.add(
              underlying_asset.policy_id,
              underlying_asset.asset_name,
              100,
            )
          |> assets.add(
              strike_collateral_asset.policy_id,
              strike_collateral_asset.asset_name,
              100,
            ),
        datum: InlineDatum(orders_datum),
        reference_script: None,
      },
    }

  let positions_datum =
    PositionDatum {
      owner_address_hash,
      position_hash,
      entered_at_usd_price: order_submission_usd_price,
      leverage_factor,
      position_asset_amount,
      margin_requirement,
      stop_loss_usd_price: 0,
      take_profit_usd_price: 0,
      entered_position_time: order_submission_time,
      hourly_usd_borrow_fee,
      collateral_asset: underlying_asset,
      side,
    }

  let position_output =
    Output {
      address: from_script(position_hash),
      value: from_lovelace(2_000_000)
        |> assets.add(position_hash, trader_pkh, 1)
        |> assets.add(underlying_asset.policy_id, underlying_asset.asset_name, 100)
        |> assets.add(
            strike_collateral_asset.policy_id,
            strike_collateral_asset.asset_name,
            100,
          ),
      datum: InlineDatum(positions_datum),
      reference_script: None,
    }

  let lended_amount = position_asset_amount / leverage_factor

  let pool_output_datum =
    PoolDatum {
      underlying_asset: pool_datum.underlying_asset,
      underlying_asset_amount: pool_datum.underlying_asset_amount,
      underlying_asset_lended_amount: pool_datum.underlying_asset_lended_amount + lended_amount,
      underlying_interest_rate: pool_datum.underlying_interest_rate,
      stable_asset: pool_datum.stable_asset,
      max_leverage_factor: pool_datum.max_leverage_factor,
      margin_requirement: pool_datum.margin_requirement,
      max_strike_holder_leverage_factor: pool_datum.max_strike_holder_leverage_factor,
      maintain_margin_amount: pool_datum.maintain_margin_amount,
      is_valid_pool_asset: pool_datum.is_valid_pool_asset,
      earnings_per_share: pool_datum.earnings_per_share,
      collateral_earnings_per_share: pool_datum.collateral_earnings_per_share,
      stable_asset_amount: pool_datum.stable_asset_amount,
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
      stable_asset_policy_id: stable_asset.policy_id,
      stable_asset_name: stable_asset.asset_name,
      burn_address,
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
// test close_profit_long_position() {
//   let orders_datum =
//     OrderDatum {
//       action: ClosePositionOrder {
//         owner_address_hash: trader_pkh,
//         position_hash,
//         leverage_factor: 10,
//         order_submission_usd_price: 100,
//         hourly_usd_borrow_fee: 100,
//         entered_at_usd_price: 100,
//         stop_loss_usd_price: 0,
//         take_profit_usd_price: 0,
//         position_asset_amount: 10_000_000,
//         margin_requirement: 10,
//         side: Long,
//         entered_position_time: 100,
//         return_amount: LongCloseOrder { asset_amount: 1_000_000 },
//       },
//     }

//   expect ClosePositionOrder { position_hash, return_amount, .. } =
//     orders_datum.action

//   let orders_input =
//     Input {
//       output_reference: out_ref,
//       output: Output {
//         address: from_script(orders_script_hash),
//         value: from_lovelace(2_000_000)
//           |> assets.add(position_hash, trader_pkh, 1)
//           |> assets.add(
//               underlying_asset.policy_id,
//               underlying_asset.asset_name,
//               100,
//             )
//           |> assets.add(
//               strike_collateral_asset.policy_id,
//               strike_collateral_asset.asset_name,
//               10,
//             ),
//         datum: InlineDatum(orders_datum),
//         reference_script: None,
//       },
//     }

//   expect LongCloseOrder { asset_amount } = return_amount

//   let trader_output =
//     Output {
//       address: from_verification_key(trader_pkh),
//       value: from_lovelace(2_000_000)
//         |> assets.add(
//             underlying_asset.policy_id,
//             underlying_asset.asset_name,
//             100 + asset_amount,
//           )
//         |> assets.add(
//             strike_collateral_asset.policy_id,
//             strike_collateral_asset.asset_name,
//             10,
//           ),
//       datum: NoDatum,
//       reference_script: None,
//     }

//   let pool_output_datum =
//     PoolDatum {
//       underlying_asset: pool_datum.underlying_asset,
//       underlying_asset_amount: pool_datum.underlying_asset_amount - asset_amount,
//       underlying_asset_lended_amount: pool_datum.underlying_asset_lended_amount,
//       underlying_interest_rate: pool_datum.underlying_interest_rate,
//       stable_asset: pool_datum.stable_asset,
//       max_leverage_factor: pool_datum.max_leverage_factor,
//       margin_requirement: pool_datum.margin_requirement,
//       max_strike_holder_leverage_factor: pool_datum.max_strike_holder_leverage_factor,
//       maintain_margin_amount: pool_datum.maintain_margin_amount,
//       is_valid_pool_asset: pool_datum.is_valid_pool_asset,
//       earnings_per_share: pool_datum.earnings_per_share,
//       collateral_earnings_per_share: pool_datum.collateral_earnings_per_share,
//       stable_asset_amount: pool_datum.stable_asset_amount,
//     }

//   let pool_output =
//     Output {
//       address: from_script(pool_script_hash),
//       value: pool_input.output.value
//         |> assets.add(
//             pool_datum.underlying_asset.policy_id,
//             pool_datum.underlying_asset.asset_name,
//             -asset_amount,
//           ),
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

//   let mint = assets.from_asset(position_hash, trader_pkh, -1)

//   let tx =
//     Transaction {
//       inputs: [orders_input, pool_input, input_batcher],
//       reference_inputs: [],
//       outputs: [trader_output, pool_output],
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
//       maximum_deadline_range,
//       underlying_asset_policy_id: underlying_asset.policy_id,
//       underlying_asset_name: underlying_asset.asset_name,
//       stable_asset_policy_id: stable_asset.policy_id,
//       stable_asset_name: stable_asset.asset_name,
//       burn_address,
//     }

//   let credential = Script(orders_script_hash)

//   let redeemer =
//     OrdersWithdrawRedeemer {
//       indexer: [(0, 0)],
//       pool_utxo_index: (1, 1),
//       batcher_index: 2,
//     }

//   orders.orders.withdraw(params, redeemer, credential, tx)
// }
// test close_profit_short_position() {
//   let orders_datum =
//     OrderDatum {
//       action: ClosePositionOrder {
//         underlying_asset,
//         owner_address_hash: trader_pkh,
//         positions_script_hash,
//         leverage_factor: 10,
//         order_submission_usd_price: 60,
//         liquidate_usd_price: 100,
//         entered_at_usd_price: 70,
//         stop_loss_usd_price: 0,
//         take_profit_usd_price: 0,
//         entered_position_time: 1727453227635,
//         positions_mint_asset,
//         positions_mint_asset_amount: 10_000_000,
//         collateral_asset: stable_asset,
//         collateral_asset_amount: 1_000_000,
//         strike_collateral_asset,
//         strike_asset_amount: 10,
//         side: Short,
//       },
//     }

//   expect ClosePositionOrder {
//     underlying_asset,
//     order_submission_usd_price,
//     entered_at_usd_price,
//     positions_mint_asset,
//     positions_mint_asset_amount,
//     collateral_asset,
//     collateral_asset_amount,
//     strike_collateral_asset,
//     strike_asset_amount,
//     ..
//   } = orders_datum.action

//   let orders_input =
//     Input {
//       output_reference: out_ref,
//       output: Output {
//         address: from_script(orders_script_hash),
//         value: from_lovelace(2_000_000)
//           |> assets.add(
//               positions_mint_asset.policy_id,
//               positions_mint_asset.asset_name,
//               positions_mint_asset_amount,
//             )
//           |> assets.add(
//               collateral_asset.policy_id,
//               collateral_asset.asset_name,
//               collateral_asset_amount,
//             )
//           |> assets.add(
//               strike_collateral_asset.policy_id,
//               strike_collateral_asset.asset_name,
//               strike_asset_amount,
//             ),
//         datum: InlineDatum(orders_datum),
//         reference_script: None,
//       },
//     }

//   let estimated_profit =
//     entered_at_usd_price * positions_mint_asset_amount - order_submission_usd_price * positions_mint_asset_amount
//   let gain_asset_amount = divide(estimated_profit, order_submission_usd_price)

//   let trader_output =
//     Output {
//       address: from_verification_key(trader_pkh),
//       value: assets.from_asset(
//         collateral_asset.policy_id,
//         collateral_asset.asset_name,
//         collateral_asset_amount,
//       )
//         |> assets.add(
//             strike_collateral_asset.policy_id,
//             strike_collateral_asset.asset_name,
//             strike_asset_amount,
//           )
//         |> assets.add(
//             pool_datum.underlying_asset.policy_id,
//             pool_datum.underlying_asset.asset_name,
//             gain_asset_amount,
//           ),
//       datum: NoDatum,
//       reference_script: None,
//     }

//   let pool_output_datum =
//     PoolDatum {
//       underlying_asset: pool_datum.underlying_asset,
//       underlying_asset_amount: pool_datum.underlying_asset_amount - gain_asset_amount,
//       underlying_asset_lended_amount: pool_datum.underlying_asset_lended_amount,
//       underlying_interest_rate: pool_datum.underlying_interest_rate,
//       stable_asset: pool_datum.stable_asset,
//       max_leverage_factor: pool_datum.max_leverage_factor,
//       margin_requirement: pool_datum.margin_requirement,
//       max_strike_holder_leverage_factor: pool_datum.max_strike_holder_leverage_factor,
//       maintain_margin_amount: pool_datum.maintain_margin_amount,
//       is_valid_pool_asset: pool_datum.is_valid_pool_asset,
//       earnings_per_share: pool_datum.earnings_per_share,
//       collateral_earnings_per_share: pool_datum.collateral_earnings_per_share,
//       stable_asset_amount: pool_datum.stable_asset_amount,
//     }

//   let pool_output =
//     Output {
//       address: from_script(pool_script_hash),
//       value: pool_input.output.value
//         |> assets.add(
//             pool_datum.underlying_asset.policy_id,
//             pool_datum.underlying_asset.asset_name,
//             gain_asset_amount,
//           ),
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

//   let mint =
//     assets.from_asset(
//       positions_mint_asset.policy_id,
//       positions_mint_asset.asset_name,
//       -positions_mint_asset_amount,
//     )

//   let tx =
//     Transaction {
//       inputs: [orders_input, pool_input, input_batcher],
//       reference_inputs: [],
//       outputs: [trader_output, pool_output],
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
//       maximum_deadline_range,
//       underlying_asset_policy_id: underlying_asset.policy_id,
//       underlying_asset_name: underlying_asset.asset_name,
//       burn_address,
//     }

//   let credential = Script(orders_script_hash)

//   let redeemer =
//     OrdersWithdrawRedeemer {
//       indexer: [(0, 0)],
//       pool_utxo_index: (1, 1),
//       batcher_index: 2,
//     }

//   orders.orders.withdraw(params, redeemer, credential, tx)
// }

// test close_loss_long_position() {
//   let orders_datum =
//     OrderDatum {
//       action: ClosePositionOrder {
//         owner_address_hash: trader_pkh,
//         underlying_asset,
//         leverage_factor: 10,
//         positions_script_hash,
//         positions_mint_asset,
//         positions_mint_asset_amount: 10_000_000,
//         collateral_asset: underlying_asset,
//         collateral_asset_amount: 10_000_000,
//         strike_collateral_asset,
//         strike_asset_amount: 10,
//         liquidate_usd_price: 100,
//         stop_loss_usd_price: 0,
//         take_profit_usd_price: 0,
//         entered_position_time: 1727453227635,
//         entered_at_usd_price: 100,
//         order_submission_usd_price: 90,
//         side: Long,
//       },
//     }

//   expect ClosePositionOrder {
//     owner_address_hash,
//     underlying_asset,
//     leverage_factor,
//     positions_script_hash,
//     positions_mint_asset,
//     positions_mint_asset_amount,
//     collateral_asset,
//     collateral_asset_amount,
//     strike_collateral_asset,
//     strike_asset_amount,
//     liquidate_usd_price,
//     stop_loss_usd_price,
//     take_profit_usd_price,
//     entered_position_time,
//     side,
//     order_submission_usd_price,
//     entered_at_usd_price,
//   } = orders_datum.action

//   let orders_input =
//     Input {
//       output_reference: out_ref,
//       output: Output {
//         address: from_script(orders_script_hash),
//         value: from_lovelace(2_000_000)
//           |> assets.add(
//               positions_mint_asset.policy_id,
//               positions_mint_asset.asset_name,
//               positions_mint_asset_amount,
//             )
//           |> assets.add(
//               collateral_asset.policy_id,
//               collateral_asset.asset_name,
//               collateral_asset_amount,
//             )
//           |> assets.add(
//               strike_collateral_asset.policy_id,
//               strike_collateral_asset.asset_name,
//               strike_asset_amount,
//             ),
//         datum: InlineDatum(orders_datum),
//         reference_script: None,
//       },
//     }

//   let estimated_profit =
//     order_submission_usd_price * positions_mint_asset_amount - entered_at_usd_price * positions_mint_asset_amount

//   let loss_asset_amount = divide(-estimated_profit, order_submission_usd_price)

//   let positions_datum =
//     PositionDatum {
//       owner_address_hash,
//       entered_at_usd_price,
//       underlying_asset,
//       leverage_factor,
//       positions_script_hash,
//       positions_mint_asset,
//       positions_mint_asset_amount,
//       collateral_asset,
//       collateral_asset_amount,
//       strike_collateral_asset,
//       strike_asset_amount,
//       liquidate_usd_price,
//       stop_loss_usd_price,
//       take_profit_usd_price,
//       entered_position_time,
//       side,
//     }

//   let position_output =
//     Output {
//       address: from_verification_key(trader_pkh),
//       value: assets.from_asset(
//         collateral_asset.policy_id,
//         collateral_asset.asset_name,
//         collateral_asset_amount - loss_asset_amount,
//       )
//         |> assets.add(
//             strike_collateral_asset.policy_id,
//             strike_collateral_asset.asset_name,
//             strike_asset_amount,
//           ),
//       datum: InlineDatum(positions_datum),
//       reference_script: None,
//     }

//   let pool_output_datum =
//     PoolDatum {
//       underlying_asset: pool_datum.underlying_asset,
//       underlying_asset_amount: pool_datum.underlying_asset_amount + loss_asset_amount,
//       underlying_asset_lended_amount: pool_datum.underlying_asset_lended_amount,
//       underlying_interest_rate: pool_datum.underlying_interest_rate,
//       stable_asset: pool_datum.stable_asset,
//       max_leverage_factor: pool_datum.max_leverage_factor,
//       margin_requirement: pool_datum.margin_requirement,
//       max_strike_holder_leverage_factor: pool_datum.max_strike_holder_leverage_factor,
//       maintain_margin_amount: pool_datum.maintain_margin_amount,
//       is_valid_pool_asset: pool_datum.is_valid_pool_asset,
//       earnings_per_share: pool_datum.earnings_per_share,
//       collateral_earnings_per_share: pool_datum.collateral_earnings_per_share,
//       stable_asset_amount: pool_datum.stable_asset_amount,
//     }

//   let pool_output =
//     Output {
//       address: from_script(pool_script_hash),
//       value: pool_input.output.value
//         |> assets.add(
//             pool_datum.underlying_asset.policy_id,
//             pool_datum.underlying_asset.asset_name,
//             loss_asset_amount,
//           ),
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

//   let mint =
//     assets.from_asset(
//       positions_mint_asset.policy_id,
//       positions_mint_asset.asset_name,
//       -positions_mint_asset_amount,
//     )

//   let tx =
//     Transaction {
//       inputs: [orders_input, pool_input, input_batcher],
//       reference_inputs: [],
//       outputs: [position_output, pool_output],
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
//       maximum_deadline_range,
//       underlying_asset_policy_id: underlying_asset.policy_id,
//       underlying_asset_name: underlying_asset.asset_name,
//       burn_address,
//     }

//   let credential = Script(orders_script_hash)

//   let redeemer =
//     OrdersWithdrawRedeemer {
//       indexer: [(0, 0)],
//       pool_utxo_index: (1, 1),
//       batcher_index: 2,
//     }

//   orders.orders.withdraw(params, redeemer, credential, tx)
// }

// test close_loss_short_position() {
//   let orders_datum =
//     OrderDatum {
//       action: ClosePositionOrder {
//         owner_address_hash: trader_pkh,
//         underlying_asset,
//         leverage_factor: 10,
//         positions_script_hash,
//         positions_mint_asset,
//         positions_mint_asset_amount: 1_000_000,
//         collateral_asset: underlying_asset,
//         collateral_asset_amount: 10_000_000,
//         strike_collateral_asset,
//         strike_asset_amount: 10,
//         liquidate_usd_price: 100,
//         stop_loss_usd_price: 0,
//         take_profit_usd_price: 0,
//         entered_position_time: 1727453227635,
//         entered_at_usd_price: 100,
//         order_submission_usd_price: 105,
//         side: Short,
//       },
//     }

//   expect ClosePositionOrder {
//     owner_address_hash,
//     underlying_asset,
//     leverage_factor,
//     positions_script_hash,
//     positions_mint_asset,
//     positions_mint_asset_amount,
//     collateral_asset,
//     collateral_asset_amount,
//     strike_collateral_asset,
//     strike_asset_amount,
//     liquidate_usd_price,
//     stop_loss_usd_price,
//     take_profit_usd_price,
//     entered_position_time,
//     side,
//     order_submission_usd_price,
//     entered_at_usd_price,
//   } = orders_datum.action

//   let orders_input =
//     Input {
//       output_reference: out_ref,
//       output: Output {
//         address: from_script(orders_script_hash),
//         value: from_lovelace(2_000_000)
//           |> assets.add(
//               positions_mint_asset.policy_id,
//               positions_mint_asset.asset_name,
//               positions_mint_asset_amount,
//             )
//           |> assets.add(
//               collateral_asset.policy_id,
//               collateral_asset.asset_name,
//               collateral_asset_amount,
//             )
//           |> assets.add(
//               strike_collateral_asset.policy_id,
//               strike_collateral_asset.asset_name,
//               strike_asset_amount,
//             ),
//         datum: InlineDatum(orders_datum),
//         reference_script: None,
//       },
//     }

//   let estimated_loss =
//     entered_at_usd_price * positions_mint_asset_amount - order_submission_usd_price * positions_mint_asset_amount

//   let formatted_loss_asset_amount =
//     format_stable_if_lovelace(underlying_asset, -estimated_loss)

//   let positions_datum =
//     PositionDatum {
//       owner_address_hash,
//       entered_at_usd_price,
//       underlying_asset,
//       leverage_factor,
//       positions_script_hash,
//       positions_mint_asset,
//       positions_mint_asset_amount,
//       collateral_asset,
//       collateral_asset_amount,
//       strike_collateral_asset,
//       strike_asset_amount,
//       liquidate_usd_price,
//       stop_loss_usd_price,
//       take_profit_usd_price,
//       entered_position_time,
//       side,
//     }

//   let position_output =
//     Output {
//       address: from_verification_key(trader_pkh),
//       value: assets.from_asset(
//         collateral_asset.policy_id,
//         collateral_asset.asset_name,
//         collateral_asset_amount - formatted_loss_asset_amount,
//       )
//         |> assets.add(
//             strike_collateral_asset.policy_id,
//             strike_collateral_asset.asset_name,
//             strike_asset_amount,
//           ),
//       datum: InlineDatum(positions_datum),
//       reference_script: None,
//     }

//   let pool_output_datum =
//     PoolDatum {
//       underlying_asset: pool_datum.underlying_asset,
//       underlying_asset_amount: pool_datum.underlying_asset_amount,
//       underlying_asset_lended_amount: pool_datum.underlying_asset_lended_amount,
//       underlying_interest_rate: pool_datum.underlying_interest_rate,
//       stable_asset: pool_datum.stable_asset,
//       max_leverage_factor: pool_datum.max_leverage_factor,
//       margin_requirement: pool_datum.margin_requirement,
//       max_strike_holder_leverage_factor: pool_datum.max_strike_holder_leverage_factor,
//       maintain_margin_amount: pool_datum.maintain_margin_amount,
//       is_valid_pool_asset: pool_datum.is_valid_pool_asset,
//       earnings_per_share: pool_datum.earnings_per_share,
//       collateral_earnings_per_share: pool_datum.collateral_earnings_per_share,
//       stable_asset_amount: pool_datum.stable_asset_amount + formatted_loss_asset_amount,
//     }

//   let pool_output =
//     Output {
//       address: from_script(pool_script_hash),
//       value: pool_input.output.value
//         |> assets.add(
//             pool_datum.underlying_asset.policy_id,
//             pool_datum.underlying_asset.asset_name,
//             formatted_loss_asset_amount,
//           ),
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

//   let mint =
//     assets.from_asset(
//       positions_mint_asset.policy_id,
//       positions_mint_asset.asset_name,
//       -positions_mint_asset_amount,
//     )

//   let tx =
//     Transaction {
//       inputs: [orders_input, pool_input, input_batcher],
//       reference_inputs: [],
//       outputs: [position_output, pool_output],
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
//       maximum_deadline_range,
//       underlying_asset_policy_id: underlying_asset.policy_id,
//       underlying_asset_name: underlying_asset.asset_name,
//       burn_address,
//     }

//   let credential = Script(orders_script_hash)

//   let redeemer =
//     OrdersWithdrawRedeemer {
//       indexer: [(0, 0)],
//       pool_utxo_index: (1, 1),
//       batcher_index: 2,
//     }

//   orders.orders.withdraw(params, redeemer, credential, tx)
// }

// test liquidate_long_position() {
//   let orders_datum =
//     OrderDatum {
//       action: LiquidatePositionOrder {
//         collateral_asset: underlying_asset,
//         collateral_asset_amount: 10_000_000,
//         positions_mint_asset,
//         positions_mint_asset_amount: 1_000_000,
//         strike_collateral_asset,
//         strike_asset_amount: 10,
//         side: Long,
//       },
//     }

//   expect LiquidatePositionOrder {
//     collateral_asset,
//     collateral_asset_amount,
//     positions_mint_asset,
//     positions_mint_asset_amount,
//     strike_collateral_asset,
//     strike_asset_amount,
//     ..
//   } = orders_datum.action

//   let orders_input =
//     Input {
//       output_reference: out_ref,
//       output: Output {
//         address: from_script(orders_script_hash),
//         value: from_lovelace(2_000_000)
//           |> assets.add(
//               positions_mint_asset.policy_id,
//               positions_mint_asset.asset_name,
//               positions_mint_asset_amount,
//             )
//           |> assets.add(
//               collateral_asset.policy_id,
//               collateral_asset.asset_name,
//               collateral_asset_amount,
//             )
//           |> assets.add(
//               strike_collateral_asset.policy_id,
//               strike_collateral_asset.asset_name,
//               strike_asset_amount,
//             ),
//         datum: InlineDatum(orders_datum),
//         reference_script: None,
//       },
//     }

//   let pool_output_datum =
//     PoolDatum {
//       underlying_asset: pool_datum.underlying_asset,
//       underlying_asset_amount: pool_datum.underlying_asset_amount + collateral_asset_amount,
//       underlying_asset_lended_amount: pool_datum.underlying_asset_lended_amount,
//       underlying_interest_rate: pool_datum.underlying_interest_rate,
//       stable_asset: pool_datum.stable_asset,
//       max_leverage_factor: pool_datum.max_leverage_factor,
//       margin_requirement: pool_datum.margin_requirement,
//       max_strike_holder_leverage_factor: pool_datum.max_strike_holder_leverage_factor,
//       maintain_margin_amount: pool_datum.maintain_margin_amount,
//       is_valid_pool_asset: pool_datum.is_valid_pool_asset,
//       earnings_per_share: pool_datum.earnings_per_share,
//       collateral_earnings_per_share: pool_datum.collateral_earnings_per_share,
//       stable_asset_amount: pool_datum.stable_asset_amount,
//     }

//   let pool_output =
//     Output {
//       address: from_script(pool_script_hash),
//       value: pool_input.output.value
//         |> assets.add(
//             pool_datum.underlying_asset.policy_id,
//             pool_datum.underlying_asset.asset_name,
//             collateral_asset_amount,
//           ),
//       datum: InlineDatum(pool_output_datum),
//       reference_script: None,
//     }

//   let burn_output =
//     Output {
//       address: from_script(burn_address),
//       value: assets.from_asset(
//         strike_collateral_asset.policy_id,
//         strike_collateral_asset.asset_name,
//         strike_asset_amount,
//       ),
//       datum: NoDatum,
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

//   let mint =
//     assets.from_asset(
//       positions_mint_asset.policy_id,
//       positions_mint_asset.asset_name,
//       -positions_mint_asset_amount,
//     )

//   let tx =
//     Transaction {
//       inputs: [orders_input, pool_input, input_batcher],
//       reference_inputs: [],
//       outputs: [burn_output, pool_output],
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
//       maximum_deadline_range,
//       underlying_asset_policy_id: underlying_asset.policy_id,
//       underlying_asset_name: underlying_asset.asset_name,
//       burn_address,
//     }

//   let credential = Script(orders_script_hash)

//   let redeemer =
//     OrdersWithdrawRedeemer {
//       indexer: [(0, 0)],
//       pool_utxo_index: (1, 1),
//       batcher_index: 2,
//     }

//   orders.orders.withdraw(params, redeemer, credential, tx)
// }

// test liquidate_short_position() {
//   let orders_datum =
//     OrderDatum {
//       action: LiquidatePositionOrder {
//         collateral_asset: underlying_asset,
//         collateral_asset_amount: 10_000_000,
//         positions_mint_asset,
//         positions_mint_asset_amount: 1_000_000,
//         strike_collateral_asset,
//         strike_asset_amount: 10,
//         side: Short,
//       },
//     }

//   expect LiquidatePositionOrder {
//     collateral_asset,
//     collateral_asset_amount,
//     positions_mint_asset,
//     positions_mint_asset_amount,
//     strike_collateral_asset,
//     strike_asset_amount,
//     ..
//   } = orders_datum.action

//   let orders_input =
//     Input {
//       output_reference: out_ref,
//       output: Output {
//         address: from_script(orders_script_hash),
//         value: from_lovelace(2_000_000)
//           |> assets.add(
//               positions_mint_asset.policy_id,
//               positions_mint_asset.asset_name,
//               positions_mint_asset_amount,
//             )
//           |> assets.add(
//               collateral_asset.policy_id,
//               collateral_asset.asset_name,
//               collateral_asset_amount,
//             )
//           |> assets.add(
//               strike_collateral_asset.policy_id,
//               strike_collateral_asset.asset_name,
//               strike_asset_amount,
//             ),
//         datum: InlineDatum(orders_datum),
//         reference_script: None,
//       },
//     }

//   let pool_output_datum =
//     PoolDatum {
//       underlying_asset: pool_datum.underlying_asset,
//       underlying_asset_amount: pool_datum.underlying_asset_amount,
//       underlying_asset_lended_amount: pool_datum.underlying_asset_lended_amount,
//       underlying_interest_rate: pool_datum.underlying_interest_rate,
//       stable_asset: pool_datum.stable_asset,
//       max_leverage_factor: pool_datum.max_leverage_factor,
//       margin_requirement: pool_datum.margin_requirement,
//       max_strike_holder_leverage_factor: pool_datum.max_strike_holder_leverage_factor,
//       maintain_margin_amount: pool_datum.maintain_margin_amount,
//       is_valid_pool_asset: pool_datum.is_valid_pool_asset,
//       earnings_per_share: pool_datum.earnings_per_share,
//       collateral_earnings_per_share: pool_datum.collateral_earnings_per_share,
//       stable_asset_amount: pool_datum.stable_asset_amount + collateral_asset_amount,
//     }

//   let pool_output =
//     Output {
//       address: from_script(pool_script_hash),
//       value: pool_input.output.value
//         |> assets.add(
//             pool_datum.underlying_asset.policy_id,
//             pool_datum.underlying_asset.asset_name,
//             collateral_asset_amount,
//           ),
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

//   let mint =
//     assets.from_asset(
//       positions_mint_asset.policy_id,
//       positions_mint_asset.asset_name,
//       -positions_mint_asset_amount,
//     )

//   let burn_output =
//     Output {
//       address: from_script(burn_address),
//       value: assets.from_asset(
//         strike_collateral_asset.policy_id,
//         strike_collateral_asset.asset_name,
//         strike_asset_amount,
//       ),
//       datum: NoDatum,
//       reference_script: None,
//     }

//   let tx =
//     Transaction {
//       inputs: [orders_input, pool_input, input_batcher],
//       reference_inputs: [],
//       outputs: [burn_output, pool_output],
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
//       maximum_deadline_range,
//       underlying_asset_policy_id: underlying_asset.policy_id,
//       underlying_asset_name: underlying_asset.asset_name,
//       burn_address,
//     }

//   let credential = Script(orders_script_hash)

//   let redeemer =
//     OrdersWithdrawRedeemer {
//       indexer: [(0, 0)],
//       pool_utxo_index: (1, 1),
//       batcher_index: 2,
//     }

//   orders.orders.withdraw(params, redeemer, credential, tx)
// }
