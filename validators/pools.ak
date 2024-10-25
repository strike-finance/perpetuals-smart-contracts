use aiken/collection/list
use aiken/collection/pairs
use cardano/address.{Credential}
use cardano/assets.{PolicyId, Value, match}
use cardano/transaction.{
  InlineDatum, Input, Output, OutputReference, Transaction,
}
use types.{
  AddressHash, PoolDatum, PoolsRedeemer, UpdateInterestRate,
  UpdateLiquidateMargin, UpdateMaxLeverageFactor,
  UpdateMaxStrikeHolderLeverageFactor, UpdateParams, UtilizePool,
}
use utils.{get_address_outputs, get_all_validators_inputs}

validator pools(orders_stake_cred: Credential, admin_pkh: AddressHash) {
  spend(
    datum: Option<PoolDatum>,
    redeemer: PoolsRedeemer,
    _own_ref: OutputReference,
    transaction: Transaction,
  ) {
    when redeemer is {
      UtilizePool -> {
        let withdrawals = transaction.withdrawals

        pairs.has_key(withdrawals, orders_stake_cred)
      }
      UpdateParams(update_type, new_value) -> {
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

        let expected_assets_locked: Value =
          assets.from_asset(
            pool_datum.underlying_asset.policy_id,
            pool_datum.underlying_asset.asset_name,
            pool_datum.underlying_asset_amount,
          )
            |> assets.add(
                pool_datum.stable_collateral_asset.policy_id,
                pool_datum.stable_collateral_asset.asset_name,
                pool_datum.stable_collateral_asset_amount,
              )

        let assets_locked_valid: Bool =
          match(output_to_pools_validator.value, expected_assets_locked, >=)

        let signed_by_admin: Bool =
          list.has(transaction.extra_signatories, admin_pkh)

        expect
          only_one_input_from_script && signed_by_admin && assets_locked_valid

        when update_type is {
          UpdateInterestRate -> {
            let expected_datum =
              PoolDatum {
                underlying_asset: pool_datum.underlying_asset,
                underlying_asset_amount: pool_datum.underlying_asset_amount,
                underlying_asset_lended_amount: pool_datum.underlying_asset_lended_amount,
                underlying_interest_rate: new_value,
                stable_collateral_asset: pool_datum.stable_collateral_asset,
                max_leverage_factor: pool_datum.max_leverage_factor,
                liquidate_margin: pool_datum.liquidate_margin,
                max_strike_holder_leverage_factor: pool_datum.max_strike_holder_leverage_factor,
                maintain_margin_amount: pool_datum.maintain_margin_amount,
                is_valid_pool_asset: pool_datum.is_valid_pool_asset,
                earnings_per_share: pool_datum.earnings_per_share,
                collateral_earnings_per_share: pool_datum.collateral_earnings_per_share,
                stable_collateral_asset_amount: pool_datum.stable_collateral_asset_amount,
              }

            output_datum_typed == expected_datum
          }
          UpdateLiquidateMargin -> {
            let expected_datum =
              PoolDatum {
                underlying_asset: pool_datum.underlying_asset,
                underlying_asset_amount: pool_datum.underlying_asset_amount,
                underlying_asset_lended_amount: pool_datum.underlying_asset_lended_amount,
                underlying_interest_rate: pool_datum.underlying_interest_rate,
                stable_collateral_asset: pool_datum.stable_collateral_asset,
                max_leverage_factor: pool_datum.max_leverage_factor,
                liquidate_margin: new_value,
                max_strike_holder_leverage_factor: pool_datum.max_strike_holder_leverage_factor,
                maintain_margin_amount: pool_datum.maintain_margin_amount,
                is_valid_pool_asset: pool_datum.is_valid_pool_asset,
                earnings_per_share: pool_datum.earnings_per_share,
                collateral_earnings_per_share: pool_datum.collateral_earnings_per_share,
                stable_collateral_asset_amount: pool_datum.stable_collateral_asset_amount,
              }

            output_datum_typed == expected_datum
          }
          UpdateMaxLeverageFactor -> {
            let expected_datum =
              PoolDatum {
                underlying_asset: pool_datum.underlying_asset,
                underlying_asset_amount: pool_datum.underlying_asset_amount,
                underlying_asset_lended_amount: pool_datum.underlying_asset_lended_amount,
                underlying_interest_rate: pool_datum.underlying_interest_rate,
                stable_collateral_asset: pool_datum.stable_collateral_asset,
                max_leverage_factor: new_value,
                liquidate_margin: pool_datum.liquidate_margin,
                max_strike_holder_leverage_factor: pool_datum.max_strike_holder_leverage_factor,
                maintain_margin_amount: pool_datum.maintain_margin_amount,
                is_valid_pool_asset: pool_datum.is_valid_pool_asset,
                earnings_per_share: pool_datum.earnings_per_share,
                collateral_earnings_per_share: pool_datum.collateral_earnings_per_share,
                stable_collateral_asset_amount: pool_datum.stable_collateral_asset_amount,
              }

            output_datum_typed == expected_datum
          }
          UpdateMaxStrikeHolderLeverageFactor -> {
            let expected_datum =
              PoolDatum {
                underlying_asset: pool_datum.underlying_asset,
                underlying_asset_amount: pool_datum.underlying_asset_amount,
                underlying_asset_lended_amount: pool_datum.underlying_asset_lended_amount,
                underlying_interest_rate: pool_datum.underlying_interest_rate,
                stable_collateral_asset: pool_datum.stable_collateral_asset,
                max_leverage_factor: pool_datum.max_leverage_factor,
                liquidate_margin: pool_datum.liquidate_margin,
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
    list.has(transaction.extra_signatories, admin_pkh)
  }

  else(_) {
    False
  }
}
