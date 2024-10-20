use aiken/collection/list
use cardano/address.{Credential, Script}
use cardano/assets.{AssetName, PolicyId}
use cardano/transaction.{Input, OutputReference, Transaction}
use orders_validations.{
  cancel_close_position, cancel_contribute_liquidity, cancel_open_position,
  cancel_withdraw_liquidity, valid_orders, validate_individual_order,
}
use types.{
  AddMoreLiquidityOrder, AddressHash, BatchOrders, CancelOrders,
  ClosePositionOrder, LiquidateOrder, OpenPositionOrder, OrdersDatum,
  OrdersRedeemer, OrdersWithdrawRedeemer, ProvideLiquidityOrder, StopLossOrder,
  TakeProfitOrder, WithdrawLiquidityOrder,
}
use utils.{get_all_validators_inputs, is_withdrawal}

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
          OpenPositionOrder -> cancel_open_position(datum, transaction)
          ClosePositionOrder -> cancel_close_position(datum, transaction)
          StopLossOrder -> False
          TakeProfitOrder -> False
          AddMoreLiquidityOrder -> todo
          ProvideLiquidityOrder ->
            cancel_contribute_liquidity(datum, transaction)
          WithdrawLiquidityOrder ->
            cancel_withdraw_liquidity(datum, transaction)
          LiquidateOrder -> False
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
      validate_individual_order,
      redeemer.indexer,
      transaction,
      own_validator,
    )
  }

  else(_) {
    fail
  }
}
