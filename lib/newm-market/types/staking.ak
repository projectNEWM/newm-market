use aiken/crypto.{ScriptHash}
use cardano/assets.{Lovelace}

pub type StakingRedeemer {
  Withdraw
  DelegateStake(ScriptHash)
  RegisterStake(ScriptHash)
  UnRegisterStake(ScriptHash)
  DelegateDRep(ScriptHash)
  RegisterDRep(ScriptHash, Lovelace)
  UnRegisterDRep(ScriptHash, Lovelace)
  UpdateDRep(ScriptHash)
  CastVote
}
