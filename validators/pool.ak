use aiken/collection/dict
use aiken/collection/pairs
use aiken/interval
use cardano/address.{Credential, Script, from_verification_key}
use cardano/assets
use cardano/transaction.{
  InlineDatum, Input, Output, OutputReference, Transaction,
}
use test_constants.{orders_script_hash}
use types.{Asset, PoolDatum}

// All pool validations are passed to the orders script. The orders script handles interactions with the pool UTxO. 
validator pool(orders_stake_cred: Credential) {
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

test pool__spend() {
  let withdrawals = [Pair(Script(orders_script_hash), 1)]

  let orders_stake_cred = Script(orders_script_hash)

  let own_ref =
    OutputReference {
      transaction_id: #"0000000000000000000000000000000000000000000000000000000000000000",
      output_index: 0,
    }
  let pool_datum =
    PoolDatum {
      underlying_asset: Asset { policy_id: "", asset_name: "" },
      lp_asset: Asset { policy_id: "", asset_name: "" },
      liquidity_total_asset_amount: 0,
      liquidity_total_gains_losses: 0,
      liquidity_total_lp_minted: 0,
      total_lended_amount: 0,
      batcher_license: "",
    }

  let seed_input =
    Input {
      output_reference: own_ref,
      output: Output {
        address: from_verification_key(#""),
        value: assets.from_lovelace(2_000_000),
        datum: InlineDatum(pool_datum),
        reference_script: None,
      },
    }

  let tx =
    Transaction {
      inputs: [seed_input],
      reference_inputs: [],
      outputs: [],
      fee: 0,
      mint: assets.zero,
      certificates: [],
      withdrawals,
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
  pool.spend(orders_stake_cred, Some(pool_datum), 0, own_ref, tx)
}
