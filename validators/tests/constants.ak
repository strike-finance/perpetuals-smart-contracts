// use cardano/assets.{AssetName, PolicyId}
// use cardano/transaction.{OutputReference}
// use types.{Asset}

// pub const provide_liquidity_policy_id =
//   #"7b41055e0f57c0c938af3373a7e1785b6569393c85cce9ddc5f246e8"

// pub const provide_liquidty_asset_name = #"6c6f6e67"

// pub const pool_policy_id =
//   #"d6ffbc9038719c18a1f993c2d2bd7cd4cf33209b3ad2f75342382365"

// pub const pool_script_hash =
//   #"c644ec8129f2af4bd297300d0a8c70a094bb4678db05f39720a051e7"

// pub const pool_license =
//   #"d6ffbc9038719c18a1f993c2d2bd7cd4cf33209b3ad2f75342382365"

// pub const position_policy_id =
//   #"d6ffbc9038719c18a1f993c2d2bd7cd4cf33209b3ad2f75342382365"

// pub const pool_asset_name = #"6c6f6e67"

// pub const orders_script_hash =
//   #"bcbc44bd78bff976123ad00e496f855df46d6af2c7a2de30133cd7f0"

// pub const burn_address =
//   #"3d960f7ce468aa238665abd8327f2916926f33350b45b2b1dbac3c03"

// pub const positions_script_hash =
//   #"581c333c9be905ebcc5ee49448d9061dab762dc0b0f96afc5d96e20f"

// pub const liquidity_positions_script_hash =
//   #"bcbc44bd78bff976123ad00e496f855df46d6af2c7a2de30133cd7f0"

// pub const trader_pkh =
//   #"d48838fee1e840857dab28a04dd88193aec8c297b85d8150c0a1f5cc"

// pub const admin_pkh =
//   #"d48838fee1e840857dab28a04dd88193aec8c297b85d8150c0a1f5cc"

// pub const stable_collateral_policy_id =
//   #"965f87c8322049a498f0803697298766e9e6b673c7ec120613048642"

// pub const stable_collateral_asset_name = #"46414b455f5553444d"

// pub const strike_collateral_policy_id =
//   #"a5ff2c36e9eeb9655d06c0a2f02d9e200aa6f8db00d760acf62c0eba"

// pub const batcher_license =
//   #"d6ffbc9038719c18a1f993c2d2bd7cd4cf33209b3ad2f75342382365"

// pub const strike_policy_id: PolicyId =
//   #"00000000000000000000000000000000000000000000000000000000"

// pub const strike_asset_name: AssetName =
//   #"00000000000000000000000000000000000000000000000000000000"

// pub const underlying_asset = Asset { policy_id: "", asset_name: "" }

// pub const batcher_fee = 2_000_000

// pub const maximum_deadline_range = 1_000_000_000

// pub const underlying_asset_multiplier = 1_000_000

// pub const stable_asset_multiplier = 1_000_000

// pub const stable_asset =
//   Asset {
//     policy_id: stable_collateral_policy_id,
//     asset_name: stable_collateral_asset_name,
//   }

// pub const positions_mint_asset =
//   Asset { policy_id: position_policy_id, asset_name: trader_pkh }

// pub const pool_asset =
//   Asset { policy_id: pool_policy_id, asset_name: pool_asset_name }

// pub const strike_collateral_asset =
//   Asset { policy_id: strike_policy_id, asset_name: strike_asset_name }

// pub const out_ref =
//   OutputReference {
//     transaction_id: #"b4971034feee28d07f157faf99b850f856d8da3494c70b19b521cfe690258e26",
//     output_index: 0,
//   }
