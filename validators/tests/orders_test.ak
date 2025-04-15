// use aiken/collection/dict
// use aiken/interval.{Finite, Interval, IntervalBound}
// use aiken/primitive/string
// use cardano/address.{Script, from_script, from_verification_key}
// use cardano/assets.{from_lovelace}
// use cardano/transaction.{InlineDatum, Input, NoDatum, Output, Transaction}
// use orders
// use tests/constants.{
//   batcher_license, burn_address, maximum_deadline_range, orders_script_hash,
//   out_ref, pool_asset_name, pool_license, pool_script_hash, position_policy_id,
//   stable_asset, strike_collateral_asset, trader_pkh, underlying_asset,
// }
// use types.{
//   Asset, CancelOrder, ClosePositionOrder, LiquidatePositionOrder, Long,
//   LongCloseOrder, OpenPositionOrder, OrderDatum, OrdersParams,
//   OrdersWithdrawRedeemer, PoolDatum, PositionDatum, PositionDatum, Short,
//   ShortCloseOrder,
// }

// const pool_datum =
//   PoolDatum {
//     underlying_asset,
//     underlying_asset_lended_amount: 1_000_000,
//     interest_rate: 2,
//     stable_asset,
//     max_leverage_factor: 10,
//     maintain_margin_amount: 5,
//     max_strike_holder_leverage_factor: 20,
//   }

// const pool_input =
//   Input {
//     output_reference: out_ref,
//     output: Output {
//       address: from_script(pool_script_hash),
//       value: from_lovelace(1_000_000_000_000_000)
//         |> assets.add(pool_license, pool_asset_name, 1)
//         |> assets.add(
//             pool_datum.underlying_asset.policy_id,
//             pool_datum.underlying_asset.asset_name,
//             10_000_000_000,
//           )
//         |> assets.add(
//             pool_datum.stable_asset.policy_id,
//             pool_datum.stable_asset.asset_name,
//             10_000,
//           ),
//       datum: InlineDatum(pool_datum),
//       reference_script: None,
//     },
//   }

// test test_cancel_open_position() {
//   let orders_datum =
//     OrderDatum {
//       action: OpenPositionOrder {
//         position_datum: PositionDatum {
//           owner_pkh: trader_pkh,
//           position_policy_id,
//           leverage_factor: 10,
//           position_asset_amount: 10_000_000,
//           maintain_margin_amount: 100,
//           hourly_usd_borrow_fee: 20,
//           entered_at_usd_price: 100,
//           entered_position_time: 1727453227635,
//           side: Long,
//         },
//       },
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

//   let mint = assets.from_asset(position_policy_id, trader_pkh, -1)

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
//       stable_asset_policy_id: stable_asset.policy_id,
//       stable_asset_name: stable_asset.asset_name,
//       burn_address,
//     }
//   let redeemer = CancelOrder(0)
//   orders.orders.spend(params, Some(orders_datum), redeemer, out_ref, tx)
// }

// test test_cancel_close_position() {
//   let orders_datum =
//     OrderDatum {
//       action: ClosePositionOrder {
//         stop_loss_usd_price: 0,
//         take_profit_usd_price: 0,
//         return_amount: LongCloseOrder {
//           asset_amount: 10_000_000,
//           strike_collateral_amount: 10,
//           pool_asset_amount: -10_000_000,
//         },
//         position_datum: PositionDatum {
//           owner_pkh: trader_pkh,
//           position_policy_id,
//           leverage_factor: 10,
//           hourly_usd_borrow_fee: 100,
//           entered_at_usd_price: 100,
//           position_asset_amount: 10_000_000,
//           maintain_margin_amount: 10,
//           side: Long,
//           entered_position_time: 100,
//         },
//       },
//     }

//   expect ClosePositionOrder {
//     stop_loss_usd_price,
//     take_profit_usd_price,
//     position_datum: PositionDatum {
//       owner_pkh,
//       position_policy_id,
//       leverage_factor,
//       hourly_usd_borrow_fee,
//       entered_at_usd_price,
//       position_asset_amount,
//       maintain_margin_amount,
//       side,
//       entered_position_time,
//     },
//     ..
//   } = orders_datum.action

