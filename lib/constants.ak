use aiken/primitive/string
use cardano/assets.{AssetName, PolicyId}
use types.{ScriptHash}

pub const batcher_fee = 2_000_000

pub const long_lp_name: ByteArray = #""

pub const short_lp_name: ByteArray = #""

pub const position_asset_name: AssetName =
  #"535452494b455f504552505f504f534954494f4e"

pub const burn_address: ScriptHash =
  #"00000000000000000000000000000000000000000000000000000000"

// All usd will be multiplied by this number to avoid floating point errors
// 1 USD = 100000
pub const usd_multiplier = 100000

pub const strike_policy_id: PolicyId =
  #"00000000000000000000000000000000000000000000000000000000"

pub const strike_asset_name: AssetName =
  #"00000000000000000000000000000000000000000000000000000000"

pub const manage_positions_script_hash: ScriptHash =
  #"268eca9c9612bdc635bbd9435e75a279cb976000f7179c8eba853420"

pub const settings_nft_asset_name =
  string.to_bytearray(@"PROTOCOL_SETTINGS_NFT")

pub const manager_nft_asset_name = string.to_bytearray(@"PROTOCOL_MANAGER_NFT")

pub const pool_nft_asset_name = string.to_bytearray(@"PROTOCOL_POOL_NFT")
