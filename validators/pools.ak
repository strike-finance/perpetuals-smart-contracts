use aiken/collection/list
use aiken/collection/pairs
use cardano/address.{Credential}
use cardano/assets.{PolicyId}
use cardano/transaction.{OutputReference, Transaction}
use types.{AddressHash, PositionDatum}

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
