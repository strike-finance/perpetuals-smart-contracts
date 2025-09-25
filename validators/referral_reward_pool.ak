use aiken/collection/dict
// Aiken contract: simple reward pool
// - Owner deposits ADA and assigns rewards
// - Users withdraw their own ADA rewards

use aiken/collection/list
use aiken/interval.{Finite, Interval, IntervalBound}
use cardano/address.{Address, VerificationKey, from_verification_key}
use cardano/assets as assets
// Using pairs list as a map for Address -> Int
use cardano/transaction.{
  InlineDatum, Input, Output, OutputReference, Transaction,
}

// Datum: list of (address, reward) pairs in lovelace
pub type ReferralRewards {
  Rewards(List<(Address, Int)>)
}

// Redeemer: either deposit (by owner) or withdraw (by user)
pub type Redeemer {
  Deposit(List<(Address, Int)>)
  // owner adds rewards
  Withdraw(Address)
}

// user withdraws their reward

// Parameters: owner of the contract
pub type Params {
  owner: Address,
}

// Helper: get value paid to a given address
fn value_paid_to(tx: Transaction, addr: Address) -> Int {
  let outs = list.filter(tx.outputs, fn(o) { o.address == addr })
  list.foldl(
    outs,
    0,
    fn(out, acc) { acc + assets.quantity_of(out.value, "", "") },
  )
}

fn rewards_get(pairs: List<(Address, Int)>, who: Address, default: Int) -> Int {
  list.foldl(
    pairs,
    default,
    fn((addr, v), acc) {
      if addr == who {
        v
      } else {
        acc
      }
    },
  )
}

fn rewards_set(
  pairs: List<(Address, Int)>,
  who: Address,
  value: Int,
) -> List<(Address, Int)> {
  // replace if exists, else append
  let replaced =
    list.map(
      pairs,
      fn((addr, v)) {
        if addr == who {
          (addr, value)
        } else {
          (addr, v)
        }
      },
    )
  let existed = list.any(pairs, fn((addr, _v)) { addr == who })
  if existed {
    replaced
  } else {
    [(who, value), ..replaced]
  }
}

fn rewards_add(
  pairs: List<(Address, Int)>,
  who: Address,
  delta: Int,
) -> List<(Address, Int)> {
  let current = rewards_get(pairs, who, 0)
  rewards_set(pairs, who, current + delta)
}

// Validator
validator reward_pool(params: Params) {
  spend(
    datum: Option<ReferralRewards>,
    redeemer: Redeemer,
    _own_ref: OutputReference,
    tx: Transaction,
  ) {
    when redeemer is {
      Deposit(pairs) -> {
        // Only owner can deposit
        let owner_cred = params.owner.payment_credential
        expect VerificationKey(owner_pkh) = owner_cred
        expect list.has(tx.extra_signatories, owner_pkh)

        // Enforce exactly one continuing output with updated datum and funded value
        let script_inputs = list.filter(tx.inputs, fn(_i) { True })
        expect list.length(script_inputs) == 1

        // Expect exactly one continuing output to this script
        let outputs = tx.outputs
        expect Some(si) = list.head(script_inputs)
        let continuing =
          list.filter(outputs, fn(o) { o.address == si.output.address })
        expect list.length(continuing) == 1
        expect Some(cont) = list.head(continuing)

        // Compute expected updated map and total added lovelace
        expect list.all(pairs, fn((_a, v)) { v >= 0 })
        let added_total = list.foldl(pairs, 0, fn((_a, v), acc) { acc + v })
        expect Some(Rewards(m)) = datum
        let updated_pairs =
          list.foldl(
            pairs,
            m,
            fn((a, v), acc_pairs) { rewards_add(acc_pairs, a, v) },
          )

        // Check output datum matches updated map
        expect InlineDatum(out_datum) = cont.datum
        expect Rewards(out_pairs) = out_datum
        expect out_pairs == updated_pairs

        // Check pool value increased by exactly added_total lovelace
        let in_val = si.output.value
        let out_val = cont.value
        let in_lov = assets.quantity_of(in_val, "", "")
        let out_lov = assets.quantity_of(out_val, "", "")
        out_lov == in_lov + added_total
      }

      Withdraw(user) -> {
        // Check signature
        let user_cred = user.payment_credential
        expect VerificationKey(user_pkh) = user_cred
        expect list.has(tx.extra_signatories, user_pkh)

        // Exactly one script input and one continuing output
        let script_inputs = list.filter(tx.inputs, fn(_i) { True })
        expect list.length(script_inputs) == 1
        expect Some(si_w) = list.head(script_inputs)
        let continuing =
          list.filter(tx.outputs, fn(o) { o.address == si_w.output.address })
        expect list.length(continuing) == 1
        expect Some(cont) = list.head(continuing)

        // Read reward and enforce updated datum (reward set to 0)
        expect Some(Rewards(m)) = datum
        let reward = rewards_get(m, user, 0)
        let can_withdraw = reward > 0

        // Expected updated map
        let updated_pairs = rewards_set(m, user, 0)
        expect InlineDatum(out_datum) = cont.datum
        expect Rewards(out_pairs) = out_datum
        expect out_pairs == updated_pairs

        // User must be paid exactly reward in lovelace in total outputs
        let paid = value_paid_to(tx, user)

        // Pool lovelace must decrease by exactly reward
        let in_lov = assets.quantity_of(si_w.output.value, "", "")
        let out_lov = assets.quantity_of(cont.value, "", "")
        can_withdraw && paid == reward && in_lov == out_lov + reward
      }
    }
  }

  else(_) {
    fail
  }
}

