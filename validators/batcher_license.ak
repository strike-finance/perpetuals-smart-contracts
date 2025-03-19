use aiken/collection/list
use cardano/assets.{AssetName, PolicyId, flatten}
use cardano/transaction.{Transaction}

pub type LicenseRedeemer {
  deadline: ByteArray,
  protocol_manager_in_idx: Int,
}

// Checks that the protocol auth is in the input, can only mint batcher license if it is
validator batcher_license(
  auth_policy_id: PolicyId,
  auth_asset_name: AssetName,
) {
  mint(redeemer: LicenseRedeemer, policy_id: ByteArray, self: Transaction) {
    let Transaction { inputs, mint, .. } = self
    expect Some(protocol_manager_input) =
      list.at(inputs, redeemer.protocol_manager_in_idx)
    expect
      assets.quantity_of(
        protocol_manager_input.output.value,
        auth_policy_id,
        auth_asset_name,
      ) == 1

    flatten(mint) == [(policy_id, redeemer.deadline, 1)]
  }

  else(_) {
    fail
  }
}
