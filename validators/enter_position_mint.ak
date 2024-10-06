use aiken/collection/list
use cardano/assets.{PolicyId, quantity_of}
use cardano/transaction.{
  InlineDatum, Input, OutputReference, Transaction, find_script_outputs,
}
use types.{
  BurnLong, BurnShort, MintLong, MintShort, OrdersDatum, PoolDatum,
  PositionsMintRedeemer,
}
use utils.{validate_token_mint}

validator enter_positions_mint(
  orders_validator: ByteArray,
  long_asset_name: ByteArray,
  short_asset_name: ByteArray,
  validate_pool_ref: OutputReference,
) {
  mint(
    redeemer: PositionsMintRedeemer,
    policy_id: PolicyId,
    transaction: Transaction,
  ) {
    when redeemer is {
      MintLong -> {
        let outputs_to_orders_address =
          find_script_outputs(transaction.outputs, orders_validator)

        let only_one_output_to_orders =
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
              ref_input.output_reference == validate_pool_ref
            },
          )

        expect InlineDatum(pool_ref_datum) = pool_ref_input.output.datum
        expect pool_ref_datum_typed: PoolDatum = pool_ref_datum

        let valid_pool_ref =
          orders_datum_typed.validate_pool_ref == validate_pool_ref

        let contains_strike_collateral =
          quantity_of(
            output_to_orders_validator.value,
            orders_datum_typed.strike_collateral_asset.policy_id,
            orders_datum_typed.strike_collateral_asset.asset_name,
          ) > 0

        let earnings_per_share_valid =
          orders_datum_typed.entered_earnings_per_share == pool_ref_datum_typed.earnings_per_share && orders_datum_typed.entered_collateral_earnings_per_share == pool_ref_datum_typed.collateral_earnings_per_share

        expect
          only_one_output_to_orders && valid_pool_ref && earnings_per_share_valid

        if contains_strike_collateral {
          let collateral_asset_deposited_amount =
            quantity_of(
              output_to_orders_validator.value,
              orders_datum_typed.underlying_asset.policy_id,
              orders_datum_typed.underlying_asset.asset_name,
            ) * orders_datum_typed.leverage_factor

          let leverage_factor_valid =
            pool_ref_datum_typed.max_strike_holder_leverage_factor >= orders_datum_typed.leverage_factor

          let expected_mint =
            (policy_id, long_asset_name, collateral_asset_deposited_amount)

          let mint_valid = validate_token_mint(transaction.mint, expected_mint)

          leverage_factor_valid && mint_valid
        } else {
          let collateral_asset_deposited_amount =
            quantity_of(
              output_to_orders_validator.value,
              orders_datum_typed.underlying_asset.policy_id,
              orders_datum_typed.underlying_asset.asset_name,
            ) * orders_datum_typed.leverage_factor

          let leverage_factor_valid =
            pool_ref_datum_typed.max_leverage_factor >= orders_datum_typed.leverage_factor

          let expected_mint =
            (policy_id, long_asset_name, collateral_asset_deposited_amount)

          let mint_valid = validate_token_mint(transaction.mint, expected_mint)

          leverage_factor_valid && mint_valid
        }
      }

      MintShort(current_price) -> {
        let outputs_to_orders_address =
          find_script_outputs(transaction.outputs, orders_validator)

        let only_one_output_to_orders =
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
              ref_input.output_reference == validate_pool_ref
            },
          )

        expect InlineDatum(pool_ref_datum) = pool_ref_input.output.datum
        expect pool_ref_datum_typed: PoolDatum = pool_ref_datum

        let valid_pool_ref =
          orders_datum_typed.validate_pool_ref == validate_pool_ref

        let contains_strike_collateral =
          quantity_of(
            output_to_orders_validator.value,
            orders_datum_typed.strike_collateral_asset.policy_id,
            orders_datum_typed.strike_collateral_asset.asset_name,
          ) > 0

        let earnings_per_share_valid =
          orders_datum_typed.entered_earnings_per_share == pool_ref_datum_typed.earnings_per_share && orders_datum_typed.entered_collateral_earnings_per_share == pool_ref_datum_typed.collateral_earnings_per_share

        expect
          only_one_output_to_orders && valid_pool_ref && earnings_per_share_valid

        if contains_strike_collateral {
          let expected_usd_collateral =
            orders_datum_typed.positions_asset_amount * current_price * orders_datum_typed.leverage_factor

          let collateral_asset_deposited_amount =
            quantity_of(
              output_to_orders_validator.value,
              orders_datum_typed.stable_collateral_asset.policy_id,
              orders_datum_typed.stable_collateral_asset.asset_name,
            ) * orders_datum_typed.leverage_factor

          let leverage_factor_valid =
            pool_ref_datum_typed.max_strike_holder_leverage_factor >= orders_datum_typed.leverage_factor

          let expected_mint =
            (policy_id, long_asset_name, collateral_asset_deposited_amount)

          let mint_valid = validate_token_mint(transaction.mint, expected_mint)

          let expected_usd_collateral_valid =
            collateral_asset_deposited_amount >= expected_usd_collateral

          expected_usd_collateral_valid && leverage_factor_valid && mint_valid
        } else {
          let expected_usd_collateral =
            orders_datum_typed.positions_asset_amount * current_price * orders_datum_typed.leverage_factor

          let collateral_asset_deposited_amount =
            quantity_of(
              output_to_orders_validator.value,
              orders_datum_typed.stable_collateral_asset.policy_id,
              orders_datum_typed.stable_collateral_asset.asset_name,
            ) * orders_datum_typed.leverage_factor

          let leverage_factor_valid =
            pool_ref_datum_typed.max_leverage_factor >= orders_datum_typed.leverage_factor

          let expected_mint =
            (policy_id, long_asset_name, collateral_asset_deposited_amount)

          let mint_valid = validate_token_mint(transaction.mint, expected_mint)

          let expected_usd_collateral_valid =
            collateral_asset_deposited_amount >= expected_usd_collateral

          expected_usd_collateral_valid && leverage_factor_valid && mint_valid
        }
      }
      BurnLong -> quantity_of(transaction.mint, policy_id, long_asset_name) < 0
      BurnShort ->
        quantity_of(transaction.mint, policy_id, short_asset_name) < 0
    }
  }

  else(_) {
    False
  }
}
