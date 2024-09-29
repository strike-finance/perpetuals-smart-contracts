use cardano/transaction.{OutputReference, Transaction}
use types.{PositionDatum}


// This validator handles the logic of funding periods. It reallocates the losing sides postions to the winning sides positions every funding period. 
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
