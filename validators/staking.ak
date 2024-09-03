use aiken/crypto.{ScriptHash}
use cardano/address.{Address, Credential, Script}
use cardano/addresses
use cardano/assets.{AssetName, Lovelace, PolicyId}
use cardano/certificate.{
  Certificate, DelegateBlockProduction, DelegateCredential,
}
use cardano/datum
use cardano/transaction.{Input, Transaction}
use cardano/tx
use cardano/value
use newm_market/types/reference.{ReferenceDatum}
use newm_market/types/staking.{Delegate, StakingRedeemer, Withdraw}
use validation/find
use validation/payout

validator contract(
  starter_pid: PolicyId,
  starter_tkn: AssetName,
  ref_hash: ScriptHash,
) {
  withdraw(
    redeemer: StakingRedeemer,
    credential: Credential,
    transaction: Transaction,
  ) {
    let Transaction { outputs, reference_inputs, withdrawals, .. } = transaction
    // get reference stuff
    let ref_addr: Address = address.from_script(ref_hash)
    let ref_input: Input = find.input_by_addr(reference_inputs, ref_addr)
    expect ref_datum: ReferenceDatum = datum.input_datum(ref_input)
    let reward_addr: Address =
      addresses.from_wallet(ref_datum.staking.reward_wallet)
    // if no reward is found error
    let reward: Lovelace = find.stake_reward_by_sc(withdrawals, credential)
    expect Withdraw = redeemer
    and {
      // data reference must hold correct token
      value.prove_exact_nft(ref_input.output.value, starter_pid, starter_tkn)?,
      // an at least here allows for small rewards to be withdrawn
      payout.at_least(reward_addr, assets.from_lovelace(reward), outputs)?,
    }
  }

  publish(
    redeemer: StakingRedeemer,
    certificate: Certificate,
    transaction: Transaction,
  ) {
    let Transaction { reference_inputs, extra_signatories, .. } = transaction
    // get reference stuff
    let ref_addr: Address = address.from_script(ref_hash)
    let ref_input: Input = find.input_by_addr(reference_inputs, ref_addr)
    expect ref_datum: ReferenceDatum = datum.input_datum(ref_input)
    expect Delegate(script_hash) = redeemer
    let new_delegation: Certificate =
      DelegateCredential {
        credential: Script(script_hash),
        delegate: DelegateBlockProduction {
          stake_pool: ref_datum.staking.pool_id,
        },
      }
    and {
      // data reference must hold correct token
      value.prove_exact_nft(ref_input.output.value, starter_pid, starter_tkn)?,
      // The only cert is for new delegation
      (certificate == new_delegation)?,
      // only keepers can update the data
      tx.verify_multisig(
        extra_signatories,
        ref_datum.keepers.pkhs,
        ref_datum.keepers.threshold,
      )?,
    }
  }

  else(_) {
    fail
  }
}
