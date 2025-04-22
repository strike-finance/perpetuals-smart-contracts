use aiken/collection/dict
use aiken/collection/list
use aiken/interval.{Finite, Interval, IntervalBound}
use cardano/address.{Credential, Script, from_script}
use cardano/assets.{AssetName, PolicyId, flatten, from_lovelace, quantity_of}
use cardano/transaction.{
  InlineDatum, Input, Output, OutputReference, Transaction,
}
use constants.{
  pool_nft_asset_name, position_asset_name, strike_asset_name, strike_policy_id,
}
use math.{calculate_position_usd_value_based_on_side}
use orders_validations.{valid_orders}
use test_constants.{
  manage_positions_script_hash, out_ref, protocol_nft_policy_id,
  test_position_policy_id, trader_pkh, underlying_asset,
}
use types.{
  ClosePositionOrder, ExpectedPoolOutput, LimitOrder, Long, MarketOrder,
  OpenPositionOrder, OrderDatum, PoolDatum, PositionDatum,
}
use utils.{
  get_address_outputs, get_all_validators_inputs, get_lower_bound,
  get_validators_inputs, is_withdrawal,
}

pub type OrdersWithdrawRedeemer {
  current_usd_price: Int,
  indexer: List<(Int, Int)>,
  pool_utxo_index: (Int, Int),
  batcher_license_utxo_index: Int,
}

pub type OrdersRedeemer {
  // Process all orders which includes providing and withdrawing liquidity
  ProcessOrders
  // Users placed limit order, can cancel anytime. Cancel open orders that has been sitting idle and havent been picked up by batcher
  CancelOrder
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
      CancelOrder -> {
        let Transaction { mint, extra_signatories, validity_range, .. } =
          transaction

        expect Some(datum) = maybe_datum

        expect OpenPositionOrder {
          position_datum: PositionDatum {
            owner_pkh,
            position_policy_id,
            entered_position_time,
            ..
          },
          open_position_type,
        } = datum.action

        expect list.length(get_validators_inputs(transaction)) == 1

        expect list.has(extra_signatories, owner_pkh)

        expect
          [(position_policy_id, position_asset_name, -1)] == assets.flatten(
            mint,
          )

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
            position_policy_id,
            collateral_asset,
            collateral_asset_amount,
            owner_stake_key,
            ..
          },
          open_position_type,
        } = datum.action

        expect list.has(extra_signatories, owner_pkh)

        expect
          [(position_policy_id, position_asset_name, -1)] == assets.flatten(
            mint,
          )

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

        // No assets has been borrowed from pool since this is just sitting at the orders
        // validator. The pool asset profit loss is the same value as what will be taken away or 
        // added to pool. Borrowed amount is technically 0 because it has not been batched yet so 
        // we don't need to update the pool datum of the lended amount
        let expected_order_datum =
          OrderDatum {
            action: ClosePositionOrder {
              owner_pkh,
              owner_stake_key,
              send_asset: collateral_asset,
              send_asset_amount,
              pool_asset_profit_loss: collateral_asset_amount - send_asset_amount,
              position_policy_id,
              borrowed_amount: 0,
            },
          }

        expect InlineDatum(output_datum) = output_to_positions_validator.datum
        let expected_order_datum_data: Data = expected_order_datum

        expect expected_order_datum_data == output_datum

        open_position_type != LimitOrder
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

    let underlying_asset_amount =
      quantity_of(
        input_pool_utxo.output.value,
        underlying_asset.policy_id,
        underlying_asset.asset_name,
      )
    // // The functions checks the inputs and its corresponding outputs. Making sure of things such as liquidity providers that withdraw liquidity get their tokens
    // // It also computes the expected pool output and datum. We then compare the expected pool output with the actual pool output to make sure the pool is in sync with the orders
    let ExpectedPoolOutput {
      underlying_asset_amount: expected_underlying_asset_amount,
      datum: expected_pool_output_datum,
      mint: expected_mint,
    } =
      valid_orders(
        redeemer.indexer,
        transaction,
        own_validator,
        underlying_asset_amount,
        input_pool_datum_typed,
        redeemer.current_usd_price,
      )

    expect
      quantity_of(
        output_pool_utxo.value,
        underlying_asset.policy_id,
        underlying_asset.asset_name,
      ) == expected_underlying_asset_amount

    expect
      quantity_of(
        output_pool_utxo.value,
        pool_nft_policy_id,
        pool_nft_asset_name,
      ) == 1

    let expected_asset_amount =
      when underlying_asset.policy_id == "" is {
        True -> 2
        _ -> 3
      }

    expect list.length(flatten(output_pool_utxo.value)) == expected_asset_amount

    expect InlineDatum(output_pool_datum) = output_pool_utxo.datum
    expect output_pool_datum_typed: PoolDatum = output_pool_datum
    expect expected_pool_output_datum == output_pool_datum_typed

    expect expected_mint == mint

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

