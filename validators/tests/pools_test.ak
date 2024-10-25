// use aiken/collection/dict
// use aiken/interval.{Finite, Interval, IntervalBound}
// use cardano/address.{from_script}
// use cardano/assets
// use cardano/transaction.{InlineDatum, Output, OutputReference, Transaction}
// use provide_liquidity_mint
// use tests/constants.{
//   lovelace_asset, orders_script_hash, pool_asset, provide_liquidity_policy_id,
//   provide_liquidty_asset_name, stable_collateral_asset, strike_collateral_asset,
//   trader_pkh, underlying_asset,
// }
// use types.{Long, PoolDatum}

// const pool_ref_datum =
//   PoolDatum {
//     underlying_asset: lovelace_asset,
//     underlying_asset_amount: 100_000_000,
//     underlying_asset_lended_amount: 1_000_000,
//     underlying_interest_rate: 2,
//     stable_collateral_asset,
//     max_leverage_factor: 10,
//     liquidate_margin: 5,
//     max_strike_holder_leverage_factor: 20,
//     maintain_margin_amount: 0,
//     is_valid_pool_asset: pool_asset,
//     earnings_per_share: 0,
//     collateral_earnings_per_share: 0,
//     stable_collateral_asset_amount: 100_000_000,
//   }

// const pool_ref_input =
//   Input {
//     output_reference: pool_license,
//     output: Output {
//       address: from_script(#""),
//       value: from_lovelace(2_000_000),
//       datum: InlineDatum(pool_ref_datum),
//       reference_script: None,
//     },
//   }

test utilize_pool() {
  True
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
  //       underlying_asset_policy_id: underlying_asset.policy_id,
  //       underlying_asset_name: underlying_asset.asset_name,
  //     }
  //   let redeemer = 1

  //   provide_liquidity_mint.provide_liquidity_mint.mint(
  //     params,
  //     redeemer,
  //     provide_liquidity_policy_id,
  //     tx,
  //   )
}
