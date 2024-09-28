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

pub type PositionType {
  BuyPos
  RewardPos
}

pub type PositionSide {
  SideTrue
  SideFalse
}

pub type PerpetualDatum {
  long_position_amount: Int,
  long_position_mint_amount: Int,
  short_position_amount: Int,
  short_position_mint_amount: Int,
}

pub type PositionDatum {
  owner_address_hash: AddressHash,
  entered_at_price: Int,
  entered_asset: Asset,
  position_amount: Int,
  leverage_amount: Int,
  position: PositionType,
  side: PositionSide,
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
