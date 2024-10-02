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
  ContributeLiquidity
  WithdrawLiquidity
}

pub type OrdersRedeemer {
  BatchOrders
  CancelOrders
}

pub type PositionsRedeemer {
  Close
  StopLoss(Int)
  PayLend(Int)
}

pub type RedeemerIndexer =
  List<(Int, Int)>

pub type OrdersWithdrawRedeemer {
  indexer: RedeemerIndexer,
  current_price: Int,
}

pub type OrdersDatum {
  owner_address_hash: AddressHash,
  entered_at_price: Int,
  underlying_asset: Asset,
  position_amount: Int,
  leverage_factor: Int,
  positions_validator_hash: ScriptHash,
  positions_asset: Asset,
  orders_validator_hash: ScriptHash,
  stop_loss_amount: Int,
  side: PositionSide,
  action: OrderAction,
  liquidity_asset: Asset,
  liquidity_amount: Int,
  order_submission_time: POSIXTime,
  collateral_asset: Asset,
  collateral_amount: Int,
}

pub type PositionDatum {
  owner_address_hash: AddressHash,
  entered_at_price: Int,
  underlying_asset: Asset,
  position_amount: Int,
  leverage_factor: Int,
  stop_loss_amount: Int,
  positions_asset: Asset,
  side: PositionSide,
  entry_time: POSIXTime,
  collateral_asset: Asset,
  collateral_amount: Int,
}

pub type PoolDatum {
  pool_asset: Asset,
  pool_asset_amount: Int,
  pooled_interest_rate: Int,
  collateral_asset: Asset,
  max_leverage_amount: Int,
  max_strike_holder_leverage_amount: Int,
  maintain_margin_amount: Int,
  liquidity_asset: Asset,
}

pub type PositionsMintRedeemer {
  Mint
  Burn
}
