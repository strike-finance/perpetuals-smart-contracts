use aiken/collection/pairs
use cardano/address.{Credential}
use cardano/transaction.{OutputReference, Transaction}
use types.{PoolDatum}

// All pool validations are passed to the orders script. The orders script handles interactions with the pool UTxO. 
validator pools(orders_stake_cred: Credential) {
  spend(
    _datum: Option<PoolDatum>,
    _redeemer: Int,
    _own_ref: OutputReference,
    transaction: Transaction,
  ) {
    let withdrawals = transaction.withdrawals

    pairs.has_key(withdrawals, orders_stake_cred)
  }

  else(_) {
    False
  }
}
