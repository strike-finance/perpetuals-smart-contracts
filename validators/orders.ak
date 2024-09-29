use aiken/collection/list
use cardano/address.{Credential}
use cardano/assets
use cardano/transaction.{OutputReference, Transaction}
use types.{Asset, OrdersDatum}

pub type BatcherRedeemer {
  pred_in_idx: Int,
}

// Users will be placing their orders here. The funds for their position will be here until the the batcher puts it into the pool.
// When they close their position, their utxo will also be here. 
validator orders(position_nft: Asset) {
  spend(
    _datum: Option<OrdersDatum>,
    redeemer: Int,
    _own_ref: OutputReference,
    self: Transaction,
  ) {
    True
  }

  withdraw(
    redeemer: BatcherRedeemer,
    _own_credential: Credential,
    self: Transaction,
  ) {
    let Transaction { inputs, .. } = self
    expect Some(pred_input) = list.at(inputs, redeemer.pred_in_idx)
    assets.quantity_of(
      pred_input.output.value,
      position_nft.policy_id,
      position_nft.asset_name,
    ) == 1
  }

  else(_) {
    fail
  }
}
