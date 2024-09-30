use aiken/collection/pairs
use cardano/address.{Credential}
use cardano/assets.{AssetName, PolicyId}
use cardano/transaction.{OutputReference, Transaction}
use types.{PositionDatum}

// This validator will hold all the the funds for valuation of the users positions. When users close their positions, they will be withdrawing funds from this contract. This is different
// from the funding period validator, which holds the funds for the users inital deposit. This validator is for the potential profit they will have made if their position rosed in value due
// to the rise in the underlying asset. 
validator positions_mint(orders_stake_cred: Credential) {
  mint(
    _datum: Option<PositionDatum>,
    policy_id: PolicyId,
    transaction: Transaction,
  ) {
    True
  }

  else(_) {
    False
  }
}
