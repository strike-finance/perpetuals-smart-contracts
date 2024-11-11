use aiken/collection/dict
use aiken/interval.{Finite, Interval, IntervalBound}
use cardano/address.{from_script}
use cardano/assets.{from_lovelace}
use cardano/transaction.{
  InlineDatum, Input, Output, OutputReference, Transaction,
}
use positions
use tests/constants.{
  admin_pkh, batcher_fee, orders_script_hash, out_ref, pool_asset, pool_license,
  position_hash, positions_script_hash, stable_asset, strike_collateral_asset,
  trader_pkh, underlying_asset,
}
use types.{
  Asset, BurnPosition, Close, ClosePositionOrder, LiquidateClose,
  LiquidatePositionOrder, Long, LongCloseOrder, MintPosition, OpenPositionOrder,
  OrderDatum, PoolDatum, PositionDatum, PositionsParams, Short, StopLossClose,
  TakeProfitClose, TraderClose, UpdateStopLoss, UpdateTakeProfit,
}

const position_datum =
  PositionDatum {
    owner_address_hash: trader_pkh,
    entered_at_usd_price: 100,
    position_hash,
    leverage_factor: 10,
    position_asset_amount: 10_000_000,
    stop_loss_usd_price: 98,
    take_profit_usd_price: 0,
    collateral_asset: underlying_asset,
    entered_position_time: 1727453227635,
    margin_requirement: 5,
    hourly_usd_borrow_fee: 20,
    side: Long,
  }

