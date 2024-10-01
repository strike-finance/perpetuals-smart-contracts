use aiken/collection/list
use aiken/collection/pairs
use cardano/address.{Credential, Script}
use cardano/assets.{PolicyId}
use cardano/transaction.{Input, OutputReference, Transaction, find_input}
use orders_utils.{cancel_open_position_order, valid_orders, validate_order}
use types.{
  AddressHash, Asset, BatchOrders, CancelOrders, ClosePosition,
  ContributeLiquidity, OpenPosition, OrdersDatum, OrdersRedeemer,
  WithdrawLiquidity,
}
use utils.{is_withdrawal}

// Users will be placing their orders here. The funds for their position will be here until the the batcher puts it into the pool.
// When they close their position, their utxo will also be here. 
validator orders(admin_pkh: AddressHash) {
  spend(
    datum: Option<OrdersDatum>,
    redeemer: OrdersRedeemer,
    own_ref: OutputReference,
    transaction: Transaction,
  ) {
    when redeemer is {
      BatchOrders -> {
        let signed_by_admin = list.has(transaction.extra_signatories, admin_pkh)
        is_withdrawal(transaction, own_ref) && signed_by_admin
      }
      CancelOrders -> {
        expect Some(datum) = datum
        expect list.has(transaction.extra_signatories, datum.owner_address_hash)

        when datum.action is {
          OpenPosition -> cancel_open_position_order(datum, transaction)
          ClosePosition -> {
            let signed_by_owner =
              list.has(transaction.extra_signatories, datum.owner_address_hash)
            signed_by_owner
          }
          ContributeLiquidity -> {
            let signed_by_owner =
              list.has(transaction.extra_signatories, datum.owner_address_hash)
            signed_by_owner
          }
          WithdrawLiquidity -> {
            let signed_by_owner =
              list.has(transaction.extra_signatories, datum.owner_address_hash)
            signed_by_owner
          }
        }
      }
    }
  }

  withdraw(
    redeemer: List<(Int, Int)>,
    _credential: Credential,
    transaction: Transaction,
  ) {
    valid_orders(validate_order, redeemer, transaction, admin_pkh)
  }

  else(_) {
    fail
  }
}
