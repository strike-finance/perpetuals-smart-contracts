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
  MintLong(Int)
  MintShort(Int)
  BurnLong
  BurnShort
}

pub type OrdersDatum {
  owner_address_hash: AddressHash,
  entered_at_price: Int,
  underlying_asset: Asset,
  underlying_asset_amount: Int,
  leverage_factor: Int,
  orders_validator_hash: ScriptHash,
  positions_validator_hash: ScriptHash,
  positions_asset: Asset,
  positions_asset_amount: Int,
  liquidity_asset: Asset,
  liquidity_asset_amount: Int,
  stable_collateral_asset: Asset,
  stable_collateral_asset_amount: Int,
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
  collateral_asset_amount: Int,
  stop_loss_amount: Int,
  take_profit_amount: Int,
  last_pay_lend_time: POSIXTime,
  validate_pool_ref: OutputReference,
  side: PositionSide,
}

pub type PoolDatum {
  underlying_asset: Asset,
  underlying_asset_amount: Int,
  underlying_asset_lended_amount: Int,
  underlying_interest_rate: Int,
  collateral_asset: Asset,
  max_leverage_factor: Int,
  max_strike_holder_leverage_factor: Int,
  maintain_margin_amount: Int,
  is_valid_pool_asset: Asset,
  earnings_per_share: Int,
  collateral_earnings_per_share: Int,
}

pub type LiquidityPositionDatum {
  owner_address_hash: AddressHash,
  entered_earnings_per_share: Int,
  entered_collateral_earnings_per_share: Int,
}

pub type EnterPositionParams {
  orders_script_hash: ScriptHash,
  long_asset_name: ByteArray,
  short_asset_name: ByteArray,
  validate_pool_ref: OutputReference,
  admin_pkh: AddressHash,
}
