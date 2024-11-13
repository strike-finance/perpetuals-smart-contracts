// use aiken/collection/dict
// use aiken/interval.{Finite, Interval, IntervalBound}
// use cardano/address.{Script, from_script}
// use cardano/assets.{from_lovelace}
// use cardano/transaction.{InlineDatum, Input, Output, Transaction}
// use pools
// use tests/constants.{
//   admin_pkh, underlying_asset, orders_script_hash, out_ref, pool_asset,
//   pool_asset_name, pool_license, pool_script_hash, stable_asset,
//   trader_pkh,
// }
// use types.{
//   PoolDatum, PoolParams, PoolRedeemer, UpdateInterestRate,
//   UpdateLiquidateMargin, UpdateMaxLeverageFactor,
//   UpdateMaxStrikeHolderLeverageFactor, UpdateParam, UtilizePool,
// }

// const pool_datum =
//   PoolDatum {
//     underlying_asset: underlying_asset,
//     underlying_asset_amount: 100_000_000,
//     underlying_asset_lended_amount: 1_000_000,
//     interest_rate: 2,
//     stable_asset,
//     max_leverage_factor: 10,
//     maintain_margin_amount: 5,
//     max_strike_holder_leverage_factor: 20,
//     maintain_margin_amount: 0,
//     is_valid_pool_asset: pool_asset,
//     earnings_per_share: 0,
//     collateral_earnings_per_share: 0,
//     stable_asset_amount: 100_000_000,
//   }

// const pool_input =
//   Input {
//     output_reference: out_ref,
//     output: Output {
//       address: from_script(pool_script_hash),
//       value: from_lovelace(2_000_000)
//         |> assets.add(pool_license, pool_asset_name, 1)
//         |> assets.add(
//             pool_datum.underlying_asset.policy_id,
//             pool_datum.underlying_asset.asset_name,
//             pool_datum.underlying_asset_amount,
//           )
//         |> assets.add(
//             pool_datum.stable_asset.policy_id,
//             pool_datum.stable_asset.asset_name,
//             pool_datum.stable_asset_amount,
//           ),
//       datum: InlineDatum(pool_datum),
//       reference_script: None,
//     },
//   }

// const stake_cred = Script(orders_script_hash)

// test utilize_pool() {
//   let withdrawals = [Pair(Script(orders_script_hash), 1)]

//   let tx =
//     Transaction {
//       inputs: [pool_input],
//       reference_inputs: [],
//       outputs: [],
//       fee: 0,
//       mint: assets.zero,
//       certificates: [],
//       withdrawals,
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
//     PoolParams {
//       orders_stake_cred: stake_cred,
//       admin_pkh,
//       asset_name: pool_asset_name,
//     }
//   let redeemer =
//     PoolRedeemer {
//       action: UtilizePool,
//       update_param_type: UpdateInterestRate(0),
//     }
//   pools.pools.spend(params, Some(pool_datum), redeemer, out_ref, tx)
// }

// test update_interest_rate() {
//   let updated_pool_datum =
//     PoolDatum {
//       underlying_asset: pool_datum.underlying_asset,
//       underlying_asset_amount: pool_datum.underlying_asset_amount,
//       underlying_asset_lended_amount: pool_datum.underlying_asset_lended_amount,
//       interest_rate: 20,
//       stable_asset: pool_datum.stable_asset,
//       max_leverage_factor: pool_datum.max_leverage_factor,
//       maintain_margin_amount: pool_datum.maintain_margin_amount,
//       max_strike_holder_leverage_factor: pool_datum.max_strike_holder_leverage_factor,
//       maintain_margin_amount: pool_datum.maintain_margin_amount,
//       is_valid_pool_asset: pool_datum.is_valid_pool_asset,
//       earnings_per_share: pool_datum.earnings_per_share,
//       collateral_earnings_per_share: pool_datum.collateral_earnings_per_share,
//       stable_asset_amount: pool_datum.stable_asset_amount,
//     }

