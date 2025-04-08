use aiken/collection/pairs
use cardano/address.{Credential}
use cardano/transaction.{Transaction}

pub type LiquidityRedeemer {
  ProvideLiquidity
  BurnLiquidity
}

// Liquidity Providers will be able to provide liquidity by minting lp tokens
// The lp tokens will be sent to the orders script. Once the orders script is done processing the liquidity
// The lp tokens will then be sent to the liquidity provider's wallet. Liquidity Providers has the ability to choose
// to provide liquidity for the long side, short side, or both
validator liquidity_mint(orders_script_credential: Credential) {
  // Calculations of how much liquidity tokens that should be minted or burnt is off-setted to the orders validator
  mint(_redeemer: Data, _policy_id: ByteArray, self: Transaction) {
    let withdrawals = self.withdrawals

    pairs.has_key(withdrawals, orders_script_credential)
  }

  else(_) {
    fail
  }
}
