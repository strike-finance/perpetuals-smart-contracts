use aiken/crypto.{Blake2b_224, Hash, Script, VerificationKey}
use cardano/assets.{AssetName, PolicyId}
use cardano/transaction.{OutputReference}

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

pub type PositionsMintRedeemer {
  Mint
  Burn
}

pub type OrdersDatum {
  owner_address_hash: AddressHash,
  entered_at_price: Int,
  underlying_asset: Asset,
  leverage_factor: Int,
  orders_validator_hash: ScriptHash,
  positions_validator_hash: ScriptHash,
  positions_asset: Asset,
  position_amount: Int,
  liquidity_asset: Asset,
  liquidity_amount: Int,
  collateral_asset: Asset,
  collateral_amount: Int,
  stop_loss_amount: Int,
  take_profit_amount: Int,
  order_submission_time: POSIXTime,
  validate_pool_ref: OutputReference,
  action: OrderAction,
  side: PositionSide,
}

pub type PositionDatum {
  owner_address_hash: AddressHash,
  entered_at_price: Int,
  underlying_asset: Asset,
  leverage_factor: Int,
  position_amount: Int,
  collateral_asset: Asset,
  collateral_amount: Int,
  stop_loss_amount: Int,
  take_profit_amount: Int,
  positions_asset: Asset,
  last_pay_lend_time: POSIXTime,
  validate_pool_ref: OutputReference,
  side: PositionSide,
}

pub type PoolDatum {
  pool_asset: Asset,
  pool_asset_amount: Int,
  pool_asset_lended_amount: Int,
  pooled_interest_rate: Int,
  collateral_asset: Asset,
  max_leverage_amount: Int,
  max_strike_holder_leverage_amount: Int,
  maintain_margin_amount: Int,
  liquidity_asset: Asset,
  earnings_per_share: Int,
  collateral_earnings_per_share: Int,
}
