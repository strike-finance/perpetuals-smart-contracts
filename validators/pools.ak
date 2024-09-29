use cardano/transaction.{OutputReference, Transaction}
use types.{PositionDatum}


// This validator will hold all the the funds for valuation of the users positions. When users close their positions, they will be withdrawing funds from this contract. This is different
// from the funding period validator, which holds the funds for the users inital deposit. This validator is for the potential profit they will have made if their position rosed in value due
// to the rise in the underlying asset.  
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
