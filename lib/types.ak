use aiken/hash.{Blake2b_224, Hash}
use aiken/transaction/credential.{VerificationKey}
use aiken/transaction/value.{AssetName, PolicyId}

pub type AssetClass {
  policy_id: PolicyId,
  asset_name: AssetName,
}

pub type AddressHash =
  Hash<Blake2b_224, VerificationKey>

pub type POSIXTime =
  Int

pub type LovelaceAmount =
  Int

pub type PerpetualDatum {
  total_ratio_feed: PolicyId,
  orcfax_price_feed: PolicyId,
  leverage: Int,
  current_funding_round_entry_price: LovelaceAmount,
  current_funding_round_entry_time: POSIXTime,
  current_funding_round_distribute_time: POSIXTime,
  owner_address_hash: AddressHash,
}

pub type Statement<t> {
  feed_id: ByteArray,
  created_at: Int,
  body: t,
}

/// Used by orcfax validator
pub type Context {
  collect_after: Int,
  collector: ByteArray,
}

// Pkh
pub type Price {
  num: Int,
  denom: Int,
}
