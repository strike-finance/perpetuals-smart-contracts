use aiken/collection/list
use aiken/collection/pairs
use cardano/address.{Script}
use cardano/assets.{PolicyId, flatten, match, quantity_of}
use cardano/transaction.{
  InlineDatum, Input, Output, OutputReference, Transaction,
}
use types.{
  PoolDatum, PoolParams, PoolRedeemer, UpdateInterestRate, UpdateLiquidateMargin,
  UpdateMaxLeverageFactor, UpdateMaxStrikeHolderLeverageFactor, UpdateParam,
  UtilizePool,
}
use utils.{get_address_outputs, get_all_validators_inputs}

validator pools(params: PoolParams) {
  spend(
    datum: Option<PoolDatum>,
    redeemer: PoolRedeemer,
    _own_ref: OutputReference,
    transaction: Transaction,
  ) {
    when redeemer.action is {
      UtilizePool -> {
        let withdrawals = transaction.withdrawals

        pairs.has_key(withdrawals, params.orders_stake_cred)
      }
      UpdateParam -> {
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
                underlying_asset_lended_amount: pool_datum.underlying_asset_lended_amount,
                interest_rate: new_value,
                stable_asset: pool_datum.stable_asset,
                max_leverage_factor: pool_datum.max_leverage_factor,
                max_strike_holder_leverage_factor: pool_datum.max_strike_holder_leverage_factor,
                maintain_margin_amount: pool_datum.maintain_margin_amount,
                is_valid_pool_asset: pool_datum.is_valid_pool_asset,
                earnings_per_share: pool_datum.earnings_per_share,
                collateral_earnings_per_share: pool_datum.collateral_earnings_per_share,
              }

            output_datum_typed == expected_datum
          }
          UpdateLiquidateMargin(new_value) -> {
            let expected_datum =
              PoolDatum {
                underlying_asset: pool_datum.underlying_asset,
                underlying_asset_lended_amount: pool_datum.underlying_asset_lended_amount,
                interest_rate: pool_datum.interest_rate,
                stable_asset: pool_datum.stable_asset,
                max_leverage_factor: pool_datum.max_leverage_factor,
                max_strike_holder_leverage_factor: pool_datum.max_strike_holder_leverage_factor,
                maintain_margin_amount: new_value,
                is_valid_pool_asset: pool_datum.is_valid_pool_asset,
                earnings_per_share: pool_datum.earnings_per_share,
                collateral_earnings_per_share: pool_datum.collateral_earnings_per_share,
              }

            output_datum_typed == expected_datum
          }
          UpdateMaxLeverageFactor(new_value) -> {
            let expected_datum =
              PoolDatum {
                underlying_asset: pool_datum.underlying_asset,
                underlying_asset_lended_amount: pool_datum.underlying_asset_lended_amount,
                interest_rate: pool_datum.interest_rate,
                stable_asset: pool_datum.stable_asset,
                max_leverage_factor: new_value,
                max_strike_holder_leverage_factor: pool_datum.max_strike_holder_leverage_factor,
                maintain_margin_amount: pool_datum.maintain_margin_amount,
                is_valid_pool_asset: pool_datum.is_valid_pool_asset,
                earnings_per_share: pool_datum.earnings_per_share,
                collateral_earnings_per_share: pool_datum.collateral_earnings_per_share,
              }

            output_datum_typed == expected_datum
          }
          UpdateMaxStrikeHolderLeverageFactor(new_value) -> {
            let expected_datum =
              PoolDatum {
                underlying_asset: pool_datum.underlying_asset,
                underlying_asset_lended_amount: pool_datum.underlying_asset_lended_amount,
                interest_rate: pool_datum.interest_rate,
                stable_asset: pool_datum.stable_asset,
                max_leverage_factor: pool_datum.max_leverage_factor,
                max_strike_holder_leverage_factor: new_value,
                maintain_margin_amount: pool_datum.maintain_margin_amount,
                is_valid_pool_asset: pool_datum.is_valid_pool_asset,
                earnings_per_share: pool_datum.earnings_per_share,
                collateral_earnings_per_share: pool_datum.collateral_earnings_per_share,
              }

            output_datum_typed == expected_datum
          }
        }
      }
    }
  }

  mint(_redeemer: Int, policy_id: PolicyId, transaction: Transaction) {
    let Transaction { outputs, extra_signatories, mint, .. } = transaction
    let PoolParams { asset_name, admin_pkh, .. } = params

    expect Some(output_back_to_pool_script) =
      list.find(
        outputs,
        fn(output: Output) {
          expect Script(output_to_liquidate_hash) =
            output.address.payment_credential

          output_to_liquidate_hash == policy_id
        },
      )

    let output_contains_pool_asset: Bool =
      quantity_of(output_back_to_pool_script.value, policy_id, asset_name) == 1

    let expected_mint = [(policy_id, params.asset_name, 1)]

    let mint_valid = expected_mint == flatten(mint)

    let signed_by_admin = list.has(extra_signatories, admin_pkh)

    mint_valid && signed_by_admin && output_contains_pool_asset
  }

  else(_) {
    False
  }
}
