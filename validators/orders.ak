use aiken/collection/list
use cardano/address.{Credential, Script}
use cardano/transaction.{Input, OutputReference, Transaction}
use orders_validations.{
  cancel_close_position, cancel_contribute_liquidity, cancel_open_position,
  cancel_withdraw_liquidity, valid_orders, validate_batcher_license,
  validate_individual_order,
}
use types.{
  BatchOrders, CancelOrders, ClosePositionOrder, LiquidatePositionOrder,
  OpenPositionOrder, OrdersDatum, OrdersParams, OrdersRedeemer,
  OrdersWithdrawRedeemer, ProvideLiquidityOrder, WithdrawLiquidityOrder,
}
use utils.{get_all_validators_inputs, is_withdrawal}

validator orders(params: OrdersParams) {
  spend(
    datum: Option<OrdersDatum>,
    redeemer: OrdersRedeemer,
    own_ref: OutputReference,
    transaction: Transaction,
  ) {
    when redeemer is {
      BatchOrders -> is_withdrawal(transaction, own_ref)
      CancelOrders(output_index) -> {
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
          ClosePositionOrder ->
            cancel_close_position(datum, transaction, output_index)
          ProvideLiquidityOrder ->
            cancel_contribute_liquidity(datum, transaction)
          WithdrawLiquidityOrder ->
            cancel_withdraw_liquidity(datum, transaction)
          LiquidatePositionOrder -> False
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

    let order_valid =
      valid_orders(
        validate_individual_order,
        redeemer.indexer,
        transaction,
        own_validator,
      )

    let batcher_license_valid =
      validate_batcher_license(
        transaction,
        params.batcher_license,
        redeemer.batcher_index,
        params.maximum_deadline_range,
      )

    order_valid && batcher_license_valid
  }

  else(_) {
    fail
  }
}
