use aiken/transaction.{ScriptContext}
use types.{DistributeDatum}

validator {
  fn spend(datum: DistributeDatum, _redeemer: Int, ctx: ScriptContext) -> Bool {
    True
  }
}
