use types.{Asset}

pub const enter_position_policy_id =
  #"5e4341df568a79b2106e0f5370ea737c62ef78728b74228bd20e0a48"

pub const provide_liquidity_policy_id =
  #"7b41055e0f57c0c938af3373a7e1785b6569393c85cce9ddc5f246e8"

pub const long_asset_name = #"6c6f6e67"

pub const short_asset_name = #"73686f7274"

pub const provide_liquidty_asset_name = #"6c6f6e67"

pub const pool_policy_id =
  #"400df17fee0ea6de308fd1867fcc494ace5ca924b509ea7c42df9f75"

pub const pool_asset_name = #"6c6f6e67"

pub const orders_script_hash =
  #"bcbc44bd78bff976123ad00e496f855df46d6af2c7a2de30133cd7f0"

pub const liquidity_positions_script_hash =
  #"bcbc44bd78bff976123ad00e496f855df46d6af2c7a2de30133cd7f0"

pub const trader_pkh =
  #"d48838fee1e840857dab28a04dd88193aec8c297b85d8150c0a1f5cc"

pub const admin_pkh =
  #"d48838fee1e840857dab28a04dd88193aec8c297b85d8150c0a1f5cc"

pub const stable_collateral_policy_id =
  #"965f87c8322049a498f0803697298766e9e6b673c7ec120613048642"

pub const stable_collateral_asset_name = #"46414b455f5553444d"

pub const strike_collateral_policy_id =
  #"a5ff2c36e9eeb9655d06c0a2f02d9e200aa6f8db00d760acf62c0eba"

pub const strike_collateral_asset_name = #"535452494b45"

pub const underlying_asset = Asset { policy_id: "", asset_name: "" }

pub const lovelace_asset = Asset { policy_id: "", asset_name: "" }

pub const stable_collateral_asset =
  Asset {
    policy_id: stable_collateral_policy_id,
    asset_name: stable_collateral_asset_name,
  }

pub const long_position_asset =
  Asset { policy_id: enter_position_policy_id, asset_name: long_asset_name }

pub const short_position_asset =
  Asset { policy_id: enter_position_policy_id, asset_name: short_asset_name }

pub const pool_asset =
  Asset { policy_id: pool_policy_id, asset_name: pool_asset_name }

pub const strike_collateral_asset =
  Asset {
    policy_id: strike_collateral_policy_id,
    asset_name: strike_collateral_asset_name,
  }
