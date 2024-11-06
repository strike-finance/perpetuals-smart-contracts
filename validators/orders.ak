// use aiken/collection/list
// use cardano/address.{Credential, Script}
// use cardano/assets.{match}
// use cardano/transaction.{InlineDatum, Input, OutputReference, Transaction}
// use orders_validations.{
//   cancel_close_position, cancel_open_position, valid_orders,
//   validate_individual_order,
// }
// use types.{
//   BatchOrders, CancelOrders, ClosePositionOrder, LiquidatePositionOrder,
//   OpenPositionOrder, OrderDatum, OrdersParams, OrdersRedeemer,
//   OrdersWithdrawRedeemer, PoolDatum,
// }
// use utils.{get_all_validators_inputs, is_withdrawal, validate_batcher_license}

// validator orders(params: OrdersParams) {
//   spend(
//     datum: Option<OrderDatum>,
//     redeemer: OrdersRedeemer,
//     own_ref: OutputReference,
//     transaction: Transaction,
//   ) {
//     when redeemer is {
//       BatchOrders -> is_withdrawal(transaction, own_ref)
//       CancelOrders(output_index) -> {
//         expect Some(datum) = datum

//         let all_validators_inputs: List<Input> =
//           get_all_validators_inputs(transaction)

//         let only_one_input_from_script: Bool =
//           list.length(all_validators_inputs) == 1
//         expect only_one_input_from_script

//         when datum.action is {
//           OpenPositionOrder(..) -> cancel_open_position(datum, transaction)
//           ClosePositionOrder(..) ->
//             cancel_close_position(datum, transaction, output_index)
//           LiquidatePositionOrder(..) -> False
//         }
//       }
//     }
//   }

//   withdraw(
//     redeemer: OrdersWithdrawRedeemer,
//     credential: Credential,
//     transaction: Transaction,
//   ) {
//     expect Script(own_validator) = credential

//     let (input_pool_utxo_index, output_pool_utxo_index) =
//       redeemer.pool_utxo_index

//     let batcher_license_valid =
//       validate_batcher_license(
//         transaction,
//         params.batcher_license,
//         redeemer.batcher_index,
//         params.maximum_deadline_range,
//       )

//     expect Some(input_pool_utxo) =
//       list.at(transaction.inputs, input_pool_utxo_index)

//     expect InlineDatum(input_pool_datum) = input_pool_utxo.output.datum
//     expect input_pool_datum_typed: PoolDatum = input_pool_datum

//     let expected_pool_output =
//       valid_orders(
//         validate_individual_order,
//         redeemer.indexer,
//         transaction,
//         own_validator,
//         input_pool_utxo.output,
//         input_pool_datum_typed,
//         params.burn_address,
//       )

//     expect Some(output_pool_utxo) =
//       list.at(transaction.outputs, output_pool_utxo_index)

//     let value_valid =
//       match(output_pool_utxo.value, expected_pool_output.value, >=)

//     expect InlineDatum(output_pool_datum) = output_pool_utxo.datum
//     expect output_pool_datum_typed: PoolDatum = output_pool_datum

//     let output_datum_valid =
//       expected_pool_output.datum == output_pool_datum_typed

//     let address_valid =
//       input_pool_utxo.output.address == output_pool_utxo.address

//     let expected_mint_valid = expected_pool_output.mint == transaction.mint

//     value_valid && output_datum_valid && address_valid && expected_mint_valid && batcher_license_valid
//   }

//   else(_) {
//     fail
//   }
// }
