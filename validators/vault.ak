use aiken/transaction.{Input, ScriptContext, Spend, Transaction}
use aiken/transaction/credential.{Address}
use aiken/transaction/value.{AssetName, PolicyId, Value}
use assist/count
use assist/data
use assist/find
use assist/payout
use assist/signing
use assist/types/hashes.{ValidatorHash}
use assist/types/token
use assist/types/wallet.{Wallet}
use assist/values
use newm_market/types/reference.{ReferenceDatum}
use newm_market/types/vault.{AddToVault, SubFromVault, VaultRedeemer}

validator(
  starter_pid: PolicyId,
  starter_tkn: AssetName,
  ref_hash: ValidatorHash,
) {
  fn params(
    this_datum: Wallet,
    redeemer: VaultRedeemer,
    context: ScriptContext,
  ) -> Bool {
    expect Spend(output_reference) = context.purpose
    // the transaction being validated
    let Transaction { inputs, outputs, reference_inputs, extra_signatories, .. } =
      context.transaction
    // the input being spent
    let this_input: Input = find.input_by_ref(inputs, output_reference)
    // this value being spent
    let this_value: Value = this_input.output.value
    // this address being spent from
    let this_addr: Address = this_input.output.address
    // the datum going back to the vault
    expect that_datum: Wallet = find.output_datum_by_addr(outputs, this_addr)
    when redeemer is {
      // anyone can add funds to the vault
      AddToVault { incoming } -> {
        // add the incoming token data to this value
        let that_value: Value =
          this_value |> token.add_tokens_to_value(incoming)
        //
        //
        //
        and {
          // datum can't change
          this_datum == that_datum,
          // can only add a token
          token.addition_only(incoming)?,
          // send at least that value to this address
          payout.at_least(this_addr, that_value, outputs)?,
          // single script input
          count.inputs_by_addr(inputs, this_addr, 1)?,
          // single script output
          count.outputs_by_addr(outputs, this_addr, 1)?,
        }
      }
      // only those with enough action tokens may subtract from the vault
      SubFromVault { outgoing } -> {
        // subtract the outgoing token data from this value
        let that_value: Value =
          this_value |> token.add_tokens_to_value(outgoing)
        // get the reference utxo and datum
        let ref_data_addr: Address = credential.from_script(ref_hash)
        let ref_data_input: Input =
          find.input_by_addr(reference_inputs, ref_data_addr)
        expect ref_data_datum: ReferenceDatum = data.input_datum(ref_data_input)
        //
        //
        //
        and {
          // datum can't change
          this_datum == that_datum,
          // can only subtract a token
          token.subtraction_only(outgoing)?,
          // the reference input value must be holding the pointer token
          values.prove_exact_nft(
            ref_data_input.output.value,
            starter_pid,
            starter_tkn,
          )?,
          // hot key must sign
          signing.verify_sig(extra_signatories, ref_data_datum.hot_key)?,
          // send that value to this address
          payout.exact(this_addr, that_value, outputs)?,
          // single script input
          count.inputs_by_addr(inputs, this_addr, 1)?,
          // single script output
          count.outputs_by_addr(outputs, this_addr, 1)?,
        }
      }
    }
  }
}
