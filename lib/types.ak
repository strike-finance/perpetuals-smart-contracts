use aiken/hash.{Blake2b_224, Hash}
use aiken/transaction/credential.{VerificationKey}
use aiken/transaction/value.{PolicyId}

pub type AddressHash =
  Hash<Blake2b_224, VerificationKey>

pub type POSIXTime =
  Int

pub type LovelaceAmount =
  Int

pub type PerpetualDatum {
  total_ratio_feed: PolicyId,
  orcfax_price_feed: PolicyId,
  leverage_amount: Int,
  current_funding_round_entry_price: Int,
  current_funding_round_entry_time: POSIXTime,
  current_funding_round_distribute_time: POSIXTime,
  owner_address_hash: AddressHash,
  owner_bech32_address: String,
  position: Int,
}

pub type OrcfaxDatum<t> {
  statement: Statement<t>,
  context: Context,
}

pub type Statement<t> {
  feed_id: ByteArray,
  created_at: POSIXTime,
  body: t,
}

pub type Context {
  collect_after: POSIXTime,
  collector: ByteArray,
}

pub type Price {
  num: Int,
  denom: Int,
}

pub type RationalDatum {
  numerator: Int,
  denominator: Int,
}

pub type ComparePerpetualInfo {
  total_ratio_feed: PolicyId,
  orcfax_price_feed: PolicyId,
  leverage_amount: Int,
  new_balance: Int,
  owner_address_hash: AddressHash,
  owner_bech32_address: String,
  funds_to_distribute: Int,
}
