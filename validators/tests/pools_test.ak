// use aiken/collection/dict
// use aiken/interval.{Finite, Interval, IntervalBound}
// use cardano/address.{from_script}
// use cardano/assets
// use cardano/transaction.{InlineDatum, Output, OutputReference, Transaction}
// use provide_liquidity_mint
// use tests/constants.{
//   long_position_asset, orders_script_hash, provide_liquidity_policy_id,
//   provide_liquidty_asset_name, collateral_asset, strike_collateral_asset,
//   trader_pkh, underlying_asset,
// }
// use types.{Long, OrdersDatum, ProvideLiquidity, ProvideLiquidityMintParams}

// test test_burn_short_positions_mint() {
//   let validate_pool_ref =
//     OutputReference {
//       transaction_id: #"b4971034feee28d07f157faf99b850f856d8da3494c70b19b521cfe690258e26",
//       output_index: 0,
//     }

//   let orders_datum =
//     OrdersDatum {
//       owner_address_hash: trader_pkh,
//       entered_at_price: 100,
//       underlying_asset,
//       underlying_asset_amount: 5000000,
//       leverage_factor: 2,
//       orders_script_hash,
//       position_script_hash: orders_script_hash,
//       positions_mint_asset: long_position_asset,
//       positions_mint_asset_amount: 10,
//       liquidity_asset: underlying_asset,
//       liquidity_asset_amount: 10,
//       collateral_asset,
//       collateral_asset_amount: 10,
//       strike_collateral_asset,
//       strike_collateral_amount: 10,
//       entered_earnings_per_share: 0,
//       entered_collateral_earnings_per_share: 0,
//       stop_loss_usd_price: 0,
//       take_profit_usd_price: 0,
//       order_submission_time: 1751111000,
//       validate_pool_ref,
//       action: ProvideLiquidity,
//       side: Long,
//     }

//   let mint =
//     assets.from_asset(
//       provide_liquidity_policy_id,
//       provide_liquidty_asset_name,
//       5_000_000,
//     )

//   let orders_output =
//     Output {
//       address: from_script(orders_script_hash),
//       value: mint
//         |> assets.merge(assets.from_lovelace(5_000_000)),
//       datum: InlineDatum(orders_datum),
//       reference_script: None,
//     }

//   let tx =
//     Transaction {
//       inputs: [],
//       reference_inputs: [],
//       outputs: [orders_output],
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
//     ProvideLiquidityMintParams {
//       orders_validator: orders_script_hash,
//       asset_name: provide_liquidty_asset_name,
//       provided_asset_policy_id: underlying_asset.policy_id,
//       provided_asset_name: underlying_asset.asset_name,
//     }
//   let redeemer = 1

//   provide_liquidity_mint.provide_liquidity_mint.mint(
//     params,
//     redeemer,
//     provide_liquidity_policy_id,
//     tx,
//   )
// }
