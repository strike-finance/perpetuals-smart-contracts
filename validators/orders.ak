use aiken/collection/list
use aiken/collection/pairs
use cardano/address.{Credential, Script}
use cardano/assets.{PolicyId}
use cardano/transaction.{Input, OutputReference, Transaction, find_input}
use orders_utils.{valid_orders, validate_order}
use types.{AddressHash, Asset, OrdersDatum}
use utils.{is_withdrawal}

// Users will be placing their orders here. The funds for their position will be here until the the batcher puts it into the pool.
// When they close their position, their utxo will also be here. 
validator orders(admin_pkh: AddressHash) {
  spend(
    _datum: Option<OrdersDatum>,
    _redeemer: Int,
    own_ref: OutputReference,
    transaction: Transaction,
  ) {
    let signed_by_admin = list.has(transaction.extra_signatories, admin_pkh)
    is_withdrawal(transaction, own_ref) && signed_by_admin
  }

  withdraw(
    redeemer: List<(Int, Int)>,
    credential: Credential,
    transaction: Transaction,
  ) {
    valid_orders(validate_order, redeemer, transaction, admin_pkh)
  }

  else(_) {
    fail
  }
}