//   let orders_input =
//     Input {
//       output_reference: out_ref,
//       output: Output {
//         address: from_script(orders_script_hash),
//         value: from_lovelace(2_000_000)
//           |> assets.add(position_policy_id, trader_pkh, 1)
//           |> assets.add(
//               underlying_asset.policy_id,
//               underlying_asset.asset_name,
//               100,
//             )
//           |> assets.add(
//               strike_collateral_asset.policy_id,
//               strike_collateral_asset.asset_name,
//               100,
//             ),
//         datum: InlineDatum(orders_datum),
//         reference_script: None,
//       },
//     }

//   let positions_datum =
//     PositionDatum {
//       owner_pkh,
//       position_policy_id,
//       entered_at_usd_price,
//       leverage_factor,
//       position_asset_amount,
//       maintain_margin_amount,
//       stop_loss_usd_price,
//       take_profit_usd_price,
//       entered_position_time,
//       hourly_usd_borrow_fee,
//       collateral_asset: underlying_asset,
//       side,
//     }

//   let position_output =
//     Output {
//       address: from_script(position_policy_id),
//       value: from_lovelace(2_000_000)
//         |> assets.add(position_policy_id, trader_pkh, 1)
//         |> assets.add(underlying_asset.policy_id, underlying_asset.asset_name, 100)
//         |> assets.add(
//             strike_collateral_asset.policy_id,
//             strike_collateral_asset.asset_name,
//             100,
//           ),
//       datum: InlineDatum(positions_datum),
//       reference_script: None,
//     }

//   let tx =
//     Transaction {
//       inputs: [orders_input],
//       reference_inputs: [],
//       outputs: [position_output],
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
//       maximum_deadline_range: 1000,
//       underlying_asset_policy_id: underlying_asset.policy_id,
//       underlying_asset_name: underlying_asset.asset_name,
//       stable_asset_policy_id: stable_asset.policy_id,
//       stable_asset_name: stable_asset.asset_name,
//       burn_address,
//     }
//   let redeemer = CancelOrder(0)
//   orders.orders.spend(params, Some(orders_datum), redeemer, out_ref, tx)
// }

// test test_open_position() {
//   let orders_datum =
//     OrderDatum {
//       action: OpenPositionOrder {
//         position_datum: PositionDatum {
//           owner_pkh: trader_pkh,
//           position_policy_id,
//           leverage_factor: 10,
//           entered_position_time: 1727453227635,
//           entered_at_usd_price: 100,
//           position_asset_amount: 10_000_000,
//           maintain_margin_amount: 100,
//           hourly_usd_borrow_fee: 100,
//           side: Long,
//         },
//       },
//     }

//   expect OpenPositionOrder{position_datum: PositionDatum {
//     owner_pkh,
//     position_policy_id,
//     leverage_factor,
//     entered_position_time,
//     entered_at_usd_price,
//     position_asset_amount,
//     maintain_margin_amount,
//     hourly_usd_borrow_fee,
//     side,
//   }} = orders_datum.action

//   let orders_input =
//     Input {
//       output_reference: out_ref,
//       output: Output {
//         address: from_script(orders_script_hash),
//         value: from_lovelace(2_000_000)
//           |> assets.add(position_policy_id, trader_pkh, 1)
//           |> assets.add(
//               underlying_asset.policy_id,
//               underlying_asset.asset_name,
//               100,
//             )
//           |> assets.add(
//               strike_collateral_asset.policy_id,
//               strike_collateral_asset.asset_name,
//               100,
//             ),
//         datum: InlineDatum(orders_datum),
//         reference_script: None,
//       },
//     }

//   let positions_datum =
//     PositionDatum {
//       owner_pkh,
//       position_policy_id,
//       entered_at_usd_price,
//       leverage_factor,
//       position_asset_amount,
//       maintain_margin_amount,
//       stop_loss_usd_price: 0,
//       take_profit_usd_price: 0,
//       entered_position_time,
//       hourly_usd_borrow_fee,
//       collateral_asset: underlying_asset,
//       side,
//     }

//   let position_output =
//     Output {
//       address: from_script(position_policy_id),
//       value: from_lovelace(2_000_000)
//         |> assets.add(position_policy_id, trader_pkh, 1)
//         |> assets.add(underlying_asset.policy_id, underlying_asset.asset_name, 100)
//         |> assets.add(
//             strike_collateral_asset.policy_id,
//             strike_collateral_asset.asset_name,
//             100,
//           ),
//       datum: InlineDatum(positions_datum),
//       reference_script: None,
//     }

//   let collateral_amount = position_asset_amount / leverage_factor
//   let lended_amount = position_asset_amount - collateral_amount

