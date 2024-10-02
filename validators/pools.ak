use aiken/collection/list
use aiken/collection/pairs
use cardano/address.{Credential}
use cardano/assets.{PolicyId}
use cardano/transaction.{OutputReference, Transaction}
use types.{AddressHash, PositionDatum}

// This validator will hold all the the funds for valuation of the users positions. When users close their positions, they will be withdrawing funds from this contract. This is different
// from the funding period validator, which holds the funds for the users inital deposit. This validator is for the potential profit they will have made if their position rosed in value due
// to the rise in the underlying asset. 
validator pools(orders_stake_cred: Credential, admin_pkh: AddressHash) {
  spend(
    _datum: Option<PositionDatum>,
    _redeemer: Int,
    _own_ref: OutputReference,
    transaction: Transaction,
  ) {
    let withdrawals = transaction.withdrawals

    pairs.has_key(withdrawals, orders_stake_cred)
  }

  mint(_redeemer: Int, _policy_id: PolicyId, transaction: Transaction) {
    list.has(transaction.extra_signatories, admin_pkh)
  }

  else(_) {
    False
  }
}
