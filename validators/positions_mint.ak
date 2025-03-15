use cardano/assets.{PolicyId, flatten}
use cardano/transaction.{OutputReference, Transaction}
use constants.{position_asset_name}
use positions_validations.{mint_position_valid}
use types.{ClosePosition, OpenPosition, PositionDatum, ScriptHash}

pub type LimitOrderRedeemer {
  CompleteLimitOrder { price: Int }
  CancelLimitOrder
}

pub type PositionMintRedeemer {
  OpenPosition { current_usd_price: Int }
  OpenLimitPosition { current_usd_price: Int }
  ClosePosition { burn_amount: Int }
}

// Create positions and send to orders script
// Can create limit orders and send to orders script once the limit order price is reached
validator positions_mint(orders_script_hash: ScriptHash) {
  spend(
    datum: Option<PositionDatum>,
    redeemer: LimitOrderRedeemer,
    _own_ref: OutputReference,
    transaction: Transaction,
  ) {
    todo
  }

  mint(
    redeemer: PositionMintRedeemer,
    policy_id: PolicyId,
    transaction: Transaction,
  ) {
    when redeemer is {
      OpenPosition(current_usd_price) ->
        mint_position_valid(
          transaction: transaction,
          orders_script_hash: orders_script_hash,
          current_usd_price: current_usd_price,
          policy_id: policy_id,
        )
      OpenLimitPosition(current_usd_price) ->
        mint_position_valid(
          transaction: transaction,
          orders_script_hash: orders_script_hash,
          current_usd_price: current_usd_price,
          policy_id: policy_id,
        )
      // Batcher might close/liquidate multiple positions at once
      ClosePosition(burn_amount) ->
        [(policy_id, position_asset_name, -burn_amount)] == flatten(
          transaction.mint,
        )
    }
  }

  else(_) {
    False
  }
}
