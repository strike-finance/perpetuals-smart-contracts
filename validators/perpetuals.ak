use aiken/list
use aiken/transaction.{ScriptContext}
use types.{PerpetualDatum}
use utils.{get_lower_bound}

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

// signed by issuer, cannot close when funds are being distributed
fn validate_close_position(datum: PerpetualDatum, ctx: ScriptContext) {
  let must_be_signed_by_owner =
    list.has(ctx.transaction.extra_signatories, datum.owner_address_hash)

  let before_distribute_fund =
    datum.current_funding_round_distribute_time > get_lower_bound(
      ctx.transaction.validity_range,
    )

  must_be_signed_by_owner && before_distribute_fund
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
