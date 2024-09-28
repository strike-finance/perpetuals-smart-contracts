use cardano/transaction.{OutputReference, Transaction}
use types.{PositionDatum}

validator positions {
  spend(
    _datum: Option<PositionDatum>,
    redeemer: Int,
    _own_ref: OutputReference,
    self: Transaction,
  ) {
    True
  }

  else(_) {
    False
  }
}