// Tests
test deposit_accumulates_and_updates_datum() {
  let owner_addr = from_verification_key(#"01")

  let params = Params { owner: owner_addr }

  let initial_pairs: List<(Address, Int)> = []
  let datum = Rewards(initial_pairs)

  let script_address = from_verification_key(#"aa")

  let input =
    Input {
      output_reference: OutputReference {
        transaction_id: #"00",
        output_index: 0,
      },
      output: Output {
        address: script_address,
        value: assets.from_lovelace(1_000_000),
        datum: InlineDatum(datum),
        reference_script: None,
      },
    }

  let user_a = from_verification_key(#"a1")
  let user_b = from_verification_key(#"b1")
  let pairs = [(user_a, 100_000), (user_b, 200_000), (user_a, 50_000)]

  let updated_pairs =
    list.foldl(
      pairs,
      initial_pairs,
      fn((addr, v), acc) { rewards_add(acc, addr, v) },
    )

  let continuing_output =
    Output {
      address: script_address,
      value: assets.from_lovelace(1_350_000),
      datum: InlineDatum(Rewards(updated_pairs)),
      reference_script: None,
    }

  let tx =
    Transaction {
      inputs: [input],
      reference_inputs: [],
      outputs: [continuing_output],
      fee: 0,
      mint: assets.zero,
      certificates: [],
      withdrawals: [],
      validity_range: Interval {
        lower_bound: IntervalBound {
          bound_type: Finite(0),
          is_inclusive: False,
        },
        upper_bound: IntervalBound {
          bound_type: Finite(10),
          is_inclusive: False,
        },
      },
      extra_signatories: [#"01"],
      redeemers: [],
      datums: dict.empty,
      id: #"",
      votes: [],
      proposal_procedures: [],
      current_treasury_amount: None,
      treasury_donation: None,
    }

  reward_pool.spend(
    params,
    Some(datum),
    Deposit(pairs),
    input.output_reference,
    tx,
  )
}

test withdraw_pays_user_and_clears_reward() {
  let owner_addr = from_verification_key(#"01")
  let params = Params { owner: owner_addr }

  let script_address = from_verification_key(#"aa")
  let user = from_verification_key(#"a1")

  let initial_pairs = rewards_set([], user, 150_000)
  let datum = Rewards(initial_pairs)

  let input =
    Input {
      output_reference: OutputReference {
        transaction_id: #"00",
        output_index: 0,
      },
      output: Output {
        address: script_address,
        value: assets.from_lovelace(1_000_000),
        datum: InlineDatum(datum),
        reference_script: None,
      },
    }

  let continuing_output =
    Output {
      address: script_address,
      value: assets.from_lovelace(850_000),
      datum: InlineDatum(Rewards(rewards_set(initial_pairs, user, 0))),
      reference_script: None,
    }

  let user_payment =
    Output {
      address: user,
      value: assets.from_lovelace(150_000),
      datum: InlineDatum(datum),
      // datum irrelevant on pubkey output
      reference_script: None,
    }

  let tx =
    Transaction {
      inputs: [input],
      reference_inputs: [],
      outputs: [continuing_output, user_payment],
      fee: 0,
      mint: assets.zero,
      certificates: [],
      withdrawals: [],
      validity_range: Interval {
        lower_bound: IntervalBound {
          bound_type: Finite(0),
          is_inclusive: False,
        },
        upper_bound: IntervalBound {
          bound_type: Finite(10),
          is_inclusive: False,
        },
      },
      extra_signatories: [#"a1"],
      redeemers: [],
      datums: dict.empty,
      id: #"",
      votes: [],
      proposal_procedures: [],
      current_treasury_amount: None,
      treasury_donation: None,
    }

  reward_pool.spend(
    params,
    Some(datum),
    Withdraw(user),
    input.output_reference,
    tx,
  )
}

test withdraw_fails_when_reward_is_zero() {
  let owner_addr = from_verification_key(#"01")
  let params = Params { owner: owner_addr }

  let script_address = from_verification_key(#"aa")
  let user = from_verification_key(#"a1")

  let initial_pairs = rewards_set([], user, 0)
  let datum = Rewards(initial_pairs)

  let input =
    Input {
      output_reference: OutputReference {
        transaction_id: #"00",
        output_index: 0,
      },
      output: Output {
        address: script_address,
        value: assets.from_lovelace(1_000_000),
        datum: InlineDatum(datum),
        reference_script: None,
      },
    }

  // Attempt to withdraw with no reward: keep pool unchanged and pay user 0
  let continuing_output =
    Output {
      address: script_address,
      value: assets.from_lovelace(1_000_000),
      datum: InlineDatum(Rewards(initial_pairs)),
      reference_script: None,
    }

  let user_payment =
    Output {
      address: user,
      value: assets.from_lovelace(0),
      datum: InlineDatum(datum),
      reference_script: None,
    }

  let tx =
    Transaction {
      inputs: [input],
      reference_inputs: [],
      outputs: [continuing_output, user_payment],
      fee: 0,
      mint: assets.zero,
      certificates: [],
      withdrawals: [],
      validity_range: Interval {
        lower_bound: IntervalBound {
          bound_type: Finite(0),
          is_inclusive: False,
        },
        upper_bound: IntervalBound {
          bound_type: Finite(10),
          is_inclusive: False,
        },
      },
      extra_signatories: [#"a1"],
      redeemers: [],
      datums: dict.empty,
      id: #"",
      votes: [],
      proposal_procedures: [],
      current_treasury_amount: None,
      treasury_donation: None,
    }

  reward_pool.spend(
    params,
    Some(datum),
    Withdraw(user),
    input.output_reference,
    tx,
  ) == False
}
