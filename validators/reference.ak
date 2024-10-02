use aiken/primitive/bytearray
use cardano/address.{Address}
use cardano/assets.{AssetName, PolicyId, Value}
use cardano/transaction.{Input, OutputReference, Transaction}
use cardano/tx
use cardano/value
use newm_market/backup
use newm_market/types/reference.{ReferenceDatum}
use types/wallet
use validation/count
use validation/find
use validation/payout

validator contract(starter_pid: PolicyId, starter_tkn: AssetName) {
  spend(
    maybe_datum: Option<Data>,
    _redeemer: Void,
    output_reference: OutputReference,
    transaction: Transaction,
  ) {
    // tx being validated
    let Transaction { inputs, reference_inputs, outputs, extra_signatories, .. } =
      transaction
    let this_input: Input = find.input_by_ref(inputs, output_reference)
    let this_addr: Address = this_input.output.address
    when maybe_datum is {
      Some(datum) ->
        if datum is ReferenceDatum {
          // this should allow the lovelace to change naturally with the updates
          let that_value: Value =
            this_input.output.value |> assets.without_lovelace
          expect that_datum: ReferenceDatum =
            find.output_datum_by_addr(outputs, this_addr)
          //
          // That datum can only update logically and only by the keepers in this
          // datum. The value validation is such that the lovelace may change
          // but whatever non-lovelace assets must remain on the UTxO.
          //
          and {
            // send back to script but allow lovelace increase or decrease
            payout.at_least(this_addr, that_value, outputs)?,
            // must hold starter token
            value.prove_exact_nft(that_value, starter_pid, starter_tkn)?,
            // single script input
            count.inputs_by_addr(inputs, this_addr, 1)?,
            // single script output
            count.outputs_by_addr(outputs, this_addr, 1)?,
            // only keepers can update the data
            tx.verify_multisig(
              extra_signatories,
              datum.keepers.pkhs,
              datum.keepers.threshold,
            )?,
            // hot key needs to be valid length
            (bytearray.length(that_datum.hot_key) == 28)?,
            // keepers are logical and valid
            reference.is_valid_keepers(that_datum.keepers)?,
            // can't have a invalid reward wallet
            wallet.is_valid(that_datum.staking.reward_wallet)?,
            // contracts either exist or dont
            reference.is_valid_contracts(that_datum.contracts)?,
          }
        } else {
          // incorrect data structures should be spendable
          backup.logic(
            this_addr,
            reference_inputs,
            extra_signatories,
            starter_pid,
            starter_tkn,
          )?
        }
      // missing data structures should be spendable
      None ->
        backup.logic(
          this_addr,
          reference_inputs,
          extra_signatories,
          starter_pid,
          starter_tkn,
        )?
    }
  }

  else(_) {
    fail
  }
}
