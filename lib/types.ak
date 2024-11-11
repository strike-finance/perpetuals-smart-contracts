use aiken/crypto.{Blake2b_224, Hash, Script, VerificationKey}
use cardano/address.{Credential}
use cardano/assets.{AssetName, PolicyId, Value}

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
  stable_asset_policy_id: PolicyId,
  stable_asset_name: AssetName,
  burn_address: ScriptHash,
}

pub type PositionSide {
  Long
  Short
}

pub type OrdersRedeemer {
  BatchOrders
  CancelOrders(Int)
}

pub type UTxOIndexer =
  List<(Int, Int)>

pub type OrdersWithdrawRedeemer {
  indexer: UTxOIndexer,
  pool_utxo_index: (Int, Int),
  batcher_index: Int,
}

pub type CloseSendAmount {
  LongCloseOrder { asset_amount: Int }
  ShortCloseOrder { collateral_amount: Int, asset_amount: Int }
}

pub type OrderAction {
  OpenPositionOrder {
    // Owner of the order
    owner_address_hash: AddressHash,
    // The leverage factor for the position
    leverage_factor: Int,
    // The time the order was submitted
    order_submission_time: POSIXTime,
    // The price at which the order was submitted
    order_submission_usd_price: Int,
    // The script hash for the positions script that holds all the positions of the trader
    position_hash: ScriptHash,
    // Total position size of the trader
    position_asset_amount: Int,
    // The collateral asset used for the position
    margin_requirement: Int,
    // Total amount of USD value to pay for borrow each hour
    hourly_usd_borrow_fee: Int,
    // Long or short position
    side: PositionSide,
  }
  ClosePositionOrder {
    // Owner of the order
    owner_address_hash: AddressHash,
    // The underlying asset that the perpetual contract is trading on
    leverage_factor: Int,
    // The price at which the order was submitted
    order_submission_usd_price: Int,
    // Entered at USD price
    entered_at_usd_price: Int,
    // Stop loss price where the position will be closed
    stop_loss_usd_price: Int,
    // Take profit price where the position will be closed
    take_profit_usd_price: Int,
    // Last time the hourly lend was paid
    entered_position_time: POSIXTime,
    // The script hash for the positions script that holds all the positions of the trader
    position_hash: ScriptHash,
    // Total position size of the trader
    position_asset_amount: Int,
    // The margin required to liquidate the pool, Example: 5 = 5%. so the collatral needs to be atleast 5% of the position value
    margin_requirement: Int,
    // Total amount of USD value to pay for borrow each hour
    hourly_usd_borrow_fee: Int,
    // Amount to return to the owner
    return_amount: CloseSendAmount,
    // Long or short position
    side: PositionSide,
  }
  LiquidatePositionOrder {
    // Owner of the position
    owner_address_hash: AddressHash,
    // The script hash for the positions script that holds all the positions of the trader
    position_hash: ScriptHash,
    // Long or short position
    side: PositionSide,
  }
}

// ProvideLiquidityOrder
// WithdrawLiquidityOrder

pub type OrderDatum {
  // Action to be taken for the order
  action: OrderAction,
}

pub type CloseType {
  TraderClose
  StopLossClose
  TakeProfitClose
  LiquidateClose
}

pub type PositionRedeemer {
  Close(Int, CloseType)
  UpdateStopLoss(Int)
  UpdateTakeProfit(Int)
}

pub type PositionMintRedeemer {
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
  // The script hash for the positions script that holds all the positions of the trader
  position_hash: ScriptHash,
  // Price at which the position was entered
  entered_at_usd_price: Int,
  // Leverage used for the postion.
  leverage_factor: Int,
  // Total position size of the trader, ie, the inital size of position + leverage
  position_asset_amount: Int,
  // Stop loss price where the position will be closed
  stop_loss_usd_price: Int,
  // Take profit price where the position will be closed
  take_profit_usd_price: Int,
  // Last time the hourly lend was paid
  entered_position_time: POSIXTime,
  // The collateral asset used for the position
  collateral_asset: Asset,
  // The margin required to liquidate the pool, Example: 5 = 5%. so the collatral needs to be atleast 5% of the position value
  margin_requirement: Int,
  // Total amount of USD value to pay for borrow each hour
  hourly_usd_borrow_fee: Int,
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
  // The margin required to liquidate the pool, Example: 5 = 5%
  margin_requirement: Int,
  // The stable collateral asset used for the pool
  stable_asset: Asset,
  // Total amount of stable collateral asset
  stable_asset_amount: Int,
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

pub type PoolParams {
  orders_stake_cred: Credential,
  admin_pkh: AddressHash,
  asset_name: AssetName,
}

pub type UpdateParamType {
  UpdateInterestRate(Int)
  UpdateLiquidateMargin(Int)
  UpdateMaxLeverageFactor(Int)
  UpdateMaxStrikeHolderLeverageFactor(Int)
}

pub type PoolRedeemerAction {
  UtilizePool
  UpdateParam
}

pub type PoolRedeemer {
  action: PoolRedeemerAction,
  update_param_type: UpdateParamType,
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

pub type ExpectedPoolOutput {
  value: Value,
  datum: PoolDatum,
  mint: Value,
}
