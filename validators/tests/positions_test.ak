use aiken/collection/dict
use aiken/interval.{Finite, Interval, IntervalBound}
use cardano/address.{from_script}
use cardano/assets.{from_lovelace}
use cardano/transaction.{
  InlineDatum, Input, Output, OutputReference, Transaction,
}
use positions
use tests/constants.{
  admin_pkh, batcher_fee, enter_position_policy_id,
  liquidity_positions_script_hash, lovelace_asset, orders_script_hash,
  pool_asset, positions_mint_asset, positions_script_hash,
  stable_collateral_asset, strike_collateral_asset, trader_pkh, underlying_asset,
  validate_pool_ref,
}
use types.{
  Asset, BurnPosition, Close, ClosePositionOrder, LiquidateClose,
  LiquidatePositionOrder, Long, MintPosition, OpenPositionOrder, OrdersDatum,
  PayLend, PoolDatum, PositionDatum, PositionsParams, Short, StopLossClose,
  TakeProfitClose, TraderClose, UpdateStopLoss, UpdateTakeProfit,
}

const position_datum =
  PositionDatum {
    owner_address_hash: trader_pkh,
    entered_at_usd_price: 100,
    underlying_asset,
    leverage_factor: 10,
    positions_mint_asset,
    positions_mint_asset_amount: 10_000_000,
    collateral_asset: lovelace_asset,
    collateral_asset_amount: 1_000_000,
    strike_collateral_asset,
    strike_collateral_asset_amount: 10,
    liquidate_usd_price: 100,
    stop_loss_usd_price: 90,
    take_profit_usd_price: 0,
    last_pay_lend_time: 1727453227635,
    validate_pool_ref,
    side: Long,
  }

const pool_ref_datum =
  PoolDatum {
    underlying_asset: lovelace_asset,
    underlying_asset_amount: 100_000_000,
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
  }

