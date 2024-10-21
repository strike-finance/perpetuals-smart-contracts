use aiken/collection/dict
use aiken/interval.{Finite, Interval, IntervalBound}
use cardano/address.{from_script}
use cardano/assets.{from_lovelace}
use cardano/transaction.{
  InlineDatum, Input, Output, OutputReference, Transaction,
}
use positions
use tests/constants.{
  admin_pkh, enter_position_policy_id, liquidity_positions_script_hash,
  lovelace_asset, orders_script_hash, pool_asset, positions_mint_asset,
  stable_collateral_asset, strike_collateral_asset, trader_pkh, underlying_asset,
}
use types.{
  Asset, BurnPosition, Long, MintPosition, OpenPositionOrder, OrdersDatum,
  PoolDatum, PositionsParams, Short,
}

test test_enter_long_positions_mint() {
  let validate_pool_ref =
    OutputReference {
      transaction_id: #"b4971034feee28d07f157faf99b850f856d8da3494c70b19b521cfe690258e26",
      output_index: 0,
    }

  let pool_ref_datum =
    PoolDatum {
      underlying_asset: lovelace_asset,
      underlying_asset_amount: 0,
      underlying_asset_lended_amount: 0,
      underlying_interest_rate: 0,
      stable_collateral_asset,
      max_leverage_factor: 10,
      liquidate_margin: 5,
      max_strike_holder_leverage_factor: 20,
      maintain_margin_amount: 0,
      is_valid_pool_asset: pool_asset,
      earnings_per_share: 0,
      collateral_earnings_per_share: 0,
    }

  let pool_ref_input =
    Input {
      output_reference: validate_pool_ref,
      output: Output {
        address: from_script(#""),
        value: from_lovelace(2_000_000),
        datum: InlineDatum(pool_ref_datum),
        reference_script: None,
      },
    }

  let mint = assets.from_asset(enter_position_policy_id, trader_pkh, 10_000_000)

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
      order_submission_usd_price: 100,
      validate_pool_ref,
      action: OpenPositionOrder,
      side: Long,
    }

  //2_000_000 batcher fee
  let pos_out =
    Output {
      address: from_script(orders_script_hash),
      value: mint
        |> assets.merge(assets.from_lovelace(2_000_000))
        |> assets.add(
            lovelace_asset.policy_id,
            lovelace_asset.asset_name,
            1_000_000,
          )
        |> assets.add(
            strike_collateral_asset.policy_id,
            strike_collateral_asset.asset_name,
            10,
          ),
      datum: InlineDatum(orders_datum),
      reference_script: None,
    }

  let tx =
    Transaction {
      inputs: [],
      reference_inputs: [pool_ref_input],
      outputs: [pos_out],
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
      extra_signatories: [admin_pkh],
      redeemers: [],
      datums: dict.empty,
      id: #"0000000000000000000000000000000000000000000000000000000000000000",
      votes: [],
      proposal_procedures: [],
      current_treasury_amount: None,
      treasury_donation: None,
    }
  let params = PositionsParams { orders_script_hash, validate_pool_ref }
  let redeemer = MintPosition(100)
  positions.positions.mint(params, redeemer, enter_position_policy_id, tx)
}

test test_enter_short_positions_mint() {
  let validate_pool_ref =
    OutputReference {
      transaction_id: #"b4971034feee28d07f157faf99b850f856d8da3494c70b19b521cfe690258e26",
      output_index: 0,
    }

  let pool_ref_datum =
    PoolDatum {
      underlying_asset,
      underlying_asset_amount: 0,
      underlying_asset_lended_amount: 0,
      underlying_interest_rate: 0,
      stable_collateral_asset,
      max_leverage_factor: 5,
      max_strike_holder_leverage_factor: 10,
      maintain_margin_amount: 0,
      is_valid_pool_asset: pool_asset,
      earnings_per_share: 0,
      collateral_earnings_per_share: 0,
      liquidate_margin: 0,
    }

  let pool_ref_input =
    Input {
      output_reference: validate_pool_ref,
      output: Output {
        address: from_script(#""),
        value: assets.from_lovelace(2_000_000),
        datum: InlineDatum(pool_ref_datum),
        reference_script: None,
      },
    }

  let orders_datum =
    OrdersDatum {
      owner_address_hash: trader_pkh,
      underlying_asset,
      underlying_asset_amount: 10,
      leverage_factor: 5,
      orders_script_hash,
      positions_script_hash: orders_script_hash,
      positions_mint_asset,
      positions_mint_asset_amount: 1000,
      liquidity_asset: underlying_asset,
      liquidity_asset_amount: 10,
      liquidity_positions_script_hash,
      collateral_asset: stable_collateral_asset,
      collateral_asset_amount: 200,
      strike_collateral_asset,
      strike_collateral_asset_amount: 10,
      entered_earnings_per_share: 0,
      entered_collateral_earnings_per_share: 0,
      liquidate_usd_price: 100,
      stop_loss_usd_price: 0,
      take_profit_usd_price: 0,
      order_submission_time: 1727453227635,
      order_submission_usd_price: 1,
      validate_pool_ref,
      action: OpenPositionOrder,
      side: Short,
    }

  let mint = assets.from_asset(enter_position_policy_id, trader_pkh, 1000)

  let pos_out =
    Output {
      address: from_script(orders_script_hash),
      value: mint
        |> assets.merge(assets.from_lovelace(2_000_000))
        |> assets.add(
            stable_collateral_asset.policy_id,
            stable_collateral_asset.asset_name,
            200,
          )
        |> assets.add(
            strike_collateral_asset.policy_id,
            strike_collateral_asset.asset_name,
            10,
          ),
      datum: InlineDatum(orders_datum),
      reference_script: None,
    }

  let tx =
    Transaction {
      inputs: [],
      reference_inputs: [pool_ref_input],
      outputs: [pos_out],
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
      extra_signatories: [admin_pkh],
      redeemers: [],
      datums: dict.empty,
      id: #"0000000000000000000000000000000000000000000000000000000000000000",
      votes: [],
      proposal_procedures: [],
      current_treasury_amount: None,
      treasury_donation: None,
    }
  let params = PositionsParams { orders_script_hash, validate_pool_ref }
  let redeemer = MintPosition(1)
  positions.positions.mint(params, redeemer, enter_position_policy_id, tx)
}

test test_burn_positions_mint() {
  let validate_pool_ref =
    OutputReference {
      transaction_id: #"b4971034feee28d07f157faf99b850f856d8da3494c70b19b521cfe690258e26",
      output_index: 0,
    }

  let mint = assets.from_asset(enter_position_policy_id, trader_pkh, -5_000_000)

  let tx =
    Transaction {
      inputs: [],
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
      extra_signatories: [admin_pkh],
      redeemers: [],
      datums: dict.empty,
      id: #"0000000000000000000000000000000000000000000000000000000000000000",
      votes: [],
      proposal_procedures: [],
      current_treasury_amount: None,
      treasury_donation: None,
    }
  let params = PositionsParams { orders_script_hash, validate_pool_ref }
  let redeemer = BurnPosition(5_000_000, trader_pkh)
  positions.positions.mint(params, redeemer, enter_position_policy_id, tx)
}
