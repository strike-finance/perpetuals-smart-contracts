use aiken/collection/dict
use aiken/collection/list
use aiken/interval.{Finite, Interval, IntervalBound}
use cardano/address.{from_script}
use cardano/assets.{AssetName, PolicyId, flatten, from_lovelace, quantity_of}
use cardano/transaction.{InlineDatum, Input, Output, Transaction}
use constants.{
  pool_nft_asset_name, position_asset_name, settings_nft_asset_name,
  strike_asset_name, strike_policy_id,
}
use math.{calculate_hourly_usd_borrow_fee}
use test_constants.{
  orders_script_hash, out_ref, position_hash, protocol_nft_policy_id, trader_pkh,
  underlying_asset,
}
use types.{
  Long, MarketOrder, OpenPositionOrder, OrderDatum, PoolDatum, PositionDatum,
  ScriptHash, SettingsDatum,
}
use utils.{get_lower_bound}

pub type LimitOrderRedeemer {
  CompleteLimitOrder { price: Int }
  CancelLimitOrder
}

pub type PositionMintRedeemer {
  OpenPosition {
    current_usd_price: Int,
    output_to_order_index: Int,
    pool_index: Int,
    setting_index: Int,
  }
  ClosePosition { burn_amount: Int }
}

validator position_mint(
  orders_script_hash: ScriptHash,
  pool_nft_policy_id: PolicyId,
  pool_nft_asset_name: AssetName,
  settings_nft_policy_id: PolicyId,
  settings_nft_asset_name: AssetName,
) {
  mint(
    redeemer: PositionMintRedeemer,
    policy_id: PolicyId,
    transaction: Transaction,
  ) {
    when redeemer is {
      OpenPosition(
        current_usd_price,
        output_to_order_index,
        pool_index,
        setting_index,
      ) -> {
        let Transaction { mint, reference_inputs, outputs, .. } = transaction

        expect Some(output_to_orders_validator) =
          list.at(outputs, output_to_order_index)
        expect InlineDatum(orders_datum) = output_to_orders_validator.datum
        expect orders_datum_typed: OrderDatum = orders_datum

        expect OpenPositionOrder {
          position_datum: PositionDatum {
            entered_position_time,
            entered_at_usd_price,
            position_asset_amount,
            hourly_usd_borrow_fee,
            collateral_asset,
            collateral_asset_amount,
            ..
          },
          ..
        } = orders_datum_typed.action

        expect Some(Input {
          output: Output { value: pool_value, datum: pool_datum, .. },
          ..
        }) = list.at(reference_inputs, pool_index)

        expect InlineDatum(pool_datum) = pool_datum
        expect pool_datum_typed: PoolDatum = pool_datum

        let PoolDatum {
          underlying_asset,
          total_lended_amount,
          liquidity_total_asset_amount,
          ..
        } = pool_datum_typed

        expect Some(Input {
          output: Output {
            value: global_settings_value,
            datum: global_settings_datum,
            ..
          },
          ..
        }) = list.at(reference_inputs, setting_index)
        expect InlineDatum(global_settings_datum) = global_settings_datum
        expect global_settings_datum_typed: SettingsDatum =
          global_settings_datum

        let SettingsDatum {
          interest_rate,
          max_leverage_factor,
          max_strike_holder_leverage_factor,
          ..
        } = global_settings_datum_typed

        let available_asset_amount =
          liquidity_total_asset_amount - total_lended_amount

        expect
          available_asset_amount >= position_asset_amount - collateral_asset_amount

        expect
          from_script(orders_script_hash) == output_to_orders_validator.address

        expect
          assets.quantity_of(
            pool_value,
            pool_nft_policy_id,
            pool_nft_asset_name,
          ) == 1

        expect
          assets.quantity_of(
            global_settings_value,
            settings_nft_policy_id,
            settings_nft_asset_name,
          ) == 1
        expect current_usd_price == entered_at_usd_price
        expect [(policy_id, position_asset_name, 1)] == flatten(mint)

        expect
          quantity_of(
            output_to_orders_validator.value,
            collateral_asset.policy_id,
            collateral_asset.asset_name,
          ) == collateral_asset_amount

        expect
          quantity_of(
            output_to_orders_validator.value,
            policy_id,
            position_asset_name,
          ) == 1

        let pool_underlying_asset_amount =
          quantity_of(
            pool_value,
            underlying_asset.policy_id,
            underlying_asset.asset_name,
          )

        let estimated_hourly_usd_borrow_fee: Int =
          calculate_hourly_usd_borrow_fee(
            position_asset_amount,
            total_lended_amount,
            current_usd_price,
            pool_underlying_asset_amount,
            interest_rate,
          )

        expect hourly_usd_borrow_fee >= estimated_hourly_usd_borrow_fee
        expect
          get_lower_bound(transaction.validity_range) >= entered_position_time

        let contains_strike_collateral: Bool =
          quantity_of(
            output_to_orders_validator.value,
            strike_policy_id,
            strike_asset_name,
          ) > 0
        // Make sure the amount of position_asset_amount is less than the collateral asset amount * leverage factor
        // for strike holders, they have a different leverage factor
        if contains_strike_collateral {
          position_asset_amount / max_strike_holder_leverage_factor <= collateral_asset_amount
        } else {
          position_asset_amount / max_leverage_factor <= collateral_asset_amount
        }
      }
      // Batcher might close/liquidate multiple positions at once
      ClosePosition(burn_amount) ->
        [(policy_id, position_asset_name, -burn_amount)] == flatten(
          transaction.mint,
        )
    }
  }

  else(_) {
    False
  }
}

