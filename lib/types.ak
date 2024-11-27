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
  CancelOrder(Int)
}

pub type UTxOIndexer =
  List<(Int, Int)>

pub type OrdersWithdrawRedeemer {
  indexer: UTxOIndexer,
  pool_utxo_index: (Int, Int),
  batcher_index: Int,
}

pub type CloseSendAmount {
  LongCloseOrder {
    // asset amount sent to trader
    asset_amount: Int,
    // asset amount sent or taken from pool
    pool_asset_amount: Int,
    // strike collateral sent to trader
    strike_collateral_amount: Int,
  }
  ShortCloseOrder {
    // stable amount sent to trader
    stable_amount: Int,
    // stable amount sent or taken from pool
    pool_stable_amount: Int,
    // asset amount sent to trader
    asset_amount: Int,
    // asset amount sent or taken from pool
    pool_asset_amount: Int,
    // strike collateral sent to trader
    strike_collateral_amount: Int,
  }
}

pub type PositionDatumInfo {
  // Owner of the order
  owner_address_hash: AddressHash,
  // The amount of leverage used for the position. 1 = 1x inital collateral value. 10 = 10x inital collateral value
  leverage_factor: Int,
  // The time the order was submitted
  entered_position_time: POSIXTime,
  // The price at which the order was submitted
  entered_at_usd_price: Int,
  // The script hash for the positions script that holds all the positions of the trader
  position_hash: ScriptHash,
  // Total position size of the trader
  position_asset_amount: Int,
  // The collateral asset used for the position
  maintain_margin_amount: Int,
  // Total amount of USD value to pay for borrow each hour
  hourly_usd_borrow_fee: Int,
  // Long or short position
  side: PositionSide,
}

pub type OrderAction {
  OpenPositionOrder { position_datum: PositionDatumInfo }
  ClosePositionOrder {
    // Stop loss price where the position will be closed
    stop_loss_usd_price: Int,
    // Take profit price where the position will be closed
    take_profit_usd_price: Int,
    // Amount to return to the owner
    return_amount: CloseSendAmount,
    // Open position order
    position_datum: PositionDatumInfo,
  }
  LiquidatePositionOrder {
    // Owner of the position
    owner_address_hash: AddressHash,
    // The script hash for the positions script that holds all the positions of the trader
    position_hash: ScriptHash,
    // Long or short position
    side: PositionSide,
    // Total size of position
    position_asset_amount: Int,
    // Leverage used for this position
    leverage_factor: Int,
  }
}

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

pub type PositionUpdateType {
  UpdateStopLoss
  UpdateTakeProfit
}

pub type PositionRedeemer {
  Close(Int, CloseType)
  PositionUpdate(PositionUpdateType, Int)
}

pub type PositionMintRedeemer {
  MintPosition(Int)
  BurnPosition(Int, ByteArray)
}

pub type PositionsParams {
  orders_script_hash: ScriptHash,
  underlying_asset_multiplier: Int,
  stable_asset_multiplier: Int,
}

pub type PositionDatum {
  // Owner of the position
  owner_address_hash: AddressHash,
  // The script hash for the positions script that holds all the positions of the trader
  position_hash: ScriptHash,
  // Price at which the position was entered. This will be 
  entered_at_usd_price: Int,
  // The amount of leverage used for the position. 1 = 1x inital collateral value. 10 = 10x inital collateral value
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
  // The margin required to liquidate the pool. Once the collateral falls below the maintain_margin_amount of the pool, their position gets liquidated. Example: 5 = 5%
  maintain_margin_amount: Int,
  // Total amount of USD value to pay for borrow each hour
  hourly_usd_borrow_fee: Int,
  // Side of the position
  side: PositionSide,
}

pub type PoolDatum {
  // The underlying asset that the pool is trading on
  underlying_asset: Asset,
  // Total amount of underlying asset that has been lended out
  underlying_asset_lended_amount: Int,
  // The interest rate for the underlying asset
  interest_rate: Int,
  // The stable asset that the pool is trading on
  stable_asset: Asset,
  // The max leverage factor for the pool
  max_leverage_factor: Int,
  // The max leverage factor for the strike holder
  max_strike_holder_leverage_factor: Int,
  // The margin required to liquidate the pool. Once the collateral falls below the maintain_margin_amount of the pool, their position gets liquidated. Example: 5 = 5%
  maintain_margin_amount: Int,
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

pub type ExpectedPoolOutput {
  value: Value,
  datum: PoolDatum,
  mint: Value,
}