//   let pool_output_datum =
//     PoolDatum {
//       underlying_asset: pool_datum.underlying_asset,
//       underlying_asset_lended_amount: pool_datum.underlying_asset_lended_amount + lended_amount,
//       interest_rate: pool_datum.interest_rate,
//       stable_asset: pool_datum.stable_asset,
//       max_leverage_factor: pool_datum.max_leverage_factor,
//       max_strike_holder_leverage_factor: pool_datum.max_strike_holder_leverage_factor,
//       maintain_margin_amount: pool_datum.maintain_margin_amount,
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

// test test_close_profit_long_position() {
//   let orders_datum =
//     OrderDatum {
//       action: ClosePositionOrder {
//         stop_loss_usd_price: 0,
//         take_profit_usd_price: 0,
//         return_amount: LongCloseOrder {
//           asset_amount: 10_000_000,
//           strike_collateral_amount: 10,
//           pool_asset_amount: -10_000_000,
//         },
//         position_datum: PositionDatum {
//           owner_pkh: trader_pkh,
//           position_policy_id,
//           leverage_factor: 10,
//           entered_at_usd_price: 100,
//           entered_position_time: 100,
//           position_asset_amount: 10_000_000,
//           maintain_margin_amount: 10,
//           side: Long,
//           hourly_usd_borrow_fee: 100,
//         },
//       },
//     }

//   expect ClosePositionOrder {
//     return_amount,
//     position_datum: PositionDatum {
//       leverage_factor,
//       position_asset_amount,
//       position_policy_id,
//       ..
//     },
//     ..
//   } = orders_datum.action

//   let inital_position_amount = position_asset_amount / leverage_factor

//   expect LongCloseOrder {
//     asset_amount,
//     strike_collateral_amount,
//     pool_asset_amount,
//   } = return_amount

//   let orders_input =
//     Input {
//       output_reference: out_ref,
//       output: Output {
//         address: from_script(orders_script_hash),
//         value: assets.from_asset(position_policy_id, trader_pkh, 1)
//           |> assets.add(
//               underlying_asset.policy_id,
//               underlying_asset.asset_name,
//               inital_position_amount,
//             )
//           |> assets.add(
//               strike_collateral_asset.policy_id,
//               strike_collateral_asset.asset_name,
//               strike_collateral_amount,
//             ),
//         datum: InlineDatum(orders_datum),
//         reference_script: None,
//       },
//     }

//   let trader_output =
//     Output {
//       address: from_verification_key(trader_pkh),
//       value: assets.from_asset(
//         underlying_asset.policy_id,
//         underlying_asset.asset_name,
//         asset_amount,
//       )
//         |> assets.add(
//             strike_collateral_asset.policy_id,
//             strike_collateral_asset.asset_name,
//             strike_collateral_amount,
//           ),
//       datum: NoDatum,
//       reference_script: None,
//     }

//   let pool_output_datum =
//     PoolDatum {
//       underlying_asset: pool_datum.underlying_asset,
//       underlying_asset_lended_amount: pool_datum.underlying_asset_lended_amount,
//       interest_rate: pool_datum.interest_rate,
//       stable_asset: pool_datum.stable_asset,
//       max_leverage_factor: pool_datum.max_leverage_factor,
//       max_strike_holder_leverage_factor: pool_datum.max_strike_holder_leverage_factor,
//       maintain_margin_amount: pool_datum.maintain_margin_amount,
//     }

//   let pool_output =
//     Output {
//       address: from_script(pool_script_hash),
//       value: pool_input.output.value
//         |> assets.add(
//             pool_datum.underlying_asset.policy_id,
//             pool_datum.underlying_asset.asset_name,
//             pool_asset_amount,
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

//   let mint = assets.from_asset(position_policy_id, trader_pkh, -1)

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

// test test_close_profit_short_position() {
//   let orders_datum =
//     OrderDatum {
//       action: ClosePositionOrder {
//         stop_loss_usd_price: 0,
//         take_profit_usd_price: 0,
//         return_amount: ShortCloseOrder {
//           asset_amount: 10_000_000,
//           pool_asset_amount: -10_000_000,
//           pool_stable_amount: 0,
//           stable_amount: 50,
//           strike_collateral_amount: 10,
//         },
//         position_datum: PositionDatum {
//           owner_pkh: trader_pkh,
//           position_policy_id,
//           leverage_factor: 10,
//           hourly_usd_borrow_fee: 100,
//           entered_at_usd_price: 100,
//           position_asset_amount: 10_000_000,
//           maintain_margin_amount: 10,
//           side: Short,
//           entered_position_time: 100,
//         },
//       },
//     }

