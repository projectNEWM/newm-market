use aiken/collection/list
use aiken/crypto.{ScriptHash}
use cardano/address.{Address}
use cardano/assets.{AssetName, PolicyId, Value}
use cardano/datum
use cardano/transaction.{Input, OutputReference, Transaction}
use cardano/tx
use cardano/value
use newm_market/backup
use newm_market/constants
use newm_market/types/reference.{ReferenceDatum}
use newm_market/types/vault.{
  AddToVault, RemoveVault, SubFromVault, VaultRedeemer,
}
use types/token
use types/wallet.{Wallet}
use validation/count
use validation/find
use validation/payout

validator contract(
  starter_pid: PolicyId,
  starter_tkn: AssetName,
  ref_hash: ScriptHash,
) {
  spend(
    maybe_datum: Option<Data>,
    redeemer: VaultRedeemer,
    output_reference: OutputReference,
    transaction: Transaction,
  ) {
    when maybe_datum is {
      Some(this_datum) ->
        if this_datum is Wallet {
          when redeemer is {
            AddToVault { incoming } -> {
              // the transaction being validated
              let Transaction { inputs, outputs, extra_signatories, .. } =
                transaction
              // the input being spent
              let this_input: Input =
                find.input_by_ref(inputs, output_reference)
              // this value being spent
              let this_value: Value = this_input.output.value
              // this address being spent from
              let this_addr: Address = this_input.output.address
              // the datum going back to the vault
              expect that_datum: Wallet =
                find.output_datum_by_addr(outputs, this_addr)
              // add the incoming token data to this value
              let that_value: Value =
                this_value |> token.add_tokens_to_value(incoming)
              //
              // Only the owner of the vault may add tokens to the vault. There
              // must always be at least the vault minimum lovelace, which is
              // always owned by the owner.
              //
              and {
                // the batcher deposit can not be removed
                (assets.lovelace_of(that_value) >= constants.vault_minimum_lovelace)?,
                // hot key must sign
                tx.verify_signature(extra_signatories, this_datum.pkh)?,
                // datum can't change
                (this_datum == that_datum)?,
                // can only add a token
                token.addition_only(incoming)?,
                // send at least that value to this address
                payout.exact(this_addr, that_value, outputs)?,
                // single script input
                count.inputs_by_addr(inputs, this_addr, 1)?,
                // single script output
                count.outputs_by_addr(outputs, this_addr, 1)?,
              }
            }
            SubFromVault { outgoing } -> {
              // the transaction being validated
              let Transaction {
                inputs,
                outputs,
                reference_inputs,
                extra_signatories,
                ..
              } = transaction
              // the input being spent
              let this_input: Input =
                find.input_by_ref(inputs, output_reference)
              // this value being spent
              let this_value: Value = this_input.output.value
              // this address being spent from
              let this_addr: Address = this_input.output.address
              // the datum going back to the vault
              expect that_datum: Wallet =
                find.output_datum_by_addr(outputs, this_addr)
              // subtract the outgoing token data from this value
              let that_value: Value =
                this_value |> token.add_tokens_to_value(outgoing)
              // get the reference utxo and datum
              let ref_data_addr: Address = address.from_script(ref_hash)
              let ref_data_input: Input =
                find.input_by_addr(reference_inputs, ref_data_addr)
              expect ref_data_datum: ReferenceDatum =
                datum.input_datum(ref_data_input)
              //
              // Only the hot key can subtract tokens from the vault. There
              // be at least the vault minimum lovelace leftover after 
              // subtraction. This maintains the minimum lovelace for the owner.
              //
              and {
                // the batcher deposit can not be removed
                (assets.lovelace_of(that_value) >= constants.vault_minimum_lovelace)?,
                // datum can't change
                (this_datum == that_datum)?,
                // can only subtract a token
                token.subtraction_only(outgoing)?,
                // the reference input value must be holding the pointer token
                value.prove_exact_nft(
                  ref_data_input.output.value,
                  starter_pid,
                  starter_tkn,
                )?,
                // hot key must sign
                tx.verify_signature(extra_signatories, ref_data_datum.hot_key)?,
                // send that value to this address
                payout.exact(this_addr, that_value, outputs)?,
                // single script input
                count.inputs_by_addr(inputs, this_addr, 1)?,
                // single script output
                count.outputs_by_addr(outputs, this_addr, 1)?,
              }
            }
            RemoveVault -> {
              // the transaction being validated
              let Transaction { inputs, extra_signatories, .. } = transaction
              // the input being spent
              let this_input: Input =
                find.input_by_ref(inputs, output_reference)
              // this value being spent
              let this_value: Value = this_input.output.value
              // this address being spent from
              let this_addr: Address = this_input.output.address
              //
              // Only the owner of the vault may remove the vault entirely if
              // and only if the minimum required lovelace exists on the UTxO.
              // No other tokens may exist. The owner may send the UTxO anywhere.
              //
              and {
                // there can only be a single policy ADA
                (( assets.policies(this_value) |> list.length ) == 1)?,
                // the amount of lovelace must be the minimum
                (assets.lovelace_of(this_value) == constants.vault_minimum_lovelace)?,
                // hot key must sign
                tx.verify_signature(extra_signatories, this_datum.pkh)?,
                // single script input
                count.inputs_by_addr(inputs, this_addr, 1)?,
              }
            }
          }
        } else {
          // incorrect data structures should be spendable
          let Transaction { reference_inputs, extra_signatories, .. } =
            transaction
          let ref_data_addr: Address = address.from_script(ref_hash)
          backup.logic(
            ref_data_addr,
            reference_inputs,
            extra_signatories,
            starter_pid,
            starter_tkn,
          )?
        }
      // missing data structures should be spendable
      None -> {
        let Transaction { reference_inputs, extra_signatories, .. } =
          transaction
        let ref_data_addr: Address = address.from_script(ref_hash)
        backup.logic(
          ref_data_addr,
          reference_inputs,
          extra_signatories,
          starter_pid,
          starter_tkn,
        )?
      }
    }
  }

  else(_) {
    fail
  }
}
