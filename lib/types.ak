use aiken/crypto.{Blake2b_224, Hash, Script, VerificationKey}
use cardano/address.{Credential}
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

pub type OrdersParams {
  batcher_license: PolicyId,
  maximum_deadline_range: Int,
  underlying_asset_policy_id: PolicyId,
  underlying_asset_name: AssetName,
}

pub type PositionSide {
  Long
  Short
}

pub type OrderAction {
  OpenPositionOrder
  ClosePositionOrder
  ProvideLiquidityOrder
  WithdrawLiquidityOrder
  LiquidatePositionOrder
}

pub type OrdersRedeemer {
  BatchOrders
  CancelOrders(Int)
}

pub type UTxOIndexer =
  List<(Int, Int)>

pub type OrdersWithdrawRedeemer {
  indexer: UTxOIndexer,
  batcher_index: Int,
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
  // Total position size of the trader
  positions_mint_asset_amount: Int,
  // Minted asset to represent amount of liquidity that has been provided 
  liquidity_asset: Asset,
  // Total amount of liquidity that has been provided 
  liquidity_asset_amount: Int,
  // Script hash of the liquidty script that holds the providers liquidit positions
  liquidity_positions_script_hash: ScriptHash,
  // The collateral asset used for the position
  collateral_asset: Asset,
  // Total amount of collateral asset used for the position
  collateral_asset_amount: Int,
  // The collateral asset used for the strike position
  strike_collateral_asset: Asset,
  // Total amount of strike collateral asset used for the position
  strike_collateral_asset_amount: Int,
  // Earnings per share for the position
  entered_earnings_per_share: Int,
  // Earnings per share for the strike position
  entered_collateral_earnings_per_share: Int,
  // Stop loss USD price for the position
  stop_loss_usd_price: Int,
  // Take profit USD price for the position
  take_profit_usd_price: Int,
  // Liquidate USD price for the position
  liquidate_usd_price: Int,
  // Price of asset when the order was submitted
  order_submission_usd_price: Int,
  // Entered at price for positions
  entered_at_usd_price: Int,
  // The time the order was submitted
  order_submission_time: POSIXTime,
  // Reference to the pool validator
  pool_license: PolicyId,
  // Action to be taken for the order
  action: OrderAction,
  // Side of the position
  side: PositionSide,
}

pub type CloseType {
  TraderClose
  StopLossClose
  TakeProfitClose
  LiquidateClose
}

pub type PositionsRedeemer {
  Close(Int, CloseType)
  UpdateStopLoss(Int)
  UpdateTakeProfit(Int)
  PayLend(Int)
}

pub type PositionsMintRedeemer {
  MintPosition(Int)
  BurnPosition(Int, ByteArray)
}

pub type PositionsParams {
  orders_script_hash: ScriptHash,
  pool_license: PolicyId,
}

pub type PositionDatum {
  // Owner of the position
  owner_address_hash: AddressHash,
  // Price at which the position was entered
  entered_at_usd_price: Int,
  // The underlying asset that the perpetual contract is trading on
  underlying_asset: Asset,
  // Leverage used for the postion.
  leverage_factor: Int,
  // Minted asset to represent the trader total position size
  positions_mint_asset: Asset,
  // Total position size of the trader, ie, the inital size of position + leverage
  positions_mint_asset_amount: Int,
  // Stable collateral asset
  collateral_asset: Asset,
  // Total stable collateral amount
  collateral_asset_amount: Int,
  // Strike Collateral Asset
  strike_collateral_asset: Asset,
  // Total strike collateral amount
  strike_collateral_asset_amount: Int,
  // Price at which the position will be liquidated
  liquidate_usd_price: Int,
  // Stop loss price where the position will be closed
  stop_loss_usd_price: Int,
  // Take profit price where the position will be closed
  take_profit_usd_price: Int,
  // Last time the hourly lend was paid
  last_pay_lend_time: POSIXTime,
  // Reference to the pool validator
  pool_license: PolicyId,
  // Side of the position
  side: PositionSide,
}

pub type PoolDatum {
  // The underlying asset that the pool is trading on
  underlying_asset: Asset,
  // Total amount of underlying asset in the pool
  underlying_asset_amount: Int,
  // Total amount of underlying asset that has been lended out
  underlying_asset_lended_amount: Int,
  // The interest rate for the underlying asset
  underlying_interest_rate: Int,
  // The margin required to liquidate the pool
  liquidate_margin: Int,
  // The stable collateral asset used for the pool
  stable_collateral_asset: Asset,
  // Total amount of stable collateral asset
  stable_collateral_asset_amount: Int,
  // The max leverage factor for the pool
  max_leverage_factor: Int,
  // The max leverage factor for the strike holder
  max_strike_holder_leverage_factor: Int,
  // The amount of margin to maintain for the pool
  maintain_margin_amount: Int,
  // Asset the determines if the pool is valid
  is_valid_pool_asset: Asset,
  // The earnings per share for the pool, will increase each time the pool earns the underlying asset
  earnings_per_share: Int,
  // The earnings per share for the collateral for the pool, will increase each time the pool earns the collateral asset
  collateral_earnings_per_share: Int,
}

pub type PoolsParams {
  orders_stake_cred: Credential,
  admin_pkh: AddressHash,
  asset_name: AssetName,
}

pub type UpdateParamsType {
  UpdateInterestRate(Int)
  UpdateLiquidateMargin(Int)
  UpdateMaxLeverageFactor(Int)
  UpdateMaxStrikeHolderLeverageFactor(Int)
}

pub type PoolsRedeemerAction {
  UtilizePool
  UpdateParams
}

pub type PoolsRedeemer {
  action: PoolsRedeemerAction,
  update_param_type: UpdateParamsType,
}

pub type LiquidityPositionDatum {
  owner_address_hash: AddressHash,
  entered_earnings_per_share: Int,
  entered_collateral_earnings_per_share: Int,
}

pub type LiquidityParams {
  orders_script_hash: ByteArray,
  asset_name: AssetName,
  underlying_asset_policy_id: PolicyId,
  underlying_asset_name: AssetName,
}

pub type LiquidityRedeemer {
  WithdrawPartialLiquidity
  WithdrawLiquidity
}

pub type LiquidityMintsRedeemer {
  MintLiquidity
  BurnLiquidity(Int)
}
