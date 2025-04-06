use aiken/collection/dict
use aiken/collection/list
use cardano/address.{Credential, Script}
use cardano/assets.{AssetName, PolicyId, match, quantity_of}
use cardano/transaction.{
  InlineDatum, Input, Output, OutputReference, Transaction,
}
use constants.{position_asset_name, strike_asset_name, strike_policy_id}
use math.{calculate_position_usd_value_based_on_side}
use orders_validations.{valid_orders}
use types.{
  AutomatedClosePositionOrder, MarketOrder, OpenPositionOrder, OrderDatum,
  PoolDatum, PositionDatum,
}
use utils.{
  get_address_outputs, get_all_validators_inputs, get_lower_bound,
  get_validators_inputs, is_withdrawal,
}

pub type OrdersWithdrawRedeemer {
  indexer: List<(Int, Int)>,
  pool_utxo_index: (Int, Int),
  batcher_license_utxo_index: Int,
}

pub type OrdersRedeemer {
  // Process all orders which includes providing and withdrawing liquidity
  ProcessOrders
  // Users placed limit order, can cancel anytime. Cancel open orders that has been sitting idle and havent been picked up by batcher
  CancelLimitOrder
  // A regular that has been placed, but havent been processed by batcher, and user wants to close it
  CloseOrderWhilePending(Int)
}

validator orders(pool_nft_policy_id: PolicyId, pool_nft_asset_name: AssetName) {
  spend(
    maybe_datum: Option<OrderDatum>,
    redeemer: OrdersRedeemer,
    own_ref: OutputReference,
    transaction: Transaction,
  ) {
    when redeemer is {
      ProcessOrders -> is_withdrawal(transaction, own_ref)
      CancelLimitOrder -> {
        let Transaction { mint, extra_signatories, validity_range, .. } =
          transaction

        expect Some(datum) = maybe_datum

        expect OpenPositionOrder {
          position_datum: PositionDatum {
            owner_pkh,
            position_hash,
            entered_position_time,
            ..
          },
          open_position_type,
        } = datum.action

        expect list.length(get_validators_inputs(transaction)) == 1

        expect list.has(extra_signatories, owner_pkh)

        expect
          [(position_hash, position_asset_name, -1)] == assets.flatten(mint)

        // If markey order, can only be cancelled if it has been sitting idle and batcher havent picked it up
        if open_position_type == MarketOrder {
          let time_sub = get_lower_bound(validity_range) - entered_position_time
          // 3 minutes
          time_sub > 180_000
        } else {
          True
        }
      }

      // User can close the position even if it has not been picked up by batcher
      CloseOrderWhilePending(current_usd_price) -> {
        let Transaction { mint, extra_signatories, .. } = transaction

        expect Some(datum) = maybe_datum

        expect OpenPositionOrder {
          position_datum: PositionDatum {
            side,
            position_asset_amount,
            entered_at_usd_price,
            owner_pkh,
            position_hash,
            collateral_asset,
            collateral_asset_amount,
            owner_stake_key,
            ..
          },
          ..
        } = datum.action

        expect list.has(extra_signatories, owner_pkh)

        expect
          [(position_hash, position_asset_name, -1)] == assets.flatten(mint)

        let position_usd_value =
          calculate_position_usd_value_based_on_side(
            side,
            position_asset_amount,
            current_usd_price,
            entered_at_usd_price,
            0,
          )

        let collateral_value: Int =
          collateral_asset_amount * entered_at_usd_price

        let send_asset_amount =
          ( collateral_value + position_usd_value ) / current_usd_price

        let all_validators_inputs: List<Input> =
          get_all_validators_inputs(transaction)
        expect list.length(all_validators_inputs) == 1

        expect Some(input_from_script) = list.head(all_validators_inputs)

        let outputs_back_to_positions_validator: List<Output> =
          get_address_outputs(transaction, input_from_script.output.address)

        expect Some(output_to_positions_validator) =
          list.head(outputs_back_to_positions_validator)

        let strike_collateral_amount =
          quantity_of(
            input_from_script.output.value,
            strike_policy_id,
            strike_asset_name,
          )

        expect
          quantity_of(
            output_to_positions_validator.value,
            collateral_asset.policy_id,
            collateral_asset.asset_name,
          ) == collateral_asset_amount

        expect
          quantity_of(
            output_to_positions_validator.value,
            strike_policy_id,
            strike_asset_name,
          ) == strike_collateral_amount

        let return_pool_asset_amount =
          when send_asset_amount > collateral_asset_amount is {
            True -> 0
            False -> send_asset_amount - collateral_asset_amount
          }

        let expected_order_datum =
          OrderDatum {
            action: AutomatedClosePositionOrder {
              send_asset_amount,
              return_pool_asset_amount,
              strike_collateral_amount,
              owner_pkh,
              owner_stake_key,
            },
          }

        expect InlineDatum(output_datum) = output_to_positions_validator.datum
        let expected_order_datum_data: Data = expected_order_datum

        expected_order_datum_data == output_datum
      }
    }
  }

  withdraw(
    redeemer: OrdersWithdrawRedeemer,
    credential: Credential,
    transaction: Transaction,
  ) {
    let Transaction { inputs, mint, outputs, .. } = transaction

    expect Script(own_validator) = credential
    let (input_pool_utxo_index, output_pool_utxo_index) =
      redeemer.pool_utxo_index

    expect Some(input_pool_utxo) = list.at(inputs, input_pool_utxo_index)

    expect InlineDatum(input_pool_datum) = input_pool_utxo.output.datum
    expect input_pool_datum_typed: PoolDatum = input_pool_datum

    expect Some(output_pool_utxo) = list.at(outputs, output_pool_utxo_index)
    // Pool UTxO contains valid nft policy and asset name
    expect
      assets.quantity_of(
        input_pool_utxo.output.value,
        pool_nft_policy_id,
        pool_nft_asset_name,
      ) == 1
    // UTxO is sent back to the pool
    expect input_pool_utxo.output.address == output_pool_utxo.address
    // The functions checks the inputs and its corresponding outputs. Making sure of things such as liquidity providers that withdraw liquidity get their tokens
    // It also computes the expected pool output and datum. We then compare the expected pool output with the actual pool output to make sure the pool is in sync with the orders
    let expected_pool_output =
      valid_orders(
        redeemer.indexer,
        transaction,
        own_validator,
        input_pool_utxo.output.value,
        input_pool_datum_typed,
      )
    expect match(output_pool_utxo.value, expected_pool_output.value, >=)

    expect InlineDatum(output_pool_datum) = output_pool_utxo.datum
    expect output_pool_datum_typed: PoolDatum = output_pool_datum
    expect expected_pool_output.datum == output_pool_datum_typed

    expect expected_pool_output.mint == mint

    let PoolDatum { batcher_license, .. } = input_pool_datum_typed

    // Make sure the batcher license is in the inputs
    expect Some(Input { output: Output { value: batcher_value, .. }, .. }) =
      list.at(inputs, redeemer.batcher_license_utxo_index)

    expect [Pair(_tn, amount)] =
      batcher_value
        |> assets.tokens(batcher_license)
        |> dict.to_pairs()

    amount == 1
  }

  else(_) {
    fail
  }
}
