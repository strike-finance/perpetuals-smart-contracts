use aiken/list
use aiken/transaction.{ScriptContext, Spend}
use aiken/transaction/credential.{Address, from_verification_key}
use aiken/transaction/value.{quantity_of}
use types.{PerpetualDatum}
use utils.{get_asset_to_address, get_lower_bound, get_validators_inputs}

type PerpetualsRedeemer {
  UpdateNewFundingRound
  LiquidateCollateral
  ClosePosition
}

type Redeemer {
  action: PerpetualsRedeemer,
}

fn validate_update_new_funding_round() {
  True
}

fn validate_liquidate_collateral() {
  True
}

fn validate_close_position(datum: PerpetualDatum, ctx: ScriptContext) {
  expect Spend(my_output_reference) = ctx.purpose
  expect Some(input_from_validator) =
    ctx.transaction.inputs
      |> transaction.find_input(my_output_reference)

  let asset_amount_in_input: Int =
    quantity_of(
      input_from_validator.output.value,
      datum.position_asset.policy_id,
      datum.position_asset.asset_name,
    )

  let issuer_address: Address = from_verification_key(datum.owner_address_hash)
  let fee: Int =
    quantity_of(
      ctx.transaction.fee,
      datum.position_asset.policy_id,
      datum.position_asset.asset_name,
    )

  let amount_to_issuer: Int =
    get_asset_to_address(
      ctx.transaction.outputs,
      issuer_address,
      datum.position_asset.policy_id,
      datum.position_asset.asset_name,
    )

  let amount_to_owner_valid: Bool =
    asset_amount_in_input - fee == amount_to_issuer

  let only_one_validator_input: Bool =
    list.length(get_validators_inputs(ctx)) == 1

  let must_be_signed_by_owner =
    list.has(ctx.transaction.extra_signatories, datum.owner_address_hash)

  let before_distribute_fund =
    datum.current_funding_round_distribute_time > get_lower_bound(
      ctx.transaction.validity_range,
    )

  ( amount_to_owner_valid || must_be_signed_by_owner ) && only_one_validator_input && before_distribute_fund
}

validator {
  fn spend(
    datum: PerpetualDatum,
    redeemer: Redeemer,
    ctx: ScriptContext,
  ) -> Bool {
    when redeemer.action is {
      UpdateNewFundingRound -> validate_update_new_funding_round()
      LiquidateCollateral -> validate_liquidate_collateral()
      ClosePosition -> validate_close_position(datum, ctx)
    }
  }
}