test enter_position_mint() {
  let position_datum =
    PositionDatum {
      owner_pkh: trader_pkh,
      owner_stake_key: None,
      entered_at_usd_price: 100,
      position_hash,
      leverage_factor: 10,
      position_asset_amount: 10_000_000,
      stop_loss_usd_price: 98,
      take_profit_usd_price: 0,
      collateral_asset: underlying_asset,
      entered_position_time: 1727453227635,
      maintain_margin_amount: 5,
      hourly_usd_borrow_fee: 90000,
      collateral_asset_amount: 1_000_000,
      side: Long,
    }

  let pool_datum =
    PoolDatum {
      underlying_asset,
      lp_asset: underlying_asset,
      liquidity_total_asset_amount: 1_000_000_000,
      liquidity_total_gains_losses: 1_000_000_000,
      liquidity_total_lp_minted: 1_000_000_000,
      total_lended_amount: 1_000_000,
      batcher_license: protocol_nft_policy_id,
    }

  let pool_ref_input =
    Input {
      output_reference: out_ref,
      output: Output {
        address: from_script(#""),
        value: from_lovelace(2_000_000)
          |> assets.add(protocol_nft_policy_id, pool_nft_asset_name, 1)
          |> assets.add(
              underlying_asset.policy_id,
              underlying_asset.asset_name,
              1_000_000_000,
            ),
        datum: InlineDatum(pool_datum),
        reference_script: None,
      },
    }

  let settings_datum =
    SettingsDatum {
      interest_rate: 10,
      max_leverage_factor: 10,
      max_strike_holder_leverage_factor: 10,
      maintain_margin_amount: 5,
    }

  let settings_ref_input =
    Input {
      output_reference: out_ref,
      output: Output {
        address: from_script(#""),
        value: from_lovelace(2_000_000)
          |> assets.add(protocol_nft_policy_id, settings_nft_asset_name, 1)
          |> assets.add(
              underlying_asset.policy_id,
              underlying_asset.asset_name,
              1_000_000_000,
            ),
        datum: InlineDatum(settings_datum),
        reference_script: None,
      },
    }

  let mint = assets.from_asset(position_hash, position_asset_name, 1)

  let orders_datum =
    OrderDatum {
      action: OpenPositionOrder {
        position_datum,
        open_position_type: MarketOrder,
      },
    }

  let orders_output =
    Output {
      address: from_script(orders_script_hash),
      value: from_lovelace(1_000_000)
        |> assets.add(position_hash, position_asset_name, 1),
      datum: InlineDatum(orders_datum),
      reference_script: None,
    }

  let tx =
    Transaction {
      inputs: [],
      reference_inputs: [pool_ref_input, settings_ref_input],
      outputs: [orders_output],
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
      extra_signatories: [],
      redeemers: [],
      datums: dict.empty,
      id: #"0000000000000000000000000000000000000000000000000000000000000000",
      votes: [],
      proposal_procedures: [],
      current_treasury_amount: None,
      treasury_donation: None,
    }

  let redeemer =
    OpenPosition {
      current_usd_price: 100,
      output_to_order_index: 0,
      pool_index: 0,
      setting_index: 1,
    }

  position_mint.mint(
    orders_script_hash,
    protocol_nft_policy_id,
    pool_nft_asset_name,
    protocol_nft_policy_id,
    settings_nft_asset_name,
    redeemer,
    position_hash,
    tx,
  )
}
