use cardano/transaction.{OutputReference}
use types.{Asset}

pub const protocol_nft_policy_id =
  #"b5bab2940b09a2350d7814b3077822f622e740e3921812d6c58112bb"

pub const orders_script_hash =
  #"914909b263494dfed1cac90f80c5e11920a8a3a9890a9186722041b8"

pub const manage_positions_script_hash =
  #"d2a71ed27acabbe919fb54dc84d4aff5b4357f6527dde0aeb7fd80c3"

pub const test_position_policy_id =
  #"8467a48e5dc922bf25aca00a90ed055571c8c148831d3dcba5b4fecc"

pub const trader_pkh =
  #"d48838fee1e840857dab28a04dd88193aec8c297b85d8150c0a1f5cc"

pub const underlying_asset = Asset { policy_id: "", asset_name: "" }

pub const out_ref =
  OutputReference {
    transaction_id: #"b4971034feee28d07f157faf99b850f856d8da3494c70b19b521cfe690258e26",
    output_index: 0,
  }
