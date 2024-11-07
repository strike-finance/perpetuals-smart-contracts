use aiken/collection/list
use aiken/collection/pairs
use cardano/assets.{PolicyId, match}
use cardano/transaction.{
  InlineDatum, Input, Output, OutputReference, Transaction,
}
use types.{
  PoolDatum, PoolsParams, PoolsRedeemer, UpdateInterestRate,
  UpdateLiquidateMargin, UpdateMaxLeverageFactor,
  UpdateMaxStrikeHolderLeverageFactor, UpdateParams, UtilizePool,
}
use utils.{get_address_outputs, get_all_validators_inputs}

validator pools(params: PoolsParams) {
  spend(
    datum: Option<PoolDatum>,
    redeemer: PoolsRedeemer,
    _own_ref: OutputReference,
    transaction: Transaction,
  ) {
    when redeemer.action is {
      UtilizePool -> {
        let withdrawals = transaction.withdrawals

        pairs.has_key(withdrawals, params.orders_stake_cred)
      }
      UpdateParams -> {
        expect Some(pool_datum) = datum

        let inputs_from_scripts: List<Input> =
          get_all_validators_inputs(transaction)

        let only_one_input_from_script: Bool =
          list.length(inputs_from_scripts) == 1

        expect Some(input_from_script) = list.head(inputs_from_scripts)

        let outputs_back_to_pools_validator: List<Output> =
          get_address_outputs(transaction, input_from_script.output.address)

        expect Some(output_to_pools_validator) =
          list.head(outputs_back_to_pools_validator)

        expect InlineDatum(output_datum) = output_to_pools_validator.datum
        expect output_datum_typed: PoolDatum = output_datum

        let assets_locked_valid: Bool =
          match(
            output_to_pools_validator.value,
            input_from_script.output.value,
            >=,
          )

        let signed_by_admin: Bool =
          list.has(transaction.extra_signatories, params.admin_pkh)

        expect
          only_one_input_from_script && signed_by_admin && assets_locked_valid

        when redeemer.update_param_type is {
          UpdateInterestRate(new_value) -> {
            let expected_datum =
              PoolDatum {
                underlying_asset: pool_datum.underlying_asset,
                underlying_asset_amount: pool_datum.underlying_asset_amount,
                underlying_asset_lended_amount: pool_datum.underlying_asset_lended_amount,
                underlying_interest_rate: new_value,
                stable_collateral_asset: pool_datum.stable_collateral_asset,
                max_leverage_factor: pool_datum.max_leverage_factor,
                margin_requirement: pool_datum.margin_requirement,
                max_strike_holder_leverage_factor: pool_datum.max_strike_holder_leverage_factor,
                maintain_margin_amount: pool_datum.maintain_margin_amount,
                is_valid_pool_asset: pool_datum.is_valid_pool_asset,
                earnings_per_share: pool_datum.earnings_per_share,
                collateral_earnings_per_share: pool_datum.collateral_earnings_per_share,
                stable_collateral_asset_amount: pool_datum.stable_collateral_asset_amount,
              }

            output_datum_typed == expected_datum
          }
          UpdateLiquidateMargin(new_value) -> {
            let expected_datum =
              PoolDatum {
                underlying_asset: pool_datum.underlying_asset,
                underlying_asset_amount: pool_datum.underlying_asset_amount,
                underlying_asset_lended_amount: pool_datum.underlying_asset_lended_amount,
                underlying_interest_rate: pool_datum.underlying_interest_rate,
                stable_collateral_asset: pool_datum.stable_collateral_asset,
                max_leverage_factor: pool_datum.max_leverage_factor,
                margin_requirement: new_value,
                max_strike_holder_leverage_factor: pool_datum.max_strike_holder_leverage_factor,
                maintain_margin_amount: pool_datum.maintain_margin_amount,
                is_valid_pool_asset: pool_datum.is_valid_pool_asset,
                earnings_per_share: pool_datum.earnings_per_share,
                collateral_earnings_per_share: pool_datum.collateral_earnings_per_share,
                stable_collateral_asset_amount: pool_datum.stable_collateral_asset_amount,
              }

            output_datum_typed == expected_datum
          }
          UpdateMaxLeverageFactor(new_value) -> {
            let expected_datum =
              PoolDatum {
                underlying_asset: pool_datum.underlying_asset,
                underlying_asset_amount: pool_datum.underlying_asset_amount,
                underlying_asset_lended_amount: pool_datum.underlying_asset_lended_amount,
                underlying_interest_rate: pool_datum.underlying_interest_rate,
                stable_collateral_asset: pool_datum.stable_collateral_asset,
                max_leverage_factor: new_value,
                margin_requirement: pool_datum.margin_requirement,
                max_strike_holder_leverage_factor: pool_datum.max_strike_holder_leverage_factor,
                maintain_margin_amount: pool_datum.maintain_margin_amount,
                is_valid_pool_asset: pool_datum.is_valid_pool_asset,
                earnings_per_share: pool_datum.earnings_per_share,
                collateral_earnings_per_share: pool_datum.collateral_earnings_per_share,
                stable_collateral_asset_amount: pool_datum.stable_collateral_asset_amount,
              }

            output_datum_typed == expected_datum
          }
          UpdateMaxStrikeHolderLeverageFactor(new_value) -> {
            let expected_datum =
              PoolDatum {
                underlying_asset: pool_datum.underlying_asset,
                underlying_asset_amount: pool_datum.underlying_asset_amount,
                underlying_asset_lended_amount: pool_datum.underlying_asset_lended_amount,
                underlying_interest_rate: pool_datum.underlying_interest_rate,
                stable_collateral_asset: pool_datum.stable_collateral_asset,
                max_leverage_factor: pool_datum.max_leverage_factor,
                margin_requirement: pool_datum.margin_requirement,
                max_strike_holder_leverage_factor: new_value,
                maintain_margin_amount: pool_datum.maintain_margin_amount,
                is_valid_pool_asset: pool_datum.is_valid_pool_asset,
                earnings_per_share: pool_datum.earnings_per_share,
                collateral_earnings_per_share: pool_datum.collateral_earnings_per_share,
                stable_collateral_asset_amount: pool_datum.stable_collateral_asset_amount,
              }

            output_datum_typed == expected_datum
          }
        }
      }
    }
  }

  mint(_redeemer: Int, _policy_id: PolicyId, transaction: Transaction) {
    list.has(transaction.extra_signatories, params.admin_pkh)
  }

  else(_) {
    False
  }
}
