use aiken/collection/dict
use aiken/collection/pairs
use aiken/interval
use cardano/address.{Script, from_script, from_verification_key}
use cardano/assets
use cardano/transaction.{Input, NoDatum, Output, OutputReference, Transaction}
use test_constants.{orders_script_hash}
use types.{ScriptHash}

pub type LiquidityRedeemer {
  ProvideLiquidity
  BurnLiquidity
}

// Liquidity Providers will be able to provide liquidity by minting lp tokens
// The lp tokens will be sent to the orders script. Once the orders script is done processing the liquidity
// The lp tokens will then be sent to the liquidity provider's wallet. Liquidity Providers has the ability to choose
// to provide liquidity for the long side, short side, or both
validator liquidity_mint(orders_stake_cred: ScriptHash) {
  // Calculations of how much liquidity tokens that should be minted or burnt is off-setted to the orders validator
  mint(_redeemer: Int, _policy_id: ByteArray, transaction: Transaction) {
    let withdrawals = transaction.withdrawals

    let orders_stake_cred_script = from_script(orders_stake_cred)

    pairs.has_key(withdrawals, orders_stake_cred_script.payment_credential)
  }

  else(_) {
    fail
  }
}

test liquidity_mint__mint() {
  let withdrawals = [Pair(Script(orders_script_hash), 1)]

  let own_ref =
    OutputReference {
      transaction_id: #"0000000000000000000000000000000000000000000000000000000000000000",
      output_index: 0,
    }

  let seed_input =
    Input {
      output_reference: own_ref,
      output: Output {
        address: from_verification_key(#""),
        value: assets.from_lovelace(2_000_000),
        datum: NoDatum,
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
  liquidity_mint.mint(
    orders_script_hash,
    1,
    #"0e5306c15911d58f5f3ff9faddcd4e68188551f9a441a539cf842eaf",
    tx,
  )
}
