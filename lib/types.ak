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
  OpenPositionOrder
  ClosePositionOrder
  StopLossOrder
  TakeProfitOrder
  ProvideLiquidityOrder
  WithdrawLiquidityOrder
  LiquidateOrder
}

pub type OrdersRedeemer {
  BatchOrders
  CancelOrders
}

pub type RedeemerIndexer =
  List<(Int, Int)>

pub type OrdersWithdrawRedeemer {
  indexer: RedeemerIndexer,
  current_price: Int,
}

pub type OrdersDatum {
  // Owner of the order
  owner_address_hash: AddressHash,
  // The underlying asset that the perpetual contract is trading on
  underlying_asset: Asset,
  // Inital size of the position
  underlying_asset_amount: Int,
  // Leverage used for the postion. Total positon size is underlying_asset_amount * leverage factor
  leverage_factor: Int,
  // The script hash for the orders script that es all the orders
  orders_script_hash: ScriptHash,
  // The script hash for the positions script that holds all the positions of the trader
  positions_script_hash: ScriptHash,
  // Minted asset to represent the trader total position size
  positions_mint_asset: Asset,
  // Total position size of the trader, ie, the inital size of position + leverage
  positions_mint_asset_amount: Int,
  // Minted asset to represent amount of liquidity that has been provided 
  liquidity_asset: Asset,
  // Total amount of liquidity that has been provided 
  liquidity_asset_amount: Int,
  liquidity_positions_script_hash: ScriptHash,
  stable_collateral_asset: Asset,
  stable_collateral_asset_amount: Int,
  strike__collateral_asset: Asset,
  strike_collateral_amount: Int,
  entered_earnings_per_share: Int,
  entered_collateral_earnings_per_share: Int,
  stop_loss_usd_price: Int,
  take_profit_usd_price: Int,
  liquidate_usd_price: Int,
  order_submission_usd_price: Int,
  order_submission_time: POSIXTime,
  validate_pool_ref: OutputReference,
  action: OrderAction,
  side: PositionSide,
}

pub type PositionsRedeemer {
  Close(Int)
  StopLoss(Int)
  UpdateStopLoss(Int)
  TakeProfit(Int)
  UpdateTakeProfit(Int)
  Liquidate(Int)
  PayLend(Int)
}

pub type PositionsMintRedeemer {
  MintLong(Int)
  MintShort(Int)
  Burn(Int, ByteArray)
}

pub type PositionsParams {
  orders_script_hash: ScriptHash,
  long_asset_name: ByteArray,
  short_asset_name: ByteArray,
  validate_pool_ref: OutputReference,
  admin_pkh: AddressHash,
}

pub type PositionDatum {
  owner_address_hash: AddressHash,
  entered_at_price: Int,
  underlying_asset: Asset,
  leverage_factor: Int,
  positions_mint_asset: Asset,
  positions_mint_asset_amount: Int,
  stable_collateral_asset: Asset,
  stable_collateral_asset_amount: Int,
  liquidate_usd_price: Int,
  stop_loss_usd_price: Int,
  take_profit_usd_price: Int,
  last_pay_lend_time: POSIXTime,
  validate_pool_ref: OutputReference,
  side: PositionSide,
}

pub type PoolDatum {
  underlying_asset: Asset,
  underlying_asset_amount: Int,
  underlying_asset_lended_amount: Int,
  underlying_interest_rate: Int,
  liquidate_margin: Int,
  stable_collateral_asset: Asset,
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

pub type LiquidityParams {
  orders_script_hash: ByteArray,
  asset_name: AssetName,
  provided_asset_policy_id: PolicyId,
  provided_asset_name: AssetName,
}

pub type LiquidityRedeemer {
  WithdrawPartialLiquidity
  WithdrawLiquidity
}

pub type LiquidityMintsRedeemer {
  MintLiquidity
  BurnLiquidity(Int)
}