//   let output =
//     Output {
//       address: from_script(pool_script_hash),
//       value: from_lovelace(2_000_000)
//         |> assets.add(pool_license, pool_asset_name, 1)
//         |> assets.add(
//             pool_datum.underlying_asset.policy_id,
//             pool_datum.underlying_asset.asset_name,
//             pool_datum.underlying_asset_amount,
//           )
//         |> assets.add(
//             pool_datum.stable_asset.policy_id,
//             pool_datum.stable_asset.asset_name,
//             pool_datum.stable_asset_amount,
//           ),
//       datum: InlineDatum(updated_pool_datum),
//       reference_script: None,
//     }

//   let tx =
//     Transaction {
//       inputs: [pool_input],
//       reference_inputs: [],
//       outputs: [output],
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
//       extra_signatories: [admin_pkh],
//       redeemers: [],
//       datums: dict.empty,
//       id: #"0000000000000000000000000000000000000000000000000000000000000000",
//       votes: [],
//       proposal_procedures: [],
//       current_treasury_amount: None,
//       treasury_donation: None,
//     }

//   let params =
//     PoolParams {
//       orders_stake_cred: stake_cred,
//       admin_pkh,
//       asset_name: pool_asset_name,
//     }
//   let redeemer =
//     PoolRedeemer {
//       action: UpdateParam,
//       update_param_type: UpdateInterestRate(20),
//     }
//   pools.pools.spend(params, Some(pool_datum), redeemer, out_ref, tx)
// }

// test update_margin_requirement() {
//   let updated_pool_datum =
//     PoolDatum {
//       underlying_asset: pool_datum.underlying_asset,
//       underlying_asset_amount: pool_datum.underlying_asset_amount,
//       underlying_asset_lended_amount: pool_datum.underlying_asset_lended_amount,
//       interest_rate: pool_datum.interest_rate,
//       stable_asset: pool_datum.stable_asset,
//       max_leverage_factor: pool_datum.max_leverage_factor,
//       maintain_margin_amount: 30,
//       max_strike_holder_leverage_factor: pool_datum.max_strike_holder_leverage_factor,
//       maintain_margin_amount: pool_datum.maintain_margin_amount,
//       is_valid_pool_asset: pool_datum.is_valid_pool_asset,
//       earnings_per_share: pool_datum.earnings_per_share,
//       collateral_earnings_per_share: pool_datum.collateral_earnings_per_share,
//       stable_asset_amount: pool_datum.stable_asset_amount,
//     }

//   let output =
//     Output {
//       address: from_script(pool_script_hash),
//       value: from_lovelace(2_000_000)
//         |> assets.add(pool_license, pool_asset_name, 1)
//         |> assets.add(
//             pool_datum.underlying_asset.policy_id,
//             pool_datum.underlying_asset.asset_name,
//             pool_datum.underlying_asset_amount,
//           )
//         |> assets.add(
//             pool_datum.stable_asset.policy_id,
//             pool_datum.stable_asset.asset_name,
//             pool_datum.stable_asset_amount,
//           ),
//       datum: InlineDatum(updated_pool_datum),
//       reference_script: None,
//     }

//   let tx =
//     Transaction {
//       inputs: [pool_input],
//       reference_inputs: [],
//       outputs: [output],
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
//       extra_signatories: [admin_pkh],
//       redeemers: [],
//       datums: dict.empty,
//       id: #"0000000000000000000000000000000000000000000000000000000000000000",
//       votes: [],
//       proposal_procedures: [],
//       current_treasury_amount: None,
//       treasury_donation: None,
//     }

//   let params =
//     PoolParams {
//       orders_stake_cred: stake_cred,
//       admin_pkh,
//       asset_name: pool_asset_name,
//     }
//   let redeemer =
//     PoolRedeemer {
//       action: UpdateParam,
//       update_param_type: UpdateLiquidateMargin(30),
//     }
//   pools.pools.spend(params, Some(pool_datum), redeemer, out_ref, tx)
// }

