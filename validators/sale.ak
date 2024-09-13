use aiken/collection/list
use aiken/crypto.{ScriptHash}
use cardano/address.{Address}
use cardano/addresses
use cardano/assets.{AssetName, PolicyId, Value}
use cardano/datum
use cardano/minting
use cardano/transaction.{Input, OutputReference, Transaction}
use cardano/tx
use cardano/value
use newm_market/types/queue.{QueuePurchase, QueueRedeemer}
use newm_market/types/reference.{ReferenceDatum}
use newm_market/types/sale.{
  Purchase, RemoveSale, SaleDatum, SaleRedeemer, StartSale, TransformSale,
}
use types/prefixes
use types/token
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
    redeemer: SaleRedeemer,
    output_reference: OutputReference,
    transaction: Transaction,
  ) {
    when maybe_datum is {
      Some(this_datum) ->
        if this_datum is SaleDatum {
          when redeemer is {
            // Buyer can purchase a bundle from the UTxO
            Purchase -> {
              let Transaction {
                inputs,
                outputs,
                reference_inputs,
                redeemers,
                ..
              } = transaction
              // data reference stuff
              let ref_addr: Address = address.from_script(ref_hash)
              let ref_input: Input =
                find.input_by_addr(reference_inputs, ref_addr)
              expect ref_datum: ReferenceDatum = datum.input_datum(ref_input)
              // the input being validated
              let this_input: Input =
                find.input_by_ref(inputs, output_reference)
              let this_address: Address = this_input.output.address
              // The queue address
              let queue_addr: Address =
                addresses.create_script_address(
                  ref_datum.contracts.queue,
                  ref_datum.contracts.stake,
                )
              // find the first queue input input
              let queue_input: Input = find.input_by_addr(inputs, queue_addr)
              let queue_out_ref: OutputReference = queue_input.output_reference
              // the sale_datum going back to the sale contract
              expect that_datum: SaleDatum =
                find.output_datum_by_addr(outputs, this_address)
              // this should fail for bad data serialization
              expect that_redeemer: QueueRedeemer =
                find.redeemer_by_ref(redeemers, queue_out_ref)
              expect QueuePurchase = that_redeemer
              //
              //
              //
              and {
                // single script input
                count.inputs_by_addr(inputs, queue_addr, 1)?,
                // single script output
                count.outputs_by_addr(outputs, queue_addr, 1)?,
                // input sale_datum and output sale_datum must equal
                (this_datum == that_datum)?,
                (ref_datum.pointer != this_datum.bundle.pid)?,
                (ref_datum.pointer != this_datum.cost.pid)?,
                // must be the correct reference data
                value.prove_exact_nft(
                  ref_input.output.value,
                  starter_pid,
                  starter_tkn,
                )?,
              }
            }
            // mint a pointer token to start off a sale
            StartSale { pointer } -> {
              let Transaction {
                inputs,
                outputs,
                reference_inputs,
                fee,
                mint,
                ..
              } = transaction
              // data reference stuff
              let ref_addr: Address = address.from_script(ref_hash)
              let ref_input: Input =
                find.input_by_addr(reference_inputs, ref_addr)
              expect ref_datum: ReferenceDatum = datum.input_datum(ref_input)
              // the input being validated
              let this_input: Input =
                find.input_by_ref(inputs, output_reference)
              let this_value: Value = this_input.output.value
              let this_address: Address = this_input.output.address
              // add the pointer token and remove the fee
              let that_value: Value =
                assets.add(this_value, ref_datum.pointer, pointer.tkn, 1)
                  |> assets.add(assets.ada_policy_id, assets.ada_asset_name, -fee)
              let mint_list: List<(PolicyId, AssetName, Int)> =
                mint |> assets.flatten()
              // the sale_datum going back to the contract
              expect that_datum: SaleDatum =
                find.output_datum_by_addr(outputs, this_address)
              //
              //
              //
              and {
                // must be the correct reference data
                value.prove_exact_nft(
                  ref_input.output.value,
                  starter_pid,
                  starter_tkn,
                )?,
                // The transaction fee can not exceed an upperbound
                reference.valid_tx_fee(fee, ref_datum.fees.start_sale_bound)?,
                // prove pointer has pointer token
                minting.is_occurring(mint_list, ref_datum.pointer, pointer.tkn)?,
                // prove this value doesn't have pointer token
                !value.prove_nft(this_value, ref_datum.pointer)?,
                // what is being sold can't be the pointer token
                (ref_datum.pointer != this_datum.bundle.pid)?,
                (ref_datum.pointer != this_datum.cost.pid)?,
                // value must go back to script
                payout.exact(this_address, that_value, outputs)?,
                // the sale_datum can not change
                (this_datum == that_datum)?,
                // single script input
                count.inputs_by_addr(inputs, this_address, 1)?,
                // single script output
                count.outputs_by_addr(outputs, this_address, 1)?,
              }
            }
            // Transform the sale by some token
            TransformSale { transforms } -> {
              let Transaction {
                inputs,
                outputs,
                reference_inputs,
                extra_signatories,
                ..
              } = transaction
              // data reference stuff
              let ref_addr: Address = address.from_script(ref_hash)
              let ref_input: Input =
                find.input_by_addr(reference_inputs, ref_addr)
              expect ref_datum: ReferenceDatum = datum.input_datum(ref_input)
              // the input being validated
              let this_input: Input =
                find.input_by_ref(inputs, output_reference)
              let this_value: Value = this_input.output.value
              let this_address: Address = this_input.output.address
              // this value is transformed into that value
              let that_value: Value =
                token.add_tokens_to_value(this_value, transforms)
              // that datum going back to the contract
              expect that_datum: SaleDatum =
                find.output_datum_by_addr(outputs, this_address)
              //
              //
              //
              and {
                // the owner must sign it
                tx.verify_signature(extra_signatories, this_datum.owner.pkh)?,
                // prove transforms does not have pointer token
                (list.all(transforms, fn(n) { ref_datum.pointer != n.pid }) == True)?,
                // value must go back to script
                payout.exact(this_address, that_value, outputs)?,
                // the this_datum can not change
                sale.valid_sale_datum_update(this_datum, that_datum)?,
                // single script input
                count.inputs_by_addr(inputs, this_address, 1)?,
                // single script output
                count.outputs_by_addr(outputs, this_address, 1)?,
                // must be the correct reference data
                value.prove_exact_nft(
                  ref_input.output.value,
                  starter_pid,
                  starter_tkn,
                )?,
              }
            }
            // Owner can remove their UTxO by burning the pointer
            RemoveSale -> {
              let Transaction {
                inputs,
                reference_inputs,
                mint,
                extra_signatories,
                ..
              } = transaction
              // data reference stuff
              let ref_addr: Address = address.from_script(ref_hash)
              let ref_input: Input =
                find.input_by_addr(reference_inputs, ref_addr)
              expect ref_datum: ReferenceDatum = datum.input_datum(ref_input)
              // the input being validated
              let this_input: Input =
                find.input_by_ref(inputs, output_reference)
              let this_value: Value = this_input.output.value
              let this_address: Address = this_input.output.address
              // check if the pointer token needs to be burned or not
              let burn_pointer_token: Bool =
                if value.prove_nft(this_value, ref_datum.pointer) {
                  // the input being validated
                  let mint_list: List<(PolicyId, AssetName, Int)> =
                    mint |> assets.flatten()
                  // must burn 1 pointer token and prove the ref token
                  and {
                    minting.by_prefix(
                      mint_list,
                      ref_datum.pointer,
                      prefixes.callable,
                      -1,
                    )?,
                    // must be the correct reference data
                    value.prove_exact_nft(
                      ref_input.output.value,
                      starter_pid,
                      starter_tkn,
                    )?,
                  }
                } else {
                  // if you dont hold the pointer then your sale never started
                  True
                }
              //
              //
              //
              and {
                // if have pointer burn else remove
                burn_pointer_token?,
                // the owner must sign it
                tx.verify_signature(extra_signatories, this_datum.owner.pkh)?,
                // single script input
                count.inputs_by_addr(inputs, this_address, 1)?,
              }
            }
          }
        } else {
          // incorrect data structures should be spendable
          True
        }
      // missing data structures should be spendable
      None -> True
    }
  }

  else(_) {
    fail
  }
}
