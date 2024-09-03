use aiken/crypto.{ScriptHash}

pub type WithdrawRedeemer {
  Withdraw
  Delegate(ScriptHash)
}