// test update_max_leverage_factor() {
//   let updated_pool_datum =
//     PoolDatum {
//       underlying_asset: pool_datum.underlying_asset,
//       underlying_asset_amount: pool_datum.underlying_asset_amount,
//       underlying_asset_lended_amount: pool_datum.underlying_asset_lended_amount,
//       interest_rate: pool_datum.interest_rate,
//       stable_asset: pool_datum.stable_asset,
//       max_leverage_factor: 30,
//       maintain_margin_amount: pool_datum.maintain_margin_amount,
//       max_strike_holder_leverage_factor: pool_datum.max_strike_holder_leverage_factor,
//       maintain_margin_amount: pool_datum.maintain_margin_amount,
//       is_valid_pool_asset: pool_datum.is_valid_pool_asset,
//       earnings_per_share: pool_datum.earnings_per_share,
//       collateral_earnings_per_share: pool_datum.collateral_earnings_per_share,
//       stable_asset_amount: pool_datum.stable_asset_amount,
//     }

//   let output =
//     Output {
//       address: from_script(pool_script_hash),
//       value: from_lovelace(2_000_000)
//         |> assets.add(pool_license, pool_asset_name, 1)
//         |> assets.add(
//             pool_datum.underlying_asset.policy_id,
//             pool_datum.underlying_asset.asset_name,
//             pool_datum.underlying_asset_amount,
//           )
//         |> assets.add(
//             pool_datum.stable_asset.policy_id,
//             pool_datum.stable_asset.asset_name,
//             pool_datum.stable_asset_amount,
//           ),
//       datum: InlineDatum(updated_pool_datum),
//       reference_script: None,
//     }

//   let tx =
//     Transaction {
//       inputs: [pool_input],
//       reference_inputs: [],
//       outputs: [output],
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
//     PoolParams {
//       orders_stake_cred: stake_cred,
//       admin_pkh,
//       asset_name: pool_asset_name,
//     }
//   let redeemer =
//     PoolRedeemer {
//       action: UpdateParam,
//       update_param_type: UpdateMaxLeverageFactor(30),
//     }
//   pools.pools.spend(params, Some(pool_datum), redeemer, out_ref, tx)
// }

// test update_max_strike_holder_leverage_factor() {
//   let updated_pool_datum =
//     PoolDatum {
//       underlying_asset: pool_datum.underlying_asset,
//       underlying_asset_amount: pool_datum.underlying_asset_amount,
//       underlying_asset_lended_amount: pool_datum.underlying_asset_lended_amount,
//       interest_rate: pool_datum.interest_rate,
//       stable_asset: pool_datum.stable_asset,
//       max_leverage_factor: pool_datum.max_leverage_factor,
//       maintain_margin_amount: pool_datum.maintain_margin_amount,
//       max_strike_holder_leverage_factor: 30,
//       maintain_margin_amount: pool_datum.maintain_margin_amount,
//       is_valid_pool_asset: pool_datum.is_valid_pool_asset,
//       earnings_per_share: pool_datum.earnings_per_share,
//       collateral_earnings_per_share: pool_datum.collateral_earnings_per_share,
//       stable_asset_amount: pool_datum.stable_asset_amount,
//     }

//   let output =
//     Output {
//       address: from_script(pool_script_hash),
//       value: from_lovelace(2_000_000)
//         |> assets.add(pool_license, pool_asset_name, 1)
//         |> assets.add(
//             pool_datum.underlying_asset.policy_id,
//             pool_datum.underlying_asset.asset_name,
//             pool_datum.underlying_asset_amount,
//           )
//         |> assets.add(
//             pool_datum.stable_asset.policy_id,
//             pool_datum.stable_asset.asset_name,
//             pool_datum.stable_asset_amount,
//           ),
//       datum: InlineDatum(updated_pool_datum),
//       reference_script: None,
//     }

//   let tx =
//     Transaction {
//       inputs: [pool_input],
//       reference_inputs: [],
//       outputs: [output],
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
//       extra_signatories: [admin_pkh],
//       redeemers: [],
//       datums: dict.empty,
//       id: #"0000000000000000000000000000000000000000000000000000000000000000",
//       votes: [],
//       proposal_procedures: [],
//       current_treasury_amount: None,
//       treasury_donation: None,
//     }

//   let params =
//     PoolParams {
//       orders_stake_cred: stake_cred,
//       admin_pkh,
//       asset_name: pool_asset_name,
//     }
//   let redeemer =
//     PoolRedeemer {
//       action: UpdateParam,
//       update_param_type: UpdateMaxStrikeHolderLeverageFactor(30),
//     }
//   pools.pools.spend(params, Some(pool_datum), redeemer, out_ref, tx)
// }
