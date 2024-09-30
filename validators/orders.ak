use aiken/collection/list
use aiken/collection/pairs
use cardano/address.{Credential, Script}
use cardano/assets.{PolicyId}
use cardano/transaction.{Input, OutputReference, Transaction, find_input}
use types.{Asset, OrdersDatum}
use utils.{is_withdrawal}

// Users will be placing their orders here. The funds for their position will be here until the the batcher puts it into the pool.
// When they close their position, their utxo will also be here. 
validator orders {
  spend(
    _datum: Option<OrdersDatum>,
    _redeemer: Int,
    own_ref: OutputReference,
    transaction: Transaction,
  ) {
    is_withdrawal(transaction, own_ref)
  }

  withdraw(
    redeemer: List<(Int, Int)>,
    credential: Credential,
    transaction: Transaction,
  ) {
    True
  }

  // check for valid orders or else it will be expensive to look through it all in the off-chain
  mint(redeemer: Int, policy_id: PolicyId, transaction: Transaction) {
    True
  }

  else(_) {
    fail
  }
}