test cancel_orders() {
  let orders_datum =
    OrderDatum {
      action: OpenPositionOrder {
        position_datum: PositionDatum {
          owner_pkh: trader_pkh,
          owner_stake_key: None,
          entered_at_usd_price: 100,
          position_policy_id: test_position_policy_id,
          manage_positions_script_hash,
          position_asset_amount: 10_000_000,
          stop_loss_usd_price: 98,
          take_profit_usd_price: 0,
          collateral_asset: underlying_asset,
          entered_position_time: 1727453227635,
          maintain_margin_amount: 5,
          hourly_usd_borrow_fee: 90000,
          collateral_asset_amount: 1_000_000,
          side: Long,
        },
        open_position_type: LimitOrder,
      },
    }

  let order_input =
    Input {
      output_reference: out_ref,
      output: Output {
        address: from_script(manage_positions_script_hash),
        value: from_lovelace(1_000_000)
          |> assets.add(test_position_policy_id, position_asset_name, 1),
        datum: InlineDatum(orders_datum),
        reference_script: None,
      },
    }

  let mint = assets.from_asset(test_position_policy_id, position_asset_name, -1)

  let tx =
    Transaction {
      inputs: [order_input],
      reference_inputs: [],
      outputs: [],
      fee: 0,
      mint,
      certificates: [],
      withdrawals: [],
      validity_range: Interval {
        lower_bound: IntervalBound {
          bound_type: Finite(1727453227635),
          is_inclusive: False,
        },
        upper_bound: IntervalBound {
          bound_type: Finite(1727456400000),
          is_inclusive: False,
        },
      },
      extra_signatories: [trader_pkh],
      redeemers: [],
      datums: dict.empty,
      id: #"0000000000000000000000000000000000000000000000000000000000000000",
      votes: [],
      proposal_procedures: [],
      current_treasury_amount: None,
      treasury_donation: None,
    }

  orders.spend(
    protocol_nft_policy_id,
    pool_nft_asset_name,
    Some(orders_datum),
    CancelOrder,
    out_ref,
    tx,
  )
}

test close_order_while_pending() {
  let orders_datum =
    OrderDatum {
      action: OpenPositionOrder {
        position_datum: PositionDatum {
          owner_pkh: trader_pkh,
          owner_stake_key: None,
          entered_at_usd_price: 90,
          position_policy_id: test_position_policy_id,
          manage_positions_script_hash,
          position_asset_amount: 10_000_000,
          stop_loss_usd_price: 98,
          take_profit_usd_price: 0,
          collateral_asset: underlying_asset,
          entered_position_time: 1727453227635,
          maintain_margin_amount: 5,
          hourly_usd_borrow_fee: 90000,
          collateral_asset_amount: 1_000_000,
          side: Long,
        },
        open_position_type: MarketOrder,
      },
    }

  let order_input =
    Input {
      output_reference: out_ref,
      output: Output {
        address: from_script(manage_positions_script_hash),
        value: from_lovelace(1_000_000)
          |> assets.add(test_position_policy_id, position_asset_name, 1),
        datum: InlineDatum(orders_datum),
        reference_script: None,
      },
    }

  let close_position_datum =
    OrderDatum {
      action: ClosePositionOrder {
        owner_pkh: trader_pkh,
        owner_stake_key: None,
        send_asset: underlying_asset,
        send_asset_amount: 1_900_000,
        pool_asset_profit_loss: -900_000,
        position_policy_id: test_position_policy_id,
        borrowed_amount: 0,
      },
    }

  let mint = assets.from_asset(test_position_policy_id, position_asset_name, -1)

  let output_to_positions_validator =
    Output {
      address: from_script(manage_positions_script_hash),
      value: from_lovelace(1_000_000),
      datum: InlineDatum(close_position_datum),
      reference_script: None,
    }

  let tx =
    Transaction {
      inputs: [order_input],
      reference_inputs: [],
      outputs: [output_to_positions_validator],
      fee: 0,
      mint,
      certificates: [],
      withdrawals: [],
      validity_range: Interval {
        lower_bound: IntervalBound {
          bound_type: Finite(1727453227635),
          is_inclusive: False,
        },
        upper_bound: IntervalBound {
          bound_type: Finite(1727456400000),
          is_inclusive: False,
        },
      },
      extra_signatories: [trader_pkh],
      redeemers: [],
      datums: dict.empty,
      id: #"0000000000000000000000000000000000000000000000000000000000000000",
      votes: [],
      proposal_procedures: [],
      current_treasury_amount: None,
      treasury_donation: None,
    }

  orders.spend(
    protocol_nft_policy_id,
    pool_nft_asset_name,
    Some(orders_datum),
    CloseOrderWhilePending(100),
    out_ref,
    tx,
  )
}
