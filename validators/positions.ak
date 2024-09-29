use cardano/transaction.{OutputReference, Transaction}
use types.{PositionDatum}




// This validator handles all logic regarding the users positions. They will be able to open and close their positions here. 
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
