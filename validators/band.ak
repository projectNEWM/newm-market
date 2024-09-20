use aiken/collection/dict
use aiken/collection/list
use aiken/crypto.{ScriptHash}
use aiken/primitive/bytearray
use cardano/address.{Address}
use cardano/addresses
use cardano/assets.{AssetName, PolicyId, Value}
use cardano/datum
use cardano/minting
use cardano/transaction.{Input, OutputReference, Transaction, TransactionId}
use cardano/tx
use cardano/value
use newm_market/backup
use newm_market/constants
use newm_market/types/band.{
  AddToBand, BandLockUpRedeemer, BurnBand, MintBand, RemoveBand,
}
use newm_market/types/reference.{ReferenceDatum}
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
    redeemer: BandLockUpRedeemer,
    output_reference: OutputReference,
    transaction: Transaction,
  ) {
    when maybe_datum is {
      Some(this_datum) ->
        if this_datum is Wallet {
          when redeemer is {
            RemoveBand -> {
              let Transaction {
                inputs,
                outputs,
                reference_inputs,
                extra_signatories,
                ..
              } = transaction
              // the input being validated
              let this_input: Input =
                find.input_by_ref(inputs, output_reference)
              let this_value: Value = this_input.output.value
              // data reference stuff
              let ref_addr: Address = address.from_script(ref_hash)
              // find the first reference input
              let ref_input: Input =
                find.input_by_addr(reference_inputs, ref_addr)
              // the reference this_datum
              expect ref_datum: ReferenceDatum = datum.input_datum(ref_input)
              let owner_addr: Address = addresses.from_wallet(this_datum)
              //
              // Remove the band if not complete by sending the currently locked
              // band to the owner's address.
              //
              and {
                // owner must sign it
                tx.verify_signature(extra_signatories, this_datum.pkh)?,
                // owner must get the utxo back
                payout.exact(owner_addr, this_value, outputs)?,
                // single script input
                count.inputs_by_vkh(inputs, 1)?,
                // anything but a complete set can be removed
                !value.prove_exact_nft(
                  this_value,
                  ref_datum.batcher_data.batcher_pid,
                  constants.complete_set_token_name,
                )?,
                // data reference must be holding correct token
                value.prove_exact_nft(
                  ref_input.output.value,
                  starter_pid,
                  starter_tkn,
                )?,
              }
            }
            AddToBand { members } -> {
              let Transaction {
                inputs,
                outputs,
                reference_inputs,
                extra_signatories,
                ..
              } = transaction
              // the input being validated
              let this_input: Input =
                find.input_by_ref(inputs, output_reference)
              let this_value: Value = this_input.output.value
              // data reference stuff
              let ref_addr: Address = address.from_script(ref_hash)
              // find the first reference input
              let ref_input: Input =
                find.input_by_addr(reference_inputs, ref_addr)
              // the reference this_datum
              expect ref_datum: ReferenceDatum = datum.input_datum(ref_input)
              let that_value: Value =
                this_value |> token.add_tokens_to_value(members)
              let this_addr: Address = this_input.output.address
              expect that_datum: Wallet =
                find.output_datum_by_addr(outputs, this_addr)
              //
              // Add members to an incomplete band. The owner can add as many 
              // band members as needed. Members can be removed if required.
              //
              and {
                // this_datum cant change
                (this_datum == that_datum)?,
                // owner must sign it
                tx.verify_signature(extra_signatories, this_datum.pkh)?,
                // send at least the members and this_value to the address
                payout.at_least(this_addr, that_value, outputs)?,
                // single script input
                count.inputs_by_vkh(inputs, 1)?,
                // no script outputs
                count.outputs_by_vkh(outputs, 1)?,
                // anything but a complete set can be updated
                !value.prove_exact_nft(
                  this_value,
                  ref_datum.batcher_data.batcher_pid,
                  constants.complete_set_token_name,
                )?,
                // data reference must be holding correct token
                value.prove_exact_nft(
                  ref_input.output.value,
                  starter_pid,
                  starter_tkn,
                )?,
              }
            }
            MintBand -> {
              let Transaction {
                inputs,
                outputs,
                reference_inputs,
                extra_signatories,
                mint,
                ..
              } = transaction
              // the input being validated
              let this_input: Input =
                find.input_by_ref(inputs, output_reference)
              let this_value: Value = this_input.output.value
              // data reference stuff
              let ref_addr: Address = address.from_script(ref_hash)
              // find the first reference input
              let ref_input: Input =
                find.input_by_addr(reference_inputs, ref_addr)
              // the reference this_datum
              expect ref_datum: ReferenceDatum = datum.input_datum(ref_input)
              let this_addr: Address = this_input.output.address
              // get the list of token names from the monster pid
              let token_names1: List<AssetName> =
                this_value
                  |> assets.tokens(ref_datum.batcher_data.monster_pid1)
                  |> dict.keys()
              let token_names2: List<AssetName> =
                this_value
                  |> assets.tokens(ref_datum.batcher_data.monster_pid2)
                  |> dict.keys()
              let token_names: List<AssetName> =
                list.concat(token_names1, token_names2)
              expect that_datum: Wallet =
                find.output_datum_by_addr(outputs, this_addr)
              // check if something is being minted here
              let mint_list: List<(PolicyId, AssetName, Int)> =
                mint
                  |> assets.flatten()
              // get first utxo info
              let first_index: Int = find.first_input_index(inputs)
              let first_tx_hash: TransactionId = find.first_input_txid(inputs)
              // The prefixes are the same length here
              let batcher_token_name: AssetName =
                value.unique_token_name(
                  first_tx_hash,
                  first_index,
                  constants.batcher_token_name,
                )
              let complete_set_token_name: AssetName =
                value.unique_token_name(
                  first_tx_hash,
                  first_index,
                  constants.complete_set_token_name,
                )
              // the complete set nft is sent back to the contract
              let that_value: Value =
                this_value
                  |> assets.add(
                      ref_datum.batcher_data.batcher_pid,
                      complete_set_token_name,
                      1,
                    )
              //
              // Mints the completed asset token and a batcher certificate to
              // the owner of the UTxO.
              //
              and {
                // datums cant change
                (this_datum == that_datum)?,
                // owner must sign it
                tx.verify_signature(extra_signatories, this_datum.pkh)?,
                // at least this value and teh complete set token sent to this address
                payout.at_least(this_addr, that_value, outputs)?,
                // single script input
                count.inputs_by_vkh(inputs, 1)?,
                // single script outputs
                count.outputs_by_vkh(outputs, 1)?,
                // must have a full set
                band.has_correct_tokens(
                  token_names,
                  ref_datum.batcher_data.monster_prefixes,
                )?,
                // mint exactly 1 batcher token
                minting.exact(
                  mint_list,
                  ref_datum.batcher_data.batcher_pid,
                  batcher_token_name,
                  1,
                )?,
                // mint exactly 1 complete set token
                minting.exact(
                  mint_list,
                  ref_datum.batcher_data.batcher_pid,
                  complete_set_token_name,
                  1,
                )?,
                // data reference must be holding correct token
                value.prove_exact_nft(
                  ref_input.output.value,
                  starter_pid,
                  starter_tkn,
                )?,
              }
            }
            BurnBand(tkn_ending) -> {
              let Transaction { inputs, reference_inputs, mint, .. } =
                transaction
              // the input being validated
              let this_input: Input =
                find.input_by_ref(inputs, output_reference)
              let this_value: Value = this_input.output.value
              // data reference stuff
              let ref_addr: Address = address.from_script(ref_hash)
              // find the first reference input
              let ref_input: Input =
                find.input_by_addr(reference_inputs, ref_addr)
              // the reference this_datum
              expect ref_datum: ReferenceDatum = datum.input_datum(ref_input)
              // check if something is being minted here
              let mint_list: List<(PolicyId, AssetName, Int)> =
                mint
                  |> assets.flatten()
              //
              // Burns a complete asset and batcher cerificate that have matching
              // token endings.
              //
              and {
                // single script input
                count.inputs_by_vkh(inputs, 1)?,
                // burn exactly 1 batcher token
                minting.exact(
                  mint_list,
                  ref_datum.batcher_data.batcher_pid,
                  bytearray.concat(constants.batcher_token_name, tkn_ending),
                  -1,
                )?,
                // mint exactly 1 complete set token
                minting.exact(
                  mint_list,
                  ref_datum.batcher_data.batcher_pid,
                  bytearray.concat(
                    constants.complete_set_token_name,
                    tkn_ending,
                  ),
                  -1,
                )?,
                // anything but a complete set can be removed
                value.prove_exact_nft(
                  this_value,
                  ref_datum.batcher_data.batcher_pid,
                  bytearray.concat(
                    constants.complete_set_token_name,
                    tkn_ending,
                  ),
                )?,
                // data reference must be holding correct token
                value.prove_exact_nft(
                  ref_input.output.value,
                  starter_pid,
                  starter_tkn,
                )?,
              }
            }
          }
        } else {
          // incorrect data structures should be spendable
          let Transaction { reference_inputs, extra_signatories, .. } =
            transaction
          backup.logic(ref_hash, reference_inputs, extra_signatories)?
        }
      // missing data structures should be spendable
      None -> {
        let Transaction { reference_inputs, extra_signatories, .. } =
          transaction
        backup.logic(ref_hash, reference_inputs, extra_signatories)?
      }
    }
  }

  else(_) {
    fail
  }
}
