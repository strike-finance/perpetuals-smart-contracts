use aiken/collection/dict
use aiken/collection/list
use aiken/interval.{Finite, Interval, IntervalBound}
use cardano/address.{from_script}
use cardano/assets.{PolicyId, quantity_of}
use cardano/transaction.{
  InlineDatum, Input, Output, OutputReference, Transaction, find_script_outputs,
}
use test_constants.{
  admin_pkh, collateral_asset, enter_position_policy_id, long_asset_name,
  long_position_asset, orders_script_hash, pool_asset, short_asset_name,
  strike_collateral_asset, trader_pkh, underlying_asset,
}
use types.{
  Asset, BurnLong, BurnShort, EnterPositionParams, Long, MintLong, MintShort,
  OpenPosition, OrdersDatum, PoolDatum, PositionsMintRedeemer,
}
use utils.{validate_token_mint}

validator enter_positions_mint(params: EnterPositionParams) {
  mint(
    redeemer: PositionsMintRedeemer,
    policy_id: PolicyId,
    transaction: Transaction,
  ) {
    when redeemer is {
      MintLong(current_price) -> {
        let outputs_to_orders_address: List<Output> =
          find_script_outputs(transaction.outputs, params.orders_script_hash)

        let only_one_output_to_orders: Bool =
          list.length(outputs_to_orders_address) == 1

        expect Some(output_to_orders_validator) =
          list.head(outputs_to_orders_address)

        expect InlineDatum(orders_datum) = output_to_orders_validator.datum

        expect orders_datum_typed: OrdersDatum = orders_datum

        let ref_input: List<Input> = transaction.reference_inputs

        expect Some(pool_ref_input) =
          list.find(
            ref_input,
            fn(ref_input: Input) {
              ref_input.output_reference == params.validate_pool_ref
            },
          )

        expect InlineDatum(pool_ref_datum) = pool_ref_input.output.datum
        expect pool_ref_datum_typed: PoolDatum = pool_ref_datum

        let valid_pool_ref: Bool =
          orders_datum_typed.validate_pool_ref == params.validate_pool_ref

        let contains_strike_collateral: Bool =
          quantity_of(
            output_to_orders_validator.value,
            orders_datum_typed.strike_collateral_asset.policy_id,
            orders_datum_typed.strike_collateral_asset.asset_name,
          ) > 0

        let earnings_per_share_valid: Bool =
          orders_datum_typed.entered_earnings_per_share == pool_ref_datum_typed.earnings_per_share && orders_datum_typed.entered_collateral_earnings_per_share == pool_ref_datum_typed.collateral_earnings_per_share

        let current_price_valid: Bool =
          current_price == orders_datum_typed.entered_at_price

        let signed_by_admin: Bool =
          list.has(transaction.extra_signatories, params.admin_pkh)

        only_one_output_to_orders && valid_pool_ref && earnings_per_share_valid && current_price_valid && signed_by_admin
      }
      //    
      // if contains_strike_collateral {
      //   let collateral_asset_deposited_amount: Int =
      //     quantity_of(
      //       output_to_orders_validator.value,
      //       orders_datum_typed.underlying_asset.policy_id,
      //       orders_datum_typed.underlying_asset.asset_name,
      //     ) * orders_datum_typed.leverage_factor
      //   let leverage_factor_valid: Bool =
      //     pool_ref_datum_typed.max_strike_holder_leverage_factor >= orders_datum_typed.leverage_factor
      //   let expected_mint: (PolicyId, ByteArray, Int) =
      //     (policy_id, long_asset_name, collateral_asset_deposited_amount)
      //   let mint_valid: Bool =
      //     validate_token_mint(transaction.mint, expected_mint)
      //   leverage_factor_valid && mint_valid
      // } else {
      //   let collateral_asset_deposited_amount: Int =
      //     quantity_of(
      //       output_to_orders_validator.value,
      //       orders_datum_typed.underlying_asset.policy_id,
      //       orders_datum_typed.underlying_asset.asset_name,
      //     ) * orders_datum_typed.leverage_factor
      //   let leverage_factor_valid: Bool =
      //     pool_ref_datum_typed.max_leverage_factor >= orders_datum_typed.leverage_factor
      //   let expected_mint: (PolicyId, ByteArray, Int) =
      //     (policy_id, long_asset_name, collateral_asset_deposited_amount)
      //   let mint_valid: Bool =
      //     validate_token_mint(transaction.mint, expected_mint)
      //   leverage_factor_valid && mint_valid
      // }
      MintShort(current_price) -> {
        let outputs_to_orders_address: List<Output> =
          find_script_outputs(transaction.outputs, params.orders_script_hash)

        let only_one_output_to_orders: Bool =
          list.length(outputs_to_orders_address) == 1

        expect Some(output_to_orders_validator) =
          list.head(outputs_to_orders_address)

        expect InlineDatum(orders_datum) = output_to_orders_validator.datum

        expect orders_datum_typed: OrdersDatum = orders_datum

        let ref_input: List<Input> = transaction.reference_inputs

        expect Some(pool_ref_input) =
          list.find(
            ref_input,
            fn(ref_input: Input) {
              ref_input.output_reference == params.validate_pool_ref
            },
          )

        expect InlineDatum(pool_ref_datum) = pool_ref_input.output.datum
        expect pool_ref_datum_typed: PoolDatum = pool_ref_datum

        let valid_pool_ref: Bool =
          orders_datum_typed.validate_pool_ref == params.validate_pool_ref

        let contains_strike_collateral: Bool =
          quantity_of(
            output_to_orders_validator.value,
            orders_datum_typed.strike_collateral_asset.policy_id,
            orders_datum_typed.strike_collateral_asset.asset_name,
          ) > 0

        let earnings_per_share_valid: Bool =
          orders_datum_typed.entered_earnings_per_share == pool_ref_datum_typed.earnings_per_share && orders_datum_typed.entered_collateral_earnings_per_share == pool_ref_datum_typed.collateral_earnings_per_share

        let current_price_valid: Bool =
          current_price == orders_datum_typed.entered_at_price

        let signed_by_admin: Bool =
          list.has(transaction.extra_signatories, params.admin_pkh)

        expect
          only_one_output_to_orders && valid_pool_ref && earnings_per_share_valid && current_price_valid && signed_by_admin

        if contains_strike_collateral {
          let expected_usd_collateral: Int =
            orders_datum_typed.positions_asset_amount * current_price * orders_datum_typed.leverage_factor

          let collateral_asset_deposited_amount: Int =
            quantity_of(
              output_to_orders_validator.value,
              orders_datum_typed.stable_collateral_asset.policy_id,
              orders_datum_typed.stable_collateral_asset.asset_name,
            ) * orders_datum_typed.leverage_factor

          let leverage_factor_valid: Bool =
            pool_ref_datum_typed.max_strike_holder_leverage_factor >= orders_datum_typed.leverage_factor

          let expected_mint: (PolicyId, ByteArray, Int) =
            (policy_id, long_asset_name, collateral_asset_deposited_amount)

          let mint_valid = validate_token_mint(transaction.mint, expected_mint)

          let expected_usd_collateral_valid: Bool =
            collateral_asset_deposited_amount >= expected_usd_collateral

          expected_usd_collateral_valid && leverage_factor_valid && mint_valid
        } else {
          let expected_usd_collateral: Int =
            orders_datum_typed.positions_asset_amount * current_price * orders_datum_typed.leverage_factor

          let collateral_asset_deposited_amount: Int =
            quantity_of(
              output_to_orders_validator.value,
              orders_datum_typed.stable_collateral_asset.policy_id,
              orders_datum_typed.stable_collateral_asset.asset_name,
            ) * orders_datum_typed.leverage_factor

          let leverage_factor_valid: Bool =
            pool_ref_datum_typed.max_leverage_factor >= orders_datum_typed.leverage_factor

          let expected_mint: (PolicyId, ByteArray, Int) =
            (policy_id, long_asset_name, collateral_asset_deposited_amount)

          let mint_valid = validate_token_mint(transaction.mint, expected_mint)

          let expected_usd_collateral_valid: Bool =
            collateral_asset_deposited_amount >= expected_usd_collateral

          expected_usd_collateral_valid && leverage_factor_valid && mint_valid
        }
      }
      BurnLong -> {
        let mint_amount: Int =
          quantity_of(transaction.mint, policy_id, long_asset_name)
        mint_amount < 0
      }
      BurnShort -> {
        let mint_amount: Int =
          quantity_of(transaction.mint, policy_id, short_asset_name)
        mint_amount < 0
      }
    }
  }

  else(_) {
    False
  }
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
      max_leverage_factor: 0,
      max_strike_holder_leverage_factor: 0,
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
        value: assets.from_lovelace(2_000_000),
        datum: InlineDatum(pool_ref_datum),
        reference_script: None,
      },
    }

  let mint = assets.from_asset(enter_position_policy_id, long_asset_name, -10)

  let orders_datum =
    OrdersDatum {
      owner_address_hash: trader_pkh,
      entered_at_price: 100,
      underlying_asset,
      underlying_asset_amount: 10,
      leverage_factor: 10,
      orders_validator_hash: orders_script_hash,
      positions_validator_hash: orders_script_hash,
      positions_asset: long_position_asset,
      positions_asset_amount: 10,
      liquidity_asset: underlying_asset,
      liquidity_asset_amount: 10,
      stable_collateral_asset: collateral_asset,
      stable_collateral_asset_amount: 10,
      strike_collateral_asset,
      strike_collateral_amount: 10,
      entered_earnings_per_share: 0,
      entered_collateral_earnings_per_share: 0,
      stop_loss_amount: 0,
      take_profit_amount: 0,
      order_submission_time: 1751111000,
      validate_pool_ref,
      action: OpenPosition,
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
  enter_positions_mint.mint(params, redeemer, enter_position_policy_id, tx)
}

test test_enter_short_positions_mint() {
  True
}

test test_burn_long_positions_mint() {
  True
}

test test_burn_short_positions_mint() {
  True
}
