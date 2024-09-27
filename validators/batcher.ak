use aiken/collection/list
use cardano/address.{Credential}
use cardano/assets
use cardano/transaction.{Transaction}
use types.{Asset}

pub type BatcherRedeemer {
  pred_in_idx: Int,
}

validator batcher(prediction_nft: Asset) {
  withdraw(
    redeemer: BatcherRedeemer,
    _own_credential: Credential,
    self: Transaction,
  ) {
    let Transaction { inputs, .. } = self
    expect Some(pred_input) = list.at(inputs, redeemer.pred_in_idx)
    assets.quantity_of(
      pred_input.output.value,
      prediction_nft.policy_id,
      prediction_nft.asset_name,
    ) == 1
  }

  else(_) {
    fail
  }
}
