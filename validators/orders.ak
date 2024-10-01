use aiken/collection/list
use cardano/address.{Credential}
use cardano/assets.{AssetName, PolicyId}
use cardano/transaction.{Input, OutputReference, Transaction}
use orders_utils.{
  cancel_close_position_order, cancel_contribute_liquidity_order,
  cancel_open_position_order, valid_orders, validate_order,
}
use types.{
  AddressHash, BatchOrders, CancelOrders, ClosePosition, ContributeLiquidity,
  OpenPosition, OrdersDatum, OrdersRedeemer, OrdersWithdrawRedeemer,
  WithdrawLiquidity,
}
use utils.{get_all_validators_inputs, is_withdrawal}

// Users will be placing their orders here. The funds for their position will be here until the the batcher puts it into the pool.
// When they close their position, their utxo will also be here. 
validator orders(
  admin_pkh: AddressHash,
  _underlying_asset_policy_id: PolicyId,
  _underlying_asset_name: AssetName,
) {
  spend(
    datum: Option<OrdersDatum>,
    redeemer: OrdersRedeemer,
    own_ref: OutputReference,
    transaction: Transaction,
  ) {
    when redeemer is {
      BatchOrders -> {
        let signed_by_admin = list.has(transaction.extra_signatories, admin_pkh)

        is_withdrawal(transaction, own_ref) && signed_by_admin
      }
      CancelOrders -> {
        expect Some(datum) = datum

        let signed_by_owner: Bool =
          list.has(transaction.extra_signatories, datum.owner_address_hash)

        let all_validators_inputs: List<Input> =
          get_all_validators_inputs(transaction)

        let only_one_input_from_script: Bool =
          list.length(all_validators_inputs) == 1
        expect signed_by_owner && only_one_input_from_script

        when datum.action is {
          OpenPosition -> cancel_open_position_order(datum, transaction)
          ClosePosition -> cancel_close_position_order(datum, transaction)
          ContributeLiquidity ->
            cancel_contribute_liquidity_order(datum, transaction)
          WithdrawLiquidity -> True
        }
      }
    }
  }

  withdraw(
    redeemer: OrdersWithdrawRedeemer,
    _credential: Credential,
    transaction: Transaction,
  ) {
    valid_orders(
      validate_order,
      redeemer.indexer,
      transaction,
      admin_pkh,
      redeemer.current_price,
    )
  }

  else(_) {
    fail
  }
}