//   expect ClosePositionOrder {
//     position_datum: PositionDatum { position_policy_id, .. },
//     return_amount,
//     ..
//   } = orders_datum.action

//   expect ShortCloseOrder {
//     asset_amount,
//     pool_asset_amount,
//     stable_amount,
//     strike_collateral_amount,
//     ..
//   } = return_amount

//   let orders_input =
//     Input {
//       output_reference: out_ref,
//       output: Output {
//         address: from_script(orders_script_hash),
//         value: from_lovelace(2_000_000)
//           |> assets.add(position_policy_id, trader_pkh, 1)
//           |> assets.add(
//               stable_asset.policy_id,
//               stable_asset.asset_name,
//               stable_amount,
//             )
//           |> assets.add(
//               strike_collateral_asset.policy_id,
//               strike_collateral_asset.asset_name,
//               strike_collateral_amount,
//             ),
//         datum: InlineDatum(orders_datum),
//         reference_script: None,
//       },
//     }

//   let trader_output =
//     Output {
//       address: from_verification_key(trader_pkh),
//       value: assets.from_asset(
//         stable_asset.policy_id,
//         stable_asset.asset_name,
//         stable_amount,
//       )
//         |> assets.add(
//             strike_collateral_asset.policy_id,
//             strike_collateral_asset.asset_name,
//             strike_collateral_amount,
//           )
//         |> assets.add(
//             pool_datum.underlying_asset.policy_id,
//             pool_datum.underlying_asset.asset_name,
//             asset_amount,
//           ),
//       datum: NoDatum,
//       reference_script: None,
//     }

//   let pool_output_datum =
//     PoolDatum {
//       underlying_asset: pool_datum.underlying_asset,
//       underlying_asset_lended_amount: pool_datum.underlying_asset_lended_amount,
//       interest_rate: pool_datum.interest_rate,
//       stable_asset: pool_datum.stable_asset,
//       max_leverage_factor: pool_datum.max_leverage_factor,
//       max_strike_holder_leverage_factor: pool_datum.max_strike_holder_leverage_factor,
//       maintain_margin_amount: pool_datum.maintain_margin_amount,
//     }

//   let pool_output =
//     Output {
//       address: from_script(pool_script_hash),
//       value: pool_input.output.value
//         |> assets.add(
//             pool_datum.underlying_asset.policy_id,
//             pool_datum.underlying_asset.asset_name,
//             pool_asset_amount,
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

//   let mint = assets.from_asset(position_policy_id, trader_pkh, -1)

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

// test test_close_loss_long_position() {
//   let orders_datum =
//     OrderDatum {
//       action: ClosePositionOrder {
//         stop_loss_usd_price: 0,
//         take_profit_usd_price: 0,
//         return_amount: LongCloseOrder {
//           asset_amount: -5_000_000,
//           strike_collateral_amount: 10,
//           pool_asset_amount: 5_000_000,
//         },
//         position_datum: PositionDatum {
//           owner_pkh: trader_pkh,
//           position_policy_id,
//           leverage_factor: 10,
//           hourly_usd_borrow_fee: 100,
//           entered_at_usd_price: 100,
//           position_asset_amount: 10_000_000,
//           maintain_margin_amount: 10,
//           side: Long,
//           entered_position_time: 100,
//         },
//       },
//     }

//   expect ClosePositionOrder {
//     position_datum: PositionDatum { position_policy_id, .. },
//     return_amount,
//     ..
//   } = orders_datum.action

//   expect LongCloseOrder {
//     asset_amount,
//     strike_collateral_amount,
//     pool_asset_amount,
//   } = return_amount

//   let orders_input =
//     Input {
//       output_reference: out_ref,
//       output: Output {
//         address: from_script(orders_script_hash),
//         value: from_lovelace(2_000_000)
//           |> assets.add(position_policy_id, trader_pkh, -1)
//           |> assets.add(
//               pool_datum.underlying_asset.policy_id,
//               pool_datum.underlying_asset.asset_name,
//               pool_asset_amount,
//             )
//           |> assets.add(
//               strike_collateral_asset.policy_id,
//               strike_collateral_asset.asset_name,
//               strike_collateral_amount,
//             ),
//         datum: InlineDatum(orders_datum),
//         reference_script: None,
//       },
//     }

