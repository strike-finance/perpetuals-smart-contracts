use aiken/collection/list
use cardano/address.{Credential, Script}
use cardano/assets.{AssetName, PolicyId}
use cardano/transaction.{Input, OutputReference, Transaction}
use types.{
  AddressHash, BatchOrders, CancelOrders, ClosePosition, Liquidate, OpenPosition,
  OrdersDatum, OrdersRedeemer, OrdersWithdrawRedeemer, ProvideLiquidity,
  WithdrawLiquidity,
}
use utils.{get_all_validators_inputs, is_withdrawal}
use validations/orders_utils.{
  cancel_close_position_order, cancel_contribute_liquidity_order,
  cancel_open_position_order, cancel_withdraw_liquidity_order, valid_orders,
  validate_order,
}

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
          ProvideLiquidity ->
            cancel_contribute_liquidity_order(datum, transaction)
          WithdrawLiquidity ->
            cancel_withdraw_liquidity_order(datum, transaction)
          Liquidate -> False
        }
      }
    }
  }

  withdraw(
    redeemer: OrdersWithdrawRedeemer,
    credential: Credential,
    transaction: Transaction,
  ) {
    expect Script(own_validator) = credential

    valid_orders(
      validate_order,
      redeemer.indexer,
      transaction,
      credential,
      redeemer.current_price,
    )
  }

  else(_) {
    fail
  }
}
