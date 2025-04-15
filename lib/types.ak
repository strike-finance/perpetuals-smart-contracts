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

pub type OpenPositionType {
  MarketOrder
  LimitOrder
}

pub type OrderAction {
  // When opening position, all borrowed assets are taken from pool and sent to position UTxO
  OpenPositionOrder {
    position_datum: PositionDatum,
    open_position_type: OpenPositionType,
  }
  // Regular close position, where users personally closed their position and all funds are returned to pool. 
  // When they closed it they already consumed what they needed. All that's left is for the pool
  ClosePositionOrder {
    // Owner of the liquidity, to send the lp tokens
    owner_pkh: AddressHash,
    // Stake key if present 
    owner_stake_key: Option<AddressHash>,
    // The collateral asset that was used
    send_asset: Asset,
    // asset amount sent to trader
    send_asset_amount: Int,
    // The profit or loss incurred by the trader and reflected in the pool
    pool_asset_profit_loss: Int,
    // The policy id of the minting position script
    position_policy_id: PolicyId,
    // Amount that was borrowed from pool
    borrowed_amount: Int,
  }
  // Return assets info
  LiquidatePositionOrder {
    // Profit by this trade to the pool
    profit: Int,
    // Lended amount returned to pool
    lended_amount: Int,
    // Position policy id
    position_policy_id: PolicyId,
  }
  ProvideLiquidityOrder {
    // Owner of the liquidity, to send the lp tokens
    owner_pkh: AddressHash,
    // Stake key if present 
    owner_stake_key: Option<AddressHash>,
    // The policy id of the asset that is being added to the pool
    liquidity_asset: Asset,
  }
  WithdrawLiquidityOrder {
    // Owner of the liquidity, to send the lp tokens
    owner_pkh: AddressHash,
    // Stake key if present 
    owner_stake_key: Option<AddressHash>,
  }
}

pub type PositionDatum {
  // Owner of the order
  owner_pkh: AddressHash,
  // Stake key if present 
  owner_stake_key: Option<AddressHash>,
  // The time the order was submitted
  entered_position_time: POSIXTime,
  // The price at which the order was submitted
  entered_at_usd_price: Int,
  // The policy id of the minting position script
  position_policy_id: PolicyId,
  // The position has of the manage positions script
  manage_positions_script_hash: ScriptHash,
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
  // Amount of collateral asset in the position
  collateral_asset_amount: Int,
  // Amount of position asset in the position
  position_asset_amount: Int,
  // Long or short position
  side: PositionSide,
}

pub type OrderDatum {
  action: OrderAction,
}

pub type CloseType {
  TraderClose
  StopLossClose
  TakeProfitClose
  LiquidateClose
}

pub type PoolDatum {
  // The underlying asset that the pool is trading on
  underlying_asset: Asset,
  // Token For Lp
  lp_asset: Asset,
  // Supported assets of the pool, with the total amount of assets that has been added to the pool + profits
  liquidity_total_asset_amount: Int,
  // Supported assets of the pool, with the total lp minted
  liquidity_total_lp_minted: Int,
  // Assets that has been lended out to traders 
  total_lended_amount: Int,
  // Batcher license
  batcher_license: PolicyId,
}

pub type SettingsDatum {
  // The interest rate for the underlying asset
  interest_rate: Int,
  // The max leverage factor for the pool
  max_leverage_factor: Int,
  // The max usd value of the position 
  max_position_usd_value: Int,
  // The min usd value of the position 
  min_position_usd_value: Int,
  // The margin required to liquidate the pool. Once the collateral falls below the maintain_margin_amount of the pool, their position gets liquidated. Example: 5 = 5%
  maintain_margin_amount: Int,
}

pub type PoolParams {
  orders_stake_cred: Credential,
  admin_pkh: AddressHash,
  asset_name: AssetName,
}

pub type ExpectedPoolOutput {
  underlying_asset_amount: Int,
  datum: PoolDatum,
  mint: Value,
}
