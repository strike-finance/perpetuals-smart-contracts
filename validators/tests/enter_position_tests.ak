use aiken/collection/dict
use aiken/interval.{Finite, Interval, IntervalBound}
use cardano/address.{from_script}
use cardano/assets.{from_lovelace}
use cardano/transaction.{
  InlineDatum, Input, Output, OutputReference, Transaction,
}
use enter_position_mint
use tests/constants.{
  admin_pkh, collateral_asset, enter_position_policy_id, long_asset_name,
  long_position_asset, orders_script_hash, pool_asset, short_asset_name,
  strike_collateral_asset, trader_pkh, underlying_asset,
}
use types.{
  Asset, BurnLong, BurnShort, EnterPositionParams, Long, MintLong, MintShort,
  OrdersDatum, PoolDatum, ProcessOpenPositionOrder,
}

test test_enter_long_positions_mint() {
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
      collateral_asset,
      max_leverage_factor: 5,
      liquidate_margin: 2,
      max_strike_holder_leverage_factor: 10,
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

  let mint =
    assets.from_asset(enter_position_policy_id, long_asset_name, 5_000_000)

  let orders_datum =
    OrdersDatum {
      owner_address_hash: trader_pkh,
      entered_at_price: 100,
      underlying_asset,
      underlying_asset_amount: 10,
      leverage_factor: 2,
      orders_script_hash,
      positions_validator_hash: orders_script_hash,
      positions_asset: long_position_asset,
      positions_asset_amount: 10,
      liquidity_asset: underlying_asset,
      liquidity_asset_amount: 10,
      collateral_asset,
      collateral_asset_amount: 10,
      strike_collateral_asset,
      strike_collateral_amount: 10,
      entered_earnings_per_share: 0,
      entered_collateral_earnings_per_share: 0,
      liquidate_usd_price: 0,
      stop_loss_usd_price: 0,
      take_profit_usd_price: 0,
      order_submission_time: 1751111000,
      order_submission_usd_price: 100,
      validate_pool_ref,
      action: ProcessOpenPositionOrder,
      side: Long,
    }

  let pos_out =
    Output {
      address: from_script(orders_script_hash),
      value: mint
        |> assets.merge(assets.from_lovelace(2_500_000)),
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
  let params =
    EnterPositionParams {
      orders_script_hash,
      long_asset_name,
      short_asset_name,
      validate_pool_ref,
      admin_pkh,
    }
  let redeemer = MintLong(100)
  enter_position_mint.enter_position_mint.mint(
    params,
    redeemer,
    enter_position_policy_id,
    tx,
  )
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
      collateral_asset,
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

  let mint = assets.from_asset(enter_position_policy_id, short_asset_name, 20)

  let orders_datum =
    OrdersDatum {
      owner_address_hash: trader_pkh,
      entered_at_price: 1,
      underlying_asset,
      underlying_asset_amount: 10,
      leverage_factor: 2,
      orders_script_hash,
      positions_validator_hash: orders_script_hash,
      positions_asset: long_position_asset,
      positions_asset_amount: 10,
      liquidity_asset: underlying_asset,
      liquidity_asset_amount: 10,
      collateral_asset,
      collateral_asset_amount: 10,
      strike_collateral_asset,
      strike_collateral_amount: 10,
      entered_earnings_per_share: 0,
      entered_collateral_earnings_per_share: 0,
      liquidate_usd_price: 0,
      stop_loss_usd_price: 0,
      take_profit_usd_price: 0,
      order_submission_time: 1751111000,
      order_submission_usd_price: 100,
      validate_pool_ref,
      action: ProcessOpenPositionOrder,
      side: Long,
    }

  let pos_out =
    Output {
      address: from_script(orders_script_hash),
      value: mint
        |> assets.merge(assets.from_lovelace(2_500_000))
        |> assets.add(
            collateral_asset.policy_id,
            collateral_asset.asset_name,
            1000000000,
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
  let params =
    EnterPositionParams {
      orders_script_hash,
      long_asset_name,
      short_asset_name,
      validate_pool_ref,
      admin_pkh,
    }
  let redeemer = MintShort(1)
  enter_position_mint.enter_position_mint.mint(
    params,
    redeemer,
    enter_position_policy_id,
    tx,
  )
}

test test_burn_long_positions_mint() {
  let validate_pool_ref =
    OutputReference {
      transaction_id: #"b4971034feee28d07f157faf99b850f856d8da3494c70b19b521cfe690258e26",
      output_index: 0,
    }

  let mint =
    assets.from_asset(enter_position_policy_id, long_asset_name, -5_000_000)

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
  let params =
    EnterPositionParams {
      orders_script_hash,
      long_asset_name,
      short_asset_name,
      validate_pool_ref,
      admin_pkh,
    }
  let redeemer = BurnLong(1)
  enter_position_mint.enter_position_mint.mint(
    params,
    redeemer,
    enter_position_policy_id,
    tx,
  )
}

test test_burn_short_positions_mint() {
  let validate_pool_ref =
    OutputReference {
      transaction_id: #"b4971034feee28d07f157faf99b850f856d8da3494c70b19b521cfe690258e26",
      output_index: 0,
    }

  let mint =
    assets.from_asset(enter_position_policy_id, short_asset_name, -5_000_000)

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
  let params =
    EnterPositionParams {
      orders_script_hash,
      long_asset_name,
      short_asset_name,
      validate_pool_ref,
      admin_pkh,
    }
  let redeemer = BurnShort(1)
  enter_position_mint.enter_position_mint.mint(
    params,
    redeemer,
    enter_position_policy_id,
    tx,
  )
}