const pool_ref_datum =
  PoolDatum {
    underlying_asset,
    underlying_asset_amount: 100_000_000,
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

const pool_ref_input =
  Input {
    output_reference: out_ref,
    output: Output {
      address: from_script(#""),
      value: from_lovelace(2_000_000)
        |> assets.add(pool_license, "", 1),
      datum: InlineDatum(pool_ref_datum),
      reference_script: None,
    },
  }

test enter_long_positions_mint() {
  let mint = assets.from_asset(position_hash, trader_pkh, 1)

  let orders_datum =
    OrderDatum {
      action: OpenPositionOrder {
        owner_address_hash: trader_pkh,
        leverage_factor: 10,
        position_hash,
        position_asset_amount: 10_000_000,
        margin_requirement: 5,
        hourly_usd_borrow_fee: 20,
        order_submission_time: 1727453227635,
        order_submission_usd_price: 100,
        side: Long,
      },
    }

  let pos_out =
    Output {
      address: from_script(orders_script_hash),
      value: mint
        |> assets.merge(assets.from_lovelace(batcher_fee))
        |> assets.add(
            underlying_asset.policy_id,
            underlying_asset.asset_name,
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
  let params = PositionsParams { orders_script_hash, pool_license }
  let redeemer = MintPosition(100)
  positions.positions.mint(params, redeemer, position_hash, tx)
}

test enter_short_positions_mint() {
  let orders_datum =
    OrderDatum {
      action: OpenPositionOrder {
        owner_address_hash: trader_pkh,
        leverage_factor: 10,
        position_hash,
        position_asset_amount: 10_000_000,
        margin_requirement: 5,
        hourly_usd_borrow_fee: 1,
        order_submission_time: 1727453227635,
        order_submission_usd_price: 1,
        side: Short,
      },
    }

  let mint = assets.from_asset(position_hash, trader_pkh, 1)

  let pos_out =
    Output {
      address: from_script(orders_script_hash),
      value: mint
        |> assets.merge(assets.from_lovelace(batcher_fee))
        |> assets.add(stable_asset.policy_id, stable_asset.asset_name, 5)
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
  let params = PositionsParams { orders_script_hash, pool_license }
  let redeemer = MintPosition(1)
  positions.positions.mint(params, redeemer, position_hash, tx)
}

test burn_positions_mint() {
  let mint = assets.from_asset(position_hash, trader_pkh, -1)

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
  let params = PositionsParams { orders_script_hash, pool_license }
  let redeemer = BurnPosition(1, trader_pkh)
  positions.positions.mint(params, redeemer, position_hash, tx)
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
        value: assets.from_asset(position_hash, trader_pkh, 1)
          |> assets.add(
              strike_collateral_asset.policy_id,
              strike_collateral_asset.asset_name,
              10,
            )
          |> assets.add(
              underlying_asset.policy_id,
              underlying_asset.asset_name,
              1_000_000,
            ),
        datum: InlineDatum(position_datum),
        reference_script: None,
      },
    }

  let orders_datum =
    OrderDatum {
      action: ClosePositionOrder {
        owner_address_hash: trader_pkh,
        leverage_factor: position_datum.leverage_factor,
        order_submission_usd_price: 100,
        position_hash,
        entered_at_usd_price: position_datum.entered_at_usd_price,
        stop_loss_usd_price: position_datum.stop_loss_usd_price,
        take_profit_usd_price: position_datum.take_profit_usd_price,
        entered_position_time: position_datum.entered_position_time,
        position_asset_amount: position_datum.position_asset_amount,
        margin_requirement: position_datum.margin_requirement,
        hourly_usd_borrow_fee: position_datum.hourly_usd_borrow_fee,
        return_amount: LongCloseOrder { asset_amount: 1_000_000 },
        side: Long,
      },
    }

  let pos_out =
    Output {
      address: from_script(orders_script_hash),
      value: assets.from_asset(position_hash, trader_pkh, 1)
        |> assets.merge(assets.from_lovelace(batcher_fee))
        |> assets.add(
            strike_collateral_asset.policy_id,
            strike_collateral_asset.asset_name,
            10,
          )
        |> assets.add(
            position_datum.collateral_asset.policy_id,
            underlying_asset.asset_name,
            1_000_000,
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
  let params = PositionsParams { orders_script_hash, pool_license }
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
        value: assets.from_asset(position_hash, trader_pkh, 1)
          |> assets.add(
              strike_collateral_asset.policy_id,
              strike_collateral_asset.asset_name,
              10,
            )
          |> assets.add(
              position_datum.collateral_asset.policy_id,
              position_datum.collateral_asset.asset_name,
              1_000_000,
            ),
        datum: InlineDatum(position_datum),
        reference_script: None,
      },
    }

  let orders_datum =
    OrderDatum {
      action: ClosePositionOrder {
        owner_address_hash: trader_pkh,
        leverage_factor: position_datum.leverage_factor,
        order_submission_usd_price: 120,
        position_hash,
        entered_at_usd_price: position_datum.entered_at_usd_price,
        stop_loss_usd_price: position_datum.stop_loss_usd_price,
        take_profit_usd_price: position_datum.take_profit_usd_price,
        entered_position_time: position_datum.entered_position_time,
        position_asset_amount: position_datum.position_asset_amount,
        margin_requirement: position_datum.margin_requirement,
        hourly_usd_borrow_fee: position_datum.hourly_usd_borrow_fee,
        return_amount: LongCloseOrder { asset_amount: 2_666_666 },
        side: Long,
      },
    }

  let pos_out =
    Output {
      address: from_script(orders_script_hash),
      value: assets.from_asset(position_hash, trader_pkh, 1)
        |> assets.merge(assets.from_lovelace(batcher_fee))
        |> assets.add(
            strike_collateral_asset.policy_id,
            strike_collateral_asset.asset_name,
            10,
          )
        |> assets.add(
            position_datum.collateral_asset.policy_id,
            position_datum.collateral_asset.asset_name,
            1_000_000,
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
  let params = PositionsParams { orders_script_hash, pool_license }

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
        value: assets.from_asset(position_hash, trader_pkh, 1)
          |> assets.add(
              position_datum.collateral_asset.policy_id,
              position_datum.collateral_asset.asset_name,
              1_000_000,
            )
          |> assets.add(
              strike_collateral_asset.policy_id,
              strike_collateral_asset.asset_name,
              10,
            ),
        datum: InlineDatum(position_datum),
        reference_script: None,
      },
    }

  let orders_datum =
    OrderDatum {
      action: ClosePositionOrder {
        owner_address_hash: trader_pkh,
        leverage_factor: position_datum.leverage_factor,
        order_submission_usd_price: 98,
        position_hash,
        entered_at_usd_price: position_datum.entered_at_usd_price,
        stop_loss_usd_price: 98,
        take_profit_usd_price: position_datum.take_profit_usd_price,
        entered_position_time: position_datum.entered_position_time,
        position_asset_amount: position_datum.position_asset_amount,
        margin_requirement: position_datum.margin_requirement,
        hourly_usd_borrow_fee: position_datum.hourly_usd_borrow_fee,
        return_amount: LongCloseOrder { asset_amount: 795_918 },
        side: Long,
      },
    }

  let pos_out =
    Output {
      address: from_script(orders_script_hash),
      value: assets.from_asset(position_hash, trader_pkh, 1)
        |> assets.merge(assets.from_lovelace(batcher_fee))
        |> assets.add(
            strike_collateral_asset.policy_id,
            strike_collateral_asset.asset_name,
            10,
          )
        |> assets.add(
            position_datum.collateral_asset.policy_id,
            position_datum.collateral_asset.asset_name,
            1_000_000,
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
  let params = PositionsParams { orders_script_hash, pool_license }
  let redeemer = Close(98, StopLossClose)
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
        value: assets.from_asset(position_hash, trader_pkh, 1)
          |> assets.add(
              strike_collateral_asset.policy_id,
              strike_collateral_asset.asset_name,
              10,
            )
          |> assets.add(
              position_datum.collateral_asset.policy_id,
              position_datum.collateral_asset.asset_name,
              1_000_000,
            ),
        datum: InlineDatum(position_datum),
        reference_script: None,
      },
    }

  let orders_datum =
    OrderDatum {
      action: LiquidatePositionOrder {
        owner_address_hash: trader_pkh,
        position_hash,
        side: Long,
      },
    }

  let pos_out =
    Output {
      address: from_script(orders_script_hash),
      value: assets.from_asset(position_hash, trader_pkh, 1)
        |> assets.merge(assets.from_lovelace(batcher_fee))
        |> assets.add(
            strike_collateral_asset.policy_id,
            strike_collateral_asset.asset_name,
            10,
          )
        |> assets.add(
            position_datum.collateral_asset.policy_id,
            position_datum.collateral_asset.asset_name,
            1_000_000,
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
  let params = PositionsParams { orders_script_hash, pool_license }
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
        value: assets.from_asset(position_hash, trader_pkh, 1)
          |> assets.add(
              strike_collateral_asset.policy_id,
              strike_collateral_asset.asset_name,
              10,
            )
          |> assets.add(
              position_datum.collateral_asset.policy_id,
              position_datum.collateral_asset.asset_name,
              1_000_000,
            ),
        datum: InlineDatum(position_datum),
        reference_script: None,
      },
    }

  let new_datum =
    PositionDatum {
      owner_address_hash: trader_pkh,
      entered_at_usd_price: position_datum.entered_at_usd_price,
      position_hash,
      leverage_factor: position_datum.leverage_factor,
      position_asset_amount: position_datum.position_asset_amount,
      collateral_asset: underlying_asset,
      stop_loss_usd_price: 10,
      take_profit_usd_price: position_datum.take_profit_usd_price,
      entered_position_time: position_datum.entered_position_time,
      margin_requirement: position_datum.margin_requirement,
      hourly_usd_borrow_fee: position_datum.hourly_usd_borrow_fee,
      side: position_datum.side,
    }

  let pos_out =
    Output {
      address: from_script(positions_script_hash),
      value: assets.from_asset(position_hash, trader_pkh, 1)
        |> assets.add(
            strike_collateral_asset.policy_id,
            strike_collateral_asset.asset_name,
            10,
          )
        |> assets.add(
            position_datum.collateral_asset.policy_id,
            position_datum.collateral_asset.asset_name,
            1_000_000,
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
  let params = PositionsParams { orders_script_hash, pool_license }
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
        value: assets.from_asset(position_hash, trader_pkh, 1)
          |> assets.add(
              strike_collateral_asset.policy_id,
              strike_collateral_asset.asset_name,
              10,
            )
          |> assets.add(
              position_datum.collateral_asset.policy_id,
              position_datum.collateral_asset.asset_name,
              1_000_000,
            ),
        datum: InlineDatum(position_datum),
        reference_script: None,
      },
    }

  let new_datum =
    PositionDatum {
      owner_address_hash: trader_pkh,
      position_hash,
      leverage_factor: position_datum.leverage_factor,
      entered_at_usd_price: position_datum.entered_at_usd_price,
      position_asset_amount: position_datum.position_asset_amount,
      collateral_asset: underlying_asset,
      stop_loss_usd_price: position_datum.stop_loss_usd_price,
      take_profit_usd_price: 10,
      entered_position_time: position_datum.entered_position_time,
      margin_requirement: position_datum.margin_requirement,
      hourly_usd_borrow_fee: position_datum.hourly_usd_borrow_fee,
      side: position_datum.side,
    }

  let pos_out =
    Output {
      address: from_script(positions_script_hash),
      value: assets.from_asset(position_hash, trader_pkh, 1)
        |> assets.add(
            strike_collateral_asset.policy_id,
            strike_collateral_asset.asset_name,
            10,
          )
        |> assets.add(
            position_datum.collateral_asset.policy_id,
            position_datum.collateral_asset.asset_name,
            1_000_000,
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
  let params = PositionsParams { orders_script_hash, pool_license }
  let redeemer = UpdateTakeProfit(10)
  positions.positions.spend(params, Some(position_datum), redeemer, own_ref, tx)
}
