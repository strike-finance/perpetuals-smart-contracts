use aiken/collection/list
use cardano/assets.{AssetName, PolicyId}
use cardano/transaction.{Input, Output, OutputReference, Transaction}
use types.{PoolDatum}

pub type SettingRedeemer {
  pmanager_in_idx: Int,
}

validator settings(manager_policy_id: PolicyId, manager_asset_name: AssetName) {
  spend(
    _datum: Option<PoolDatum>,
    redeemer: SettingRedeemer,
    _own_ref: OutputReference,
    transaction: Transaction,
  ) {
    let Transaction { inputs, .. } = transaction
    expect Some(pmanager_input) = list.at(inputs, redeemer.pmanager_in_idx)
    assets.quantity_of(
      pmanager_input.output.value,
      manager_policy_id,
      manager_asset_name,
    ) == 1
  }

  else(_) {
    False
  }
}
