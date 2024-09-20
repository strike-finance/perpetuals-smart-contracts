use aiken/transaction.{Input, Output, ScriptContext, find_script_outputs}
use types.{ComparePerpetualInfo}
use utils.{
  check_spend, get_input_from_distribute_info, get_inputs_from_script,
  get_output_to_distribute_info, perpetuals_info_list_matches,
}

type Redeemer {
  perpetual_validator_hash: ByteArray,
}

validator pooled_assets {
  spend(_datum, redeemer: Int, ctx: ScriptContext) {
    check_spend(ctx)
  }

  withdraw(redeemer: Redeemer, ctx: ScriptContext) {
    let inputs_from_perpetual_validator: List<Input> =
      get_inputs_from_script(
        ctx.transaction.inputs,
        redeemer.perpetual_validator_hash,
      )

    let inputs_from_perpetual_validator_info: List<ComparePerpetualInfo> =
      get_input_from_distribute_info(inputs_from_perpetual_validator, ctx)

    let outputs_to_distribute_validator: List<Output> =
      find_script_outputs(
        ctx.transaction.outputs,
        redeemer.perpetual_validator_hash,
      )

    let outputs_to_distribute_validator_info: List<ComparePerpetualInfo> =
      get_output_to_distribute_info(outputs_to_distribute_validator, ctx)

    let info_matches: Bool =
      perpetuals_info_list_matches(
        inputs_from_perpetual_validator_info,
        outputs_to_distribute_validator_info,
      )

    info_matches
  }

  else(_) {
    fail
  }
}
