use aiken/crypto.{ScriptHash}

pub type StakingRedeemer {
  Withdraw
  Delegate(ScriptHash)
  Register(ScriptHash)
}