const pool_ref_input =
  Input {
    output_reference: validate_pool_ref,
    output: Output {
      address: from_script(#""),
      value: from_lovelace(2_000_000),
      datum: InlineDatum(pool_ref_datum),
      reference_script: None,
    },
  }

test enter_long_positions_mint() {
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
      entered_at_usd_price: 100,
      order_submission_usd_price: 100,
      validate_pool_ref,
      action: OpenPositionOrder,
      side: Long,
    }

  let pos_out =
    Output {
      address: from_script(orders_script_hash),
      value: mint
        |> assets.merge(assets.from_lovelace(batcher_fee))
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

test enter_short_positions_mint() {
  let orders_datum =
    OrdersDatum {
      owner_address_hash: trader_pkh,
      underlying_asset,
      underlying_asset_amount: 10,
      leverage_factor: 5,
      orders_script_hash,
      positions_script_hash: orders_script_hash,
      positions_mint_asset,
      positions_mint_asset_amount: 10_000_000,
      liquidity_asset: underlying_asset,
      liquidity_asset_amount: 10,
      liquidity_positions_script_hash,
      collateral_asset: stable_collateral_asset,
      collateral_asset_amount: 5,
      strike_collateral_asset,
      strike_collateral_asset_amount: 10,
      entered_earnings_per_share: 0,
      entered_collateral_earnings_per_share: 0,
      liquidate_usd_price: 100,
      stop_loss_usd_price: 0,
      take_profit_usd_price: 0,
      order_submission_time: 1727453227635,
      order_submission_usd_price: 1,
      entered_at_usd_price: 100,
      validate_pool_ref,
      action: OpenPositionOrder,
      side: Short,
    }

  let mint = assets.from_asset(enter_position_policy_id, trader_pkh, 10_000_000)

  let pos_out =
    Output {
      address: from_script(orders_script_hash),
      value: mint
        |> assets.merge(assets.from_lovelace(batcher_fee))
        |> assets.add(
            stable_collateral_asset.policy_id,
            stable_collateral_asset.asset_name,
            5,
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

test burn_positions_mint() {
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

test close_position_signed_by_owner() {
  let own_ref =
    OutputReference {
      transaction_id: #"b4971034feee28d07f157faf99b850f856d8da3494c70b19b521cfe690258e26",
      output_index: 0,
    }

  let input =
    Input {
      output_reference: own_ref,
      output: Output {
        address: from_script(positions_script_hash),
        value: assets.from_asset(
          enter_position_policy_id,
          trader_pkh,
          10_000_000,
        )
          |> assets.add(
              position_datum.strike_collateral_asset.policy_id,
              position_datum.strike_collateral_asset.asset_name,
              position_datum.strike_collateral_asset_amount,
            )
          |> assets.add(
              position_datum.collateral_asset.policy_id,
              position_datum.collateral_asset.asset_name,
              position_datum.collateral_asset_amount,
            ),
        datum: InlineDatum(position_datum),
        reference_script: None,
      },
    }

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
      entered_at_usd_price: 100,
      validate_pool_ref,
      action: ClosePositionOrder,
      side: Long,
    }

  let pos_out =
    Output {
      address: from_script(orders_script_hash),
      value: assets.from_asset(enter_position_policy_id, trader_pkh, 10_000_000)
        |> assets.merge(assets.from_lovelace(batcher_fee))
        |> assets.add(
            position_datum.strike_collateral_asset.policy_id,
            position_datum.strike_collateral_asset.asset_name,
            position_datum.strike_collateral_asset_amount,
          )
        |> assets.add(
            position_datum.collateral_asset.policy_id,
            position_datum.collateral_asset.asset_name,
            position_datum.collateral_asset_amount,
          ),
      datum: InlineDatum(orders_datum),
      reference_script: None,
    }

  let tx =
    Transaction {
      inputs: [input],
      reference_inputs: [],
      outputs: [pos_out],
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
  let params = PositionsParams { orders_script_hash, validate_pool_ref }
  let redeemer = Close(100, TraderClose)
  positions.positions.spend(params, Some(position_datum), redeemer, own_ref, tx)
}

test close_position_take_profit() {
  let own_ref =
    OutputReference {
      transaction_id: #"b4971034feee28d07f157faf99b850f856d8da3494c70b19b521cfe690258e26",
      output_index: 0,
    }

  let input =
    Input {
      output_reference: own_ref,
      output: Output {
        address: from_script(positions_script_hash),
        value: assets.from_asset(
          enter_position_policy_id,
          trader_pkh,
          10_000_000,
        )
          |> assets.add(
              position_datum.strike_collateral_asset.policy_id,
              position_datum.strike_collateral_asset.asset_name,
              position_datum.strike_collateral_asset_amount,
            )
          |> assets.add(
              position_datum.collateral_asset.policy_id,
              position_datum.collateral_asset.asset_name,
              position_datum.collateral_asset_amount,
            ),
        datum: InlineDatum(position_datum),
        reference_script: None,
      },
    }

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
      order_submission_usd_price: 120,
      entered_at_usd_price: 100,
      validate_pool_ref,
      action: ClosePositionOrder,
      side: Long,
    }

  let pos_out =
    Output {
      address: from_script(orders_script_hash),
      value: assets.from_asset(enter_position_policy_id, trader_pkh, 10_000_000)
        |> assets.merge(assets.from_lovelace(batcher_fee))
        |> assets.add(
            position_datum.strike_collateral_asset.policy_id,
            position_datum.strike_collateral_asset.asset_name,
            position_datum.strike_collateral_asset_amount,
          )
        |> assets.add(
            position_datum.collateral_asset.policy_id,
            position_datum.collateral_asset.asset_name,
            position_datum.collateral_asset_amount,
          ),
      datum: InlineDatum(orders_datum),
      reference_script: None,
    }

  let tx =
    Transaction {
      inputs: [input],
      reference_inputs: [],
      outputs: [pos_out],
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
  let params = PositionsParams { orders_script_hash, validate_pool_ref }
  let redeemer = Close(120, TakeProfitClose)
  positions.positions.spend(params, Some(position_datum), redeemer, own_ref, tx)
}

test close_position_stop_loss() {
  let own_ref =
    OutputReference {
      transaction_id: #"b4971034feee28d07f157faf99b850f856d8da3494c70b19b521cfe690258e26",
      output_index: 0,
    }

  let input =
    Input {
      output_reference: own_ref,
      output: Output {
        address: from_script(positions_script_hash),
        value: assets.from_asset(
          enter_position_policy_id,
          trader_pkh,
          10_000_000,
        )
          |> assets.add(
              position_datum.strike_collateral_asset.policy_id,
              position_datum.strike_collateral_asset.asset_name,
              position_datum.strike_collateral_asset_amount,
            )
          |> assets.add(
              position_datum.collateral_asset.policy_id,
              position_datum.collateral_asset.asset_name,
              position_datum.collateral_asset_amount,
            ),
        datum: InlineDatum(position_datum),
        reference_script: None,
      },
    }

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
      stop_loss_usd_price: 90,
      take_profit_usd_price: 0,
      order_submission_time: 1727453227635,
      order_submission_usd_price: 10,
      entered_at_usd_price: 100,
      validate_pool_ref,
      action: ClosePositionOrder,
      side: Long,
    }

  let pos_out =
    Output {
      address: from_script(orders_script_hash),
      value: assets.from_asset(enter_position_policy_id, trader_pkh, 10_000_000)
        |> assets.merge(assets.from_lovelace(batcher_fee))
        |> assets.add(
            position_datum.strike_collateral_asset.policy_id,
            position_datum.strike_collateral_asset.asset_name,
            position_datum.strike_collateral_asset_amount,
          )
        |> assets.add(
            position_datum.collateral_asset.policy_id,
            position_datum.collateral_asset.asset_name,
            position_datum.collateral_asset_amount,
          ),
      datum: InlineDatum(orders_datum),
      reference_script: None,
    }

  let tx =
    Transaction {
      inputs: [input],
      reference_inputs: [],
      outputs: [pos_out],
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
  let params = PositionsParams { orders_script_hash, validate_pool_ref }
  let redeemer = Close(10, StopLossClose)
  positions.positions.spend(params, Some(position_datum), redeemer, own_ref, tx)
}

test close_position_liquidate() {
  let own_ref =
    OutputReference {
      transaction_id: #"b4971034feee28d07f157faf99b850f856d8da3494c70b19b521cfe690258e26",
      output_index: 0,
    }

  let input =
    Input {
      output_reference: own_ref,
      output: Output {
        address: from_script(positions_script_hash),
        value: assets.from_asset(
          enter_position_policy_id,
          trader_pkh,
          10_000_000,
        )
          |> assets.add(
              position_datum.strike_collateral_asset.policy_id,
              position_datum.strike_collateral_asset.asset_name,
              position_datum.strike_collateral_asset_amount,
            )
          |> assets.add(
              position_datum.collateral_asset.policy_id,
              position_datum.collateral_asset.asset_name,
              position_datum.collateral_asset_amount,
            ),
        datum: InlineDatum(position_datum),
        reference_script: None,
      },
    }

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
      stop_loss_usd_price: 90,
      take_profit_usd_price: 0,
      order_submission_time: 1727453227635,
      order_submission_usd_price: 10,
      entered_at_usd_price: 100,
      validate_pool_ref,
      action: LiquidatePositionOrder,
      side: Long,
    }

  let pos_out =
    Output {
      address: from_script(orders_script_hash),
      value: assets.from_asset(enter_position_policy_id, trader_pkh, 10_000_000)
        |> assets.merge(assets.from_lovelace(batcher_fee))
        |> assets.add(
            position_datum.strike_collateral_asset.policy_id,
            position_datum.strike_collateral_asset.asset_name,
            position_datum.strike_collateral_asset_amount,
          )
        |> assets.add(
            position_datum.collateral_asset.policy_id,
            position_datum.collateral_asset.asset_name,
            position_datum.collateral_asset_amount,
          ),
      datum: InlineDatum(orders_datum),
      reference_script: None,
    }

  let tx =
    Transaction {
      inputs: [input],
      reference_inputs: [],
      outputs: [pos_out],
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
  let params = PositionsParams { orders_script_hash, validate_pool_ref }
  let redeemer = Close(10, LiquidateClose)
  positions.positions.spend(params, Some(position_datum), redeemer, own_ref, tx)
}

test update_stop_loss() {
  let own_ref =
    OutputReference {
      transaction_id: #"b4971034feee28d07f157faf99b850f856d8da3494c70b19b521cfe690258e26",
      output_index: 0,
    }

  let input =
    Input {
      output_reference: own_ref,
      output: Output {
        address: from_script(positions_script_hash),
        value: assets.from_asset(
          enter_position_policy_id,
          trader_pkh,
          10_000_000,
        )
          |> assets.add(
              position_datum.strike_collateral_asset.policy_id,
              position_datum.strike_collateral_asset.asset_name,
              position_datum.strike_collateral_asset_amount,
            )
          |> assets.add(
              position_datum.collateral_asset.policy_id,
              position_datum.collateral_asset.asset_name,
              position_datum.collateral_asset_amount,
            ),
        datum: InlineDatum(position_datum),
        reference_script: None,
      },
    }

  let new_datum =
    PositionDatum {
      owner_address_hash: trader_pkh,
      entered_at_usd_price: 100,
      underlying_asset,
      leverage_factor: 10,
      positions_mint_asset,
      positions_mint_asset_amount: 10_000_000,
      collateral_asset: lovelace_asset,
      collateral_asset_amount: 1_000_000,
      strike_collateral_asset,
      strike_collateral_asset_amount: 10,
      liquidate_usd_price: 100,
      stop_loss_usd_price: 10,
      take_profit_usd_price: 0,
      last_pay_lend_time: 1727453227635,
      validate_pool_ref,
      side: Long,
    }

  let pos_out =
    Output {
      address: from_script(positions_script_hash),
      value: assets.from_asset(enter_position_policy_id, trader_pkh, 10_000_000)
        |> assets.add(
            position_datum.strike_collateral_asset.policy_id,
            position_datum.strike_collateral_asset.asset_name,
            position_datum.strike_collateral_asset_amount,
          )
        |> assets.add(
            position_datum.collateral_asset.policy_id,
            position_datum.collateral_asset.asset_name,
            position_datum.collateral_asset_amount,
          ),
      datum: InlineDatum(new_datum),
      reference_script: None,
    }

  let tx =
    Transaction {
      inputs: [input],
      reference_inputs: [],
      outputs: [pos_out],
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
  let params = PositionsParams { orders_script_hash, validate_pool_ref }
  let redeemer = UpdateStopLoss(10)
  positions.positions.spend(params, Some(position_datum), redeemer, own_ref, tx)
}

test update_take_profit() {
  let own_ref =
    OutputReference {
      transaction_id: #"b4971034feee28d07f157faf99b850f856d8da3494c70b19b521cfe690258e26",
      output_index: 0,
    }

  let input =
    Input {
      output_reference: own_ref,
      output: Output {
        address: from_script(positions_script_hash),
        value: assets.from_asset(
          enter_position_policy_id,
          trader_pkh,
          10_000_000,
        )
          |> assets.add(
              position_datum.strike_collateral_asset.policy_id,
              position_datum.strike_collateral_asset.asset_name,
              position_datum.strike_collateral_asset_amount,
            )
          |> assets.add(
              position_datum.collateral_asset.policy_id,
              position_datum.collateral_asset.asset_name,
              position_datum.collateral_asset_amount,
            ),
        datum: InlineDatum(position_datum),
        reference_script: None,
      },
    }

  let new_datum =
    PositionDatum {
      owner_address_hash: trader_pkh,
      entered_at_usd_price: 100,
      underlying_asset,
      leverage_factor: 10,
      positions_mint_asset,
      positions_mint_asset_amount: 10_000_000,
      collateral_asset: lovelace_asset,
      collateral_asset_amount: 1_000_000,
      strike_collateral_asset,
      strike_collateral_asset_amount: 10,
      liquidate_usd_price: 100,
      stop_loss_usd_price: 90,
      take_profit_usd_price: 10,
      last_pay_lend_time: 1727453227635,
      validate_pool_ref,
      side: Long,
    }

  let pos_out =
    Output {
      address: from_script(positions_script_hash),
      value: assets.from_asset(enter_position_policy_id, trader_pkh, 10_000_000)
        |> assets.add(
            position_datum.strike_collateral_asset.policy_id,
            position_datum.strike_collateral_asset.asset_name,
            position_datum.strike_collateral_asset_amount,
          )
        |> assets.add(
            position_datum.collateral_asset.policy_id,
            position_datum.collateral_asset.asset_name,
            position_datum.collateral_asset_amount,
          ),
      datum: InlineDatum(new_datum),
      reference_script: None,
    }

  let tx =
    Transaction {
      inputs: [input],
      reference_inputs: [],
      outputs: [pos_out],
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
  let params = PositionsParams { orders_script_hash, validate_pool_ref }
  let redeemer = UpdateTakeProfit(10)
  positions.positions.spend(params, Some(position_datum), redeemer, own_ref, tx)
}

test pay_lend() {
  let own_ref =
    OutputReference {
      transaction_id: #"b4971034feee28d07f157faf99b850f856d8da3494c70b19b521cfe690258e26",
      output_index: 0,
    }

  let input =
    Input {
      output_reference: own_ref,
      output: Output {
        address: from_script(positions_script_hash),
        value: assets.from_asset(
          position_datum.positions_mint_asset.policy_id,
          position_datum.positions_mint_asset.asset_name,
          10_000_000,
        )
          |> assets.add(
              position_datum.strike_collateral_asset.policy_id,
              position_datum.strike_collateral_asset.asset_name,
              position_datum.strike_collateral_asset_amount,
            )
          |> assets.add(
              position_datum.collateral_asset.policy_id,
              position_datum.collateral_asset.asset_name,
              position_datum.collateral_asset_amount,
            ),
        datum: InlineDatum(position_datum),
        reference_script: None,
      },
    }

  let new_datum =
    PositionDatum {
      owner_address_hash: position_datum.owner_address_hash,
      entered_at_usd_price: position_datum.entered_at_usd_price,
      underlying_asset: position_datum.underlying_asset,
      leverage_factor: position_datum.leverage_factor,
      positions_mint_asset: position_datum.positions_mint_asset,
      positions_mint_asset_amount: position_datum.positions_mint_asset_amount,
      collateral_asset: position_datum.collateral_asset,
      collateral_asset_amount: position_datum.collateral_asset_amount,
      strike_collateral_asset: position_datum.strike_collateral_asset,
      strike_collateral_asset_amount: position_datum.strike_collateral_asset_amount,
      liquidate_usd_price: position_datum.liquidate_usd_price,
      stop_loss_usd_price: position_datum.stop_loss_usd_price,
      take_profit_usd_price: position_datum.take_profit_usd_price,
      last_pay_lend_time: position_datum.last_pay_lend_time + 3_600_000,
      validate_pool_ref: position_datum.validate_pool_ref,
      side: position_datum.side,
    }

  let expected_burn_mint =
    assets.from_asset(
      position_datum.positions_mint_asset.policy_id,
      position_datum.positions_mint_asset.asset_name,
      -200_000,
    )

  let pos_out =
    Output {
      address: from_script(positions_script_hash),
      value: assets.from_asset(
        position_datum.positions_mint_asset.policy_id,
        position_datum.positions_mint_asset.asset_name,
        9_800_000,
      )
        |> assets.add(
            position_datum.strike_collateral_asset.policy_id,
            position_datum.strike_collateral_asset.asset_name,
            position_datum.strike_collateral_asset_amount,
          )
        |> assets.add(
            position_datum.collateral_asset.policy_id,
            position_datum.collateral_asset.asset_name,
            position_datum.collateral_asset_amount,
          ),
      datum: InlineDatum(new_datum),
      reference_script: None,
    }

  let tx =
    Transaction {
      inputs: [input],
      reference_inputs: [pool_ref_input],
      outputs: [pos_out],
      fee: 0,
      mint: expected_burn_mint,
      certificates: [],
      withdrawals: [],
      validity_range: Interval {
        lower_bound: IntervalBound {
          bound_type: Finite(1727453227635 + 3_600_000),
          is_inclusive: False,
        },
        upper_bound: IntervalBound {
          bound_type: Finite(1728456400000 + 3_600_000),
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
  let params = PositionsParams { orders_script_hash, validate_pool_ref }
  let redeemer = PayLend(90)
  positions.positions.spend(params, Some(position_datum), redeemer, own_ref, tx)
}
