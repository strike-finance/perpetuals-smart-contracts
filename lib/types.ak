use aiken/crypto.{Blake2b_224, Hash, VerificationKey}
use cardano/assets.{AssetName, PolicyId}

pub type Asset {
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
  long_position_amount: Int,
  long_position_mint_amount: Int,
  short_position_amount: Int,
  short_position_mint_amount: Int,
}

pub type PositionDatum {
  owner_address_hash: AddressHash,
  position_amount: Int,
  leverage_amount: Int,
  mint_policy_id: PolicyId,
  mint_asset_name: AssetName,
  perpetual_validator_hash: ByteArray,
}

pub type LeverageDatum {
  position_validator_hash: ByteArray,
}

pub type PositionsRedeemer {
  FoldPositions
}

pub type PoolRedeemer {
  OpenPosition
  ClosePosition
}
