use aiken/collection/dict
use aiken/collection/list
use aiken/interval
use cardano/address.{from_script}
use cardano/assets.{AssetName, PolicyId}
use cardano/transaction.{
  InlineDatum, Input, NoDatum, Output, OutputReference, Transaction,
}
use constants.{manager_nft_asset_name}
use test_constants.{protocol_nft_policy_id}
use types.{SettingsDatum}

pub type SettingRedeemer {
  manager_in_idx: Int,
}

validator settings(manager_policy_id: PolicyId, manager_asset_name: AssetName) {
  spend(
    _datum: Option<SettingsDatum>,
    redeemer: SettingRedeemer,
    _own_ref: OutputReference,
    transaction: Transaction,
  ) {
    let Transaction { inputs, .. } = transaction
    expect Some(pmanager_input) = list.at(inputs, redeemer.manager_in_idx)
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

test protocol_settings__spend() {
  let psetting_datum =
    SettingsDatum {
      interest_rate: 100_000_000,
      max_leverage_factor: 100_000_000,
      maintain_margin_amount: 100_000_000,
      max_position_usd_value: 1_000_000_000,
      min_position_usd_value: 100_000_000,
    }
  let psetting_ref =
    OutputReference {
      transaction_id: #"b4971034feee28d07f157faf99b850",
      output_index: 0,
    }
  let psetting_input =
    Input {
      output_reference: psetting_ref,
      output: Output {
        address: from_script(#"11"),
        value: assets.zero
          |> assets.add(protocol_nft_policy_id, manager_nft_asset_name, 1),
        datum: InlineDatum(psetting_datum),
        reference_script: None,
      },
    }
  let pmanager_out_ref =
    OutputReference {
      transaction_id: #"b4971034feee28d07f157faf99b850f856d8da3494c70b19b521cfe690258e26",
      output_index: 0,
    }
  let pmanager_input =
    Input {
      output_reference: pmanager_out_ref,
      output: Output {
        address: from_script(#""),
        value: assets.from_lovelace(2_000_000)
          |> assets.add(protocol_nft_policy_id, manager_nft_asset_name, 1),
        datum: NoDatum,
        reference_script: None,
      },
    }
  let psetting_redeemer = SettingRedeemer { manager_in_idx: 1 }
  let tx =
    Transaction {
      inputs: [psetting_input, pmanager_input],
      reference_inputs: [],
      outputs: [],
      fee: 0,
      mint: assets.zero,
      certificates: [],
      withdrawals: [],
      validity_range: interval.everything,
      extra_signatories: [],
      redeemers: [],
      datums: dict.empty,
      id: #"0000000000000000000000000000000000000000000000000000000000000000",
      votes: [],
      proposal_procedures: [],
      current_treasury_amount: None,
      treasury_donation: None,
    }
  settings.spend(
    protocol_nft_policy_id,
    manager_nft_asset_name,
    Some(psetting_datum),
    psetting_redeemer,
    psetting_ref,
    tx,
  )
}
