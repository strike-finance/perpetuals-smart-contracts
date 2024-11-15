use cardano/assets.{AssetName, PolicyId}

pub const batcher_fee = 2_000_000

// All usd will be multiplied by this number to avoid floating point errors
// 1 USD = 100000
pub const usd_multiplier = 100000

pub const strike_policy_id: PolicyId =
  #"00000000000000000000000000000000000000000000000000000000"

pub const strike_asset_name: AssetName =
  #"00000000000000000000000000000000000000000000000000000000"
