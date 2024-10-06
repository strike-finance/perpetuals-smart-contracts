use cardano/transaction.{Transaction}

validator always_fail {
  spend(_datum: Option<Int>, _redeemer: Int, _o: Data, _self: Transaction) {
    False
  }

  else(_) {
    fail
  }
}
