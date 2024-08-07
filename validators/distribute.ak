use aiken/list
use aiken/transaction.{ScriptContext}
use types.{DistributeDatum, POSIXTime}
use utils.{get_lower_bound}

validator(time: POSIXTime) {
  fn spend(datum: DistributeDatum, _redeemer: Int, ctx: ScriptContext) -> Bool {
    True
  }
}