//   let position_output =
//     Output {
//       address: from_verification_key(trader_pkh),
//       value: assets.from_asset(
//         pool_datum.underlying_asset.policy_id,
//         pool_datum.underlying_asset.asset_name,
//         asset_amount,
//       )
//         |> assets.add(
//             strike_collateral_asset.policy_id,
//             strike_collateral_asset.asset_name,
//             strike_collateral_amount,
//           ),
//       datum: NoDatum,
//       reference_script: None,
//     }

//   let pool_output_datum =
//     PoolDatum {
//       underlying_asset: pool_datum.underlying_asset,
//       underlying_asset_lended_amount: pool_datum.underlying_asset_lended_amount,
//       interest_rate: pool_datum.interest_rate,
//       stable_asset: pool_datum.stable_asset,
//       max_leverage_factor: pool_datum.max_leverage_factor,
//       max_strike_holder_leverage_factor: pool_datum.max_strike_holder_leverage_factor,
//       maintain_margin_amount: pool_datum.maintain_margin_amount,
//     }

//   let pool_output =
//     Output {
//       address: from_script(pool_script_hash),
//       value: pool_input.output.value
//         |> assets.add(
//             pool_datum.underlying_asset.policy_id,
//             pool_datum.underlying_asset.asset_name,
//             pool_asset_amount,
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

//   let mint = assets.from_asset(position_policy_id, trader_pkh, -1)

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

// test test_close_loss_short_position() {
//   let orders_datum =
//     OrderDatum {
//       action: ClosePositionOrder {
//         stop_loss_usd_price: 0,
//         take_profit_usd_price: 0,
//         return_amount: ShortCloseOrder {
//           asset_amount: 0,
//           pool_asset_amount: 0,
//           pool_stable_amount: 50,
//           stable_amount: -50,
//           strike_collateral_amount: 10,
//         },
//         position_datum: PositionDatum {
//           owner_pkh: trader_pkh,
//           position_policy_id,
//           leverage_factor: 10,
//           hourly_usd_borrow_fee: 100,
//           entered_at_usd_price: 100,
//           position_asset_amount: 10_000_000,
//           maintain_margin_amount: 10,
//           side: Short,
//           entered_position_time: 100,
//         },
//       },
//     }

//   let orders_input =
//     Input {
//       output_reference: out_ref,
//       output: Output {
//         address: from_script(orders_script_hash),
//         value: from_lovelace(2_000_000)
//           |> assets.add(position_policy_id, trader_pkh, -1)
//           |> assets.add(
//               pool_datum.stable_asset.policy_id,
//               pool_datum.stable_asset.asset_name,
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

//   expect ClosePositionOrder {
//     position_datum: PositionDatum { position_policy_id, .. },
//     return_amount,
//     ..
//   } = orders_datum.action

//   expect ShortCloseOrder {
//     pool_stable_amount,
//     stable_amount,
//     strike_collateral_amount,
//     ..
//   } = return_amount

//   let position_output =
//     Output {
//       address: from_verification_key(trader_pkh),
//       value: assets.from_asset(
//         pool_datum.stable_asset.policy_id,
//         pool_datum.stable_asset.asset_name,
//         stable_amount,
//       )
//         |> assets.add(
//             strike_collateral_asset.policy_id,
//             strike_collateral_asset.asset_name,
//             strike_collateral_amount,
//           ),
//       datum: NoDatum,
//       reference_script: None,
//     }

//   let pool_output_datum =
//     PoolDatum {
//       underlying_asset: pool_datum.underlying_asset,
//       underlying_asset_lended_amount: pool_datum.underlying_asset_lended_amount,
//       interest_rate: pool_datum.interest_rate,
//       stable_asset: pool_datum.stable_asset,
//       max_leverage_factor: pool_datum.max_leverage_factor,
//       maintain_margin_amount: pool_datum.maintain_margin_amount,
//       max_strike_holder_leverage_factor: pool_datum.max_strike_holder_leverage_factor,
//     }

//   let pool_output =
//     Output {
//       address: from_script(pool_script_hash),
//       value: pool_input.output.value
//         |> assets.add(
//             pool_datum.stable_asset.policy_id,
//             pool_datum.stable_asset.asset_name,
//             pool_stable_amount,
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

//   let mint = assets.from_asset(position_policy_id, trader_pkh, -1)

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
//       stable_asset_policy_id: pool_datum.stable_asset.policy_id,
//       stable_asset_name: pool_datum.stable_asset.asset_name,
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

