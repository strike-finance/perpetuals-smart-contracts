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
  MintLong
  MintShort(Int)
  BurnLong
  BurnShort
}

pub type OrdersDatum {
  owner_address_hash: AddressHash,
  entered_at_price: Int,
  underlying_asset: Asset,
  underlying_amount: Int,
  leverage_factor: Int,
  orders_validator_hash: ScriptHash,
  positions_validator_hash: ScriptHash,
  positions_asset: Asset,
  positions_asset_amount: Int,
  liquidity_asset: Asset,
  liquidity_asset_amount: Int,
  stable_collateral_asset: Asset,
  stable_collateral_amount: Int,
  strike_collateral_asset: Asset,
  strike_collateral_amount: Int,
  entered_earnings_per_share: Int,
  entered_collateral_earnings_per_share: Int,
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
  positions_asset: Asset,
  positions_asset_amount: Int,
  collateral_asset: Asset,
  collateral_amount: Int,
  stop_loss_amount: Int,
  take_profit_amount: Int,
  last_pay_lend_time: POSIXTime,
  entered_earnings_per_share: Int,
  entered_collateral_earnings_per_share: Int,
  validate_pool_ref: OutputReference,
  side: PositionSide,
}

pub type PoolDatum {
  pool_asset: Asset,
  pool_asset_amount: Int,
  pool_asset_lended_amount: Int,
  pooled_interest_rate: Int,
  collateral_asset: Asset,
  max_leverage_factor: Int,
  max_strike_holder_leverage_factor: Int,
  maintain_margin_amount: Int,
  liquidity_asset: Asset,
  earnings_per_share: Int,
  collateral_earnings_per_share: Int,
}
