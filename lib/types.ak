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

pub type PositionSide {
  Long
  Short
}

pub type UTxOIndexer =
  List<(Int, Int)>

pub type CloseSendAmount {
  // asset amount sent to trader
  send_asset_amount: Int,
  // asset amount sent or taken from pool
  return_pool_asset_amount: Int,
  // strike collateral sent to trader
  strike_collateral_amount: Int,
}

pub type PositionDatum {
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
  // Collateral asset 
  collateral_asset: Asset,
  // The margin required to liquidate the pool. Once the collateral falls below the maintain_margin_amount of the pool, their position gets liquidated. Example: 5 = 5% 
  maintain_margin_amount: Int,
  // Total amount of USD value to pay for borrow each hour
  hourly_usd_borrow_fee: Int,
  // Stop loss price where the position will be closed
  stop_loss_usd_price: Int,
  // Take profit price where the position will be closed
  take_profit_usd_price: Int,
  // Long or short position
  side: PositionSide,
}

pub type OrderAction {
  OpenPositionOrder { position_datum: PositionDatum }
  ClosePositionOrder {
    // The script hash for the positions script that holds all the positions of the trader
    position_hash: ScriptHash,
    // The amount of underlying asset gained/loss for liquidity providers
    underlying_asset_gain_loss: Int,
  }
  LiquidatePositionOrder {
    // The script hash for the positions script that holds all the positions of the trader
    position_hash: ScriptHash,
    // The amount of underlying asset gained/loss for liquidity providers
    underlying_asset_gain: Int,
  }
  ProvideLiquidityOrder {
    // Amount of liquidity to provide
    liquidity_amount: Int,
    // Owner of the liquidity, to send the lp tokens
    owner_address_hash: AddressHash,
  }
  WithdrawLiquidityOrder {
    // Amount of liquidity to withdraw
    liquidity_amount: Int,
    // Owner of the liquidity, to send their withdrawal amount
    owner_address_hash: AddressHash,
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
}

pub type PositionRedeemer {
  CompleteLimitOrder { price: Int }
  CancelLimitOrder { price: Int }
}

pub type MintPositionRedeemer {
  OpenPosition { price: Int }
  ClosePosition { burn_amount: Int }
  OpenLimitPosition { price: Int }
}

pub type PoolDatum {
  // The underlying asset that the pool is trading on
  underlying_asset: Asset,
  // Total amount of underlying asset that belongs to liquidity providers
  total_underlying_asset_amount: Int,
  // Total amount of lp tokens minted
  total_lp_tokens_minted: Int,
  // The interest rate for the underlying asset
  interest_rate: Int,
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

pub type ExpectedPoolOutput {
  value: Value,
  datum: PoolDatum,
  mint: Value,
}

pub type OrdersRedeemer {
  ProcessOrders
  ClosePendingOpenOrders
}