// test test_liquidate_long_position() {
//   let orders_datum =
//     OrderDatum {
//       action: LiquidatePositionOrder {
//         owner_pkh: trader_pkh,
//         position_policy_id,
//         side: Long,
//         position_asset_amount: 10_000_000,
//         leverage_factor: 10,
//       },
//     }

//   expect LiquidatePositionOrder {
//     position_policy_id,
//     position_asset_amount,
//     leverage_factor,
//     ..
//   } = orders_datum.action

//   let orders_input =
//     Input {
//       output_reference: out_ref,
//       output: Output {
//         address: from_script(orders_script_hash),
//         value: assets.from_asset(
//           pool_datum.underlying_asset.policy_id,
//           pool_datum.underlying_asset.asset_name,
//           position_asset_amount / leverage_factor,
//         )
//           |> assets.add(
//               strike_collateral_asset.policy_id,
//               strike_collateral_asset.asset_name,
//               10,
//             ),
//         datum: InlineDatum(orders_datum),
//         reference_script: None,
//       },
//     }

//   let lended_amount: Int =
//     position_asset_amount - position_asset_amount / leverage_factor

//   let pool_output_datum =
//     PoolDatum {
//       underlying_asset: pool_datum.underlying_asset,
//       underlying_asset_lended_amount: pool_datum.underlying_asset_lended_amount - lended_amount,
//       interest_rate: pool_datum.interest_rate,
//       stable_asset: pool_datum.stable_asset,
//       max_leverage_factor: pool_datum.max_leverage_factor,
//       max_strike_holder_leverage_factor: pool_datum.max_strike_holder_leverage_factor,
//       maintain_margin_amount: pool_datum.maintain_margin_amount,
//     }

//   let pool_output =
//     Output {
//       address: from_script(pool_script_hash),
//       value: pool_input.output.value
//         |> assets.add(
//             pool_datum.underlying_asset.policy_id,
//             pool_datum.underlying_asset.asset_name,
//             position_asset_amount / leverage_factor,
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
//         10,
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

//   let mint = assets.from_asset(position_policy_id, trader_pkh, -1)

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
//       stable_asset_policy_id: pool_datum.stable_asset.policy_id,
//       stable_asset_name: pool_datum.stable_asset.asset_name,
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

// test test_liquidate_short_position() {
//   let orders_datum =
//     OrderDatum {
//       action: LiquidatePositionOrder {
//         owner_pkh: trader_pkh,
//         position_policy_id,
//         side: Short,
//         position_asset_amount: 10_000_000,
//         leverage_factor: 10,
//       },
//     }

//   expect LiquidatePositionOrder {
//     position_policy_id,
//     position_asset_amount,
//     leverage_factor,
//     ..
//   } = orders_datum.action

//   let orders_input =
//     Input {
//       output_reference: out_ref,
//       output: Output {
//         address: from_script(orders_script_hash),
//         value: from_lovelace(2_000_000)
//           |> assets.add(position_policy_id, trader_pkh, -1)
//           |> assets.add(
//               pool_datum.stable_asset.policy_id,
//               pool_datum.stable_asset.asset_name,
//               1_000,
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

//   let lended_amount: Int =
//     position_asset_amount - position_asset_amount / leverage_factor

//   let pool_output_datum =
//     PoolDatum {
//       underlying_asset: pool_datum.underlying_asset,
//       underlying_asset_lended_amount: pool_datum.underlying_asset_lended_amount - lended_amount,
//       interest_rate: pool_datum.interest_rate,
//       stable_asset: pool_datum.stable_asset,
//       max_leverage_factor: pool_datum.max_leverage_factor,
//       maintain_margin_amount: pool_datum.maintain_margin_amount,
//       max_strike_holder_leverage_factor: pool_datum.max_strike_holder_leverage_factor,
//     }

//   let pool_output =
//     Output {
//       address: from_script(pool_script_hash),
//       value: pool_input.output.value
//         |> assets.add(
//             pool_datum.stable_asset.policy_id,
//             pool_datum.stable_asset.asset_name,
//             1_000,
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

//   let mint = assets.from_asset(position_policy_id, trader_pkh, -1)

//   let burn_output =
//     Output {
//       address: from_script(burn_address),
//       value: assets.from_asset(
//         strike_collateral_asset.policy_id,
//         strike_collateral_asset.asset_name,
//         10,
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
//       stable_asset_policy_id: pool_datum.stable_asset.policy_id,
//       stable_asset_name: pool_datum.stable_asset.asset_name,
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
