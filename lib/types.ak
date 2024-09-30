use aiken/crypto.{Blake2b_224, Hash, Script, VerificationKey}
use cardano/assets.{AssetName, PolicyId}

pub type Asset {
  policy_id: PolicyId,
  asset_name: AssetName,
}

pub type AddressHash =
  Hash<Blake2b_224, VerificationKey>

pub type ScriptHash =
  Hash<Blake2b_224, Script>

pub type POSIXTime =
  Int

pub type LovelaceAmount =
  Int

pub type PositionSide {
  Long
  Short
}

pub type OrderAction {
  OpenPosition
  ClosePosition
  ContributePool
  WithdrawPool
}

pub type PerpetualDatum {
  long_position_amount: Int,
  long_position_mint_amount: Int,
  short_position_amount: Int,
  short_position_mint_amount: Int,
}

pub type OrdersDatum {
  owner_address_hash: AddressHash,
  entered_at_price: Int,
  entered_at_timestamp: POSIXTime,
  entered_asset: Asset,
  position_amount: Int,
  leverage_amount: Int,
  side: PositionSide,
  action: OrderAction,
}

pub type PositionDatum {
  owner_address_hash: AddressHash,
  entered_asset: Asset,
  position_amount: Int,
  leverage_amount: Int,
  stop_loss_amount: Int,
  valid_position_asset: Asset,
  side: PositionSide,
  orders_validator_hash: ScriptHash,
}

pub type FundPeriodDatum {
  current_long_position_amount: Int,
  total_long_position_amount: Int,
  current_short_position_amount: Int,
  total_short_position_amount: Int,
  start_time: POSIXTime,
  end_time: POSIXTime,
  start_price: Int,
}

pub type LeverageDatum {
  position_validator_hash: ByteArray,
}

pub type PositionsRedeemer {
  Close
  StopLoss(Int)
}
