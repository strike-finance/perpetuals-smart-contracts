use cardano/address.{StakeCredential}
use cardano/assets.{AssetName, PolicyId}
use cardano/transaction.{OutputReference, Transaction}
use types.{
  Close, ClosePosition, OpenPosition, PositionDatum, PositionsRedeemer, StopLoss,
}

// This validator handles all logic regarding the users positions. They will be able to open and close their positions here. 
validator positions {
  spend(
    _datum: Option<PositionDatum>,
    redeemer: PositionsRedeemer,
    _own_ref: OutputReference,
    self: Transaction,
  ) {
    when redeemer is {
      Close -> True
      StopLoss -> True
    }
  }

  else(_) {
    False
  }
}
