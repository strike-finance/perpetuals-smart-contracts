use aiken/collection/list
use aiken/collection/pairs
use cardano/assets.{match}
use cardano/transaction.{
  InlineDatum, Input, Output, OutputReference, Transaction,
}
use types.{
  PoolDatum, PoolParams, PoolRedeemer, UpdateInterestRate, UpdateLiquidateMargin,
  UpdateMaxLeverageFactor, UpdateMaxStrikeHolderLeverageFactor, UpdateParam,
  UtilizePool,
}

// All pool validations are passed to the orders script. The orders script handles interactions with the pool UTxO. 
validator pools(params: PoolParams) {
  spend(
    datum: Option<PoolDatum>,
    _redeemer: Int,
    _own_ref: OutputReference,
    transaction: Transaction,
  ) {
    let withdrawals = transaction.withdrawals

    pairs.has_key(withdrawals, params.orders_stake_cred)
  }

  else(_) {
    False
  }
}
