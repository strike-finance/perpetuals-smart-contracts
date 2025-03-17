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
  owner_pkh: AddressHash,
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

pub type LiquidityActionInfo {
  // Amount of liquidity to provide for the long side
  long_liquidity_amount: Int,
  // Amount of liquidity to provide for the short side
  short_liquidity_amount: Int,
  // Owner of the liquidity, to send the lp tokens
  owner_pkh: AddressHash,
  // Stake key if present 
  owner_stake_key: Option<AddressHash>,
  // LP token Policy Id 
  policy_id: PolicyId,
}

pub type OrderAction {
  OpenPositionOrder { position_datum: PositionDatum }
  ClosePositionOrder {
    // The script hash for the positions script that holds all the positions of the trader
    position_hash: ScriptHash,
    // The amount of underlying asset gained/loss for liquidity providers
    underlying_asset_gain_loss: Int,
    // Long or short position close
    side: PositionSide,
  }
  LiquidatePositionOrder {
    // The script hash for the positions script that holds all the positions of the trader
    position_hash: ScriptHash,
    // The amount of underlying asset gained/loss for liquidity providers
    underlying_asset_gain: Int,
    // Long or short position liquidated
    side: PositionSide,
  }
  ProvideLiquidityOrder { info: LiquidityActionInfo }
  WithdrawLiquidityOrder { info: LiquidityActionInfo }
}

pub type OrderDatum {
  action: OrderAction,
}

pub type CloseType {
  TraderClose
  StopLossClose
  TakeProfitClose
}

pub type PoolDatum {
  // The underlying asset that the pool is trading on
  underlying_asset: Asset,
  // Token For Lp, the asset name determines if the lp is for a long or short pool
  lp_policy_id: PolicyId,
  // Total amount of underlying asset that belongs to long liquidity providers
  long_total_asset_amount: Int,
  // Total amount of underlying asset that belongs to short liquidity providers
  short_total_asset_amount: Int,
  // Amount of long assets currently available for traders 
  long_available_asset_amount: Int,
  // Amount of short assets currently available for traders
  short_available_asset_amount: Int,
  // Total amount of lp tokens minted for long liquidity providers
  long_total_lp_minted: Int,
  // Total amount of lp tokens minted for short liquidity providers
  short_total_lp_minted: Int,
}

pub type SettingsDatum {
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
