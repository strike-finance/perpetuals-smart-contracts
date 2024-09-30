use cardano/address.{StakeCredential}
use cardano/assets.{AssetName, PolicyId}
use cardano/transaction.{OutputReference, Transaction}
use positions_utils.{validate_close_position}
use types.{
  Close, ClosePosition, OpenPosition, PositionDatum, PositionsRedeemer, StopLoss,
}

// This validator handles all logic regarding the users positions. They will be able to open and close their positions here. 
validator positions {
  spend(
    datum: Option<PositionDatum>,
    redeemer: PositionsRedeemer,
    own_ref: OutputReference,
    transaction: Transaction,
  ) {
    when redeemer is {
      Close -> validate_close_position(transaction, own_ref, datum)
      StopLoss -> True
    }
  }

  else(_) {
    False
  }
}
