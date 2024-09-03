// use aiken/transaction.{Input,
//   OutputReference, ScriptContext, Spend, Transaction}
// use aiken/transaction/credential.{Address}
// use aiken/transaction/value.{AssetName, PolicyId, Value}
// use assist/addresses
// use assist/count
// use assist/data
// use assist/find
// use assist/payout
// use assist/signing
// use assist/types/hashes.{ValidatorHash}
// use assist/types/moment.{Moment}
// use assist/types/token.{Token}
// use assist/types/wallet.{Wallet}
// use assist/values
// use newm_market/constants.{usd_policy_id}
// use newm_market/types/oracle.{OracleDatum}
// use newm_market/types/queue.{
//   QueueCancel, QueueDatum, QueuePurchase, QueueRedeemer, QueueRefund,
// }
// use newm_market/types/reference.{ReferenceDatum}
// use newm_market/types/sale.{Purchase, SaleDatum, SaleRedeemer}
// use newm_market/types/vault.{AddToVault, VaultRedeemer}

// validator(
//   starter_pid: PolicyId,
//   starter_tkn: AssetName,
//   ref_hash: ValidatorHash,
// ) {
//   fn params(
//     this_datum: QueueDatum,
//     redeemer: QueueRedeemer,
//     context: ScriptContext,
//   ) -> Bool {
//     expect Spend(output_reference) = context.purpose
//     // the transaction being validated
//     let Transaction {
//       inputs,
//       outputs,
//       reference_inputs,
//       fee,
//       extra_signatories,
//       redeemers,
//       validity_range,
//       ..
//     } = context.transaction
//     // the reference this_datum
//     // the input being validated
//     let this_input: Input = find.input_by_ref(inputs, output_reference)
//     let this_value: Value = this_input.output.value
//     let this_addr: Address = this_input.output.address
//     when redeemer is {
//       // a batcher can complete a purchase from the queue, for profit
//       QueuePurchase -> {
//         //
//         // data reference stuff
//         let ref_addr: Address = credential.from_script(ref_hash)
//         let ref_input: Input = find.input_by_addr(reference_inputs, ref_addr)
//         expect ref_datum: ReferenceDatum = data.input_datum(ref_input)
//         //
//         // sale stuff
//         let sale_addr: Address =
//           addresses.create_script_address(
//             ref_datum.contracts.sale,
//             ref_datum.contracts.stake,
//           )
//         let sale_input: Input = find.input_by_addr(inputs, sale_addr)
//         let sale_out_ref: OutputReference = sale_input.output_reference
//         let sale_value: Value = sale_input.output.value
//         expect sale_datum: SaleDatum = data.input_datum(sale_input)
//         //
//         // oracle profit stuff
//         let (newm_profit_amt, cost_token): (Int, Token) =
//           if and {
//             ref_datum.profit_data.profit_margin == 0,
//             sale_datum.cost.pid != usd_policy_id,
//           } {
//             (0, sale_datum.cost)
//           } else {
//             let feed_addr: Address =
//               credential.from_script(ref_datum.profit_data.feed_vkh)
//             let feed_input: Input =
//               find.input_by_addr(reference_inputs, feed_addr)
//             expect feed_datum: OracleDatum = data.input_datum(feed_input)
//             let feed_price: Int = oracle.get_price(feed_datum)
//             let feed_moment: Moment = oracle.get_moment(feed_datum)
//             if and {
//               // oracle must have correct feed token
//               values.prove_exact_nft(
//                 feed_input.output.value,
//                 ref_datum.profit_data.feed_pid,
//                 ref_datum.profit_data.feed_tkn,
//               )?,
//               // oracle moment needs to be valid
//               moment.is_contained(feed_moment, validity_range)?,
//             } {
//               let amt: Int =
//                 oracle.calculate_profit(
//                   ref_datum.profit_data.profit_margin,
//                   feed_price,
//                 )
//               if sale_datum.cost.pid == usd_policy_id {
//                 let usd_amt: Int =
//                   oracle.calculate_profit(sale_datum.cost.amt, feed_price)
//                 (
//                   amt,
//                   Token {
//                     pid: ref_datum.profit_data.profit_pid,
//                     tkn: ref_datum.profit_data.profit_tkn,
//                     amt: usd_amt,
//                   },
//                 )
//               } else {
//                 (amt, sale_datum.cost)
//               }
//             } else {
//               fail @"Invalid Oracle"
//             }
//           }
//         //
//         // vault stuff
//         let vault_logic: Bool =
//           if ref_datum.profit_data.profit_margin == 0 {
//             // do not anything with the vault if the margin is set to zero
//             True
//           } else {
//             let vault_addr: Address =
//               addresses.create_script_address(
//                 ref_datum.contracts.vault,
//                 ref_datum.contracts.stake,
//               )
//             let vault_input: Input = find.input_by_addr(inputs, vault_addr)
//             let vault_out_ref: OutputReference = vault_input.output_reference
//             let vault_value: Value = vault_input.output.value
//             //
//             // the value returning to the vault contract
//             // add the newm profit
//             let return_vault_value: Value =
//               vault_value
//                 |> value.add(
//                     ref_datum.profit_data.profit_pid,
//                     ref_datum.profit_data.profit_tkn,
//                     newm_profit_amt,
//                   )
//             //
//             // get correct vault
//             expect that_vault_redeemer: VaultRedeemer =
//               find.redeemer_by_ref(redeemers, vault_out_ref)
//             let is_correct_vault_redeemer: Bool =
//               when that_vault_redeemer is {
//                 // only the purchase redeemer is allowed
//                 AddToVault(_) -> True
//                 _ -> fail @"Incorrect Vault Redeemer"
//               }
//             // do the vault logic here since removing from queue is dependent on the newm_profit
//             and {
//               // vault gets the profit
//               payout.exact(vault_addr, return_vault_value, outputs)?,
//               // correct redeemer on the vault contract side
//               is_correct_vault_redeemer?,
//             }
//           }
//         //
//         // find the quantity of the bundle token on the sale utxo
//         let cur_bundle_tkn_amt: Int =
//           value.quantity_of(
//             sale_value,
//             sale_datum.bundle.pid,
//             sale_datum.bundle.tkn,
//           )
//         let number_of_bundles: Int =
//           // allows for a partial bundle to be fulfilled
//           // if the current number of bundles is less than what the queue wants
//           // then get the leftover for a part fill else get what you want
//           if
//           cur_bundle_tkn_amt / sale_datum.bundle.amt < this_datum.number_of_bundles{
//             // so get the left over
//             cur_bundle_tkn_amt / sale_datum.bundle.amt
//           } else {
//             // or get what you want
//             this_datum.number_of_bundles
//           }
//         //
//         // calculate the total cost for the number of bundles
//         let total_cost: Token = token.multiply(cost_token, number_of_bundles)
//         //
//         // the value returning to the sale contract
//         // add the cost to the sale value and remove the bundles
//         let return_sale_value: Value =
//           token.add_token_to_value(sale_value, total_cost)
//             |> value.add(
//                 sale_datum.bundle.pid,
//                 sale_datum.bundle.tkn,
//                 -number_of_bundles * sale_datum.bundle.amt,
//               )
//         //
//         // The value returning to the queue contract, if profit margin is zero 
//         // then this is still fine 
//         // remove the fee, cost value, incentive, and profit
//         // add the bundle value
//         let return_queue_value: Value =
//           token.add_token_to_value(this_value, token.negative(total_cost))
//             |> value.merge(value.negate(fee))
//             |> value.add(
//                 sale_datum.bundle.pid,
//                 sale_datum.bundle.tkn,
//                 number_of_bundles * sale_datum.bundle.amt,
//               )
//             |> value.add(
//                 this_datum.incentive.pid,
//                 this_datum.incentive.tkn,
//                 -this_datum.incentive.amt,
//               )
//             |> value.add(
//                 ref_datum.profit_data.profit_pid,
//                 ref_datum.profit_data.profit_tkn,
//                 -newm_profit_amt,
//               )
//         //
//         // the queue_datum going back to the queue contract
//         expect that_datum: QueueDatum =
//           find.output_datum_by_addr(outputs, this_addr)
//         //
//         // get the correct sale
//         expect that_sale_redeemer: SaleRedeemer =
//           find.redeemer_by_ref(redeemers, sale_out_ref)
//         let is_correct_sale_redeemer: Bool =
//           when that_sale_redeemer is {
//             // only the purchase redeemer is allowed
//             Purchase -> True
//             _ -> fail @"Incorrect Sale Redeemer"
//           }
//         //
//         //
//         //
//         and {
//           // if vault is applicable then check the logic
//           vault_logic?,
//           // single sale script input
//           count.inputs_by_addr(inputs, sale_addr, 1)?,
//           // one sale script output
//           count.outputs_by_addr(outputs, sale_addr, 1)?,
//           // queue gets the bundle
//           payout.exact(this_addr, return_queue_value, outputs)?,
//           // sale gets the cost
//           payout.exact(sale_addr, return_sale_value, outputs)?,
//           // correct redeemer on the sale contract side
//           is_correct_sale_redeemer?,
//           // keep the datum constant
//           (this_datum == that_datum)?,
//           // prove correct sale datum
//           values.prove_exact_nft(
//             sale_value,
//             ref_datum.pointer,
//             this_datum.pointer_tkn,
//           )?,
//           // number of bundles must be positive
//           (this_datum.number_of_bundles > 0)?,
//           // maximum number of bundles must be positive
//           (sale_datum.max_bundle_size > 0)?,
//           // the number of bundles can be more than max
//           (sale_datum.max_bundle_size >= this_datum.number_of_bundles)?,
//           // must be non-negative incentive
//           (this_datum.incentive.amt >= 0)?,
//           // bundle amount must be postiive
//           (sale_datum.bundle.amt > 0)?,
//           // must have at least one bundle for sale
//           (cur_bundle_tkn_amt >= sale_datum.bundle.amt)?,
//           // the fee for this transaction must be valid
//           reference.valid_tx_fee(fee, ref_datum.fees.purchase_queue_bound)?,
//           // tx must be spending the certificate of batcher authenticity
//           // it can't be this output reference or the sale output reference
//           queue.prove_existence_of_batcher(
//             ref_datum.batcher_data.batcher_pid,
//             inputs,
//             output_reference,
//             sale_out_ref,
//           )?,
//         }
//       }
//       // a batcher can auto refund a completed queue item, not for profit
//       QueueRefund -> {
//         //
//         // data reference stuff
//         let ref_addr: Address = credential.from_script(ref_hash)
//         let ref_input: Input = find.input_by_addr(reference_inputs, ref_addr)
//         expect ref_datum: ReferenceDatum = data.input_datum(ref_input)
//         //
//         // sale stuff
//         let sale_addr: Address =
//           addresses.create_script_address(
//             ref_datum.contracts.sale,
//             ref_datum.contracts.stake,
//           )
//         let sale_input: Input = find.input_by_addr(reference_inputs, sale_addr)
//         let sale_out_ref: OutputReference = sale_input.output_reference
//         let sale_value: Value = sale_input.output.value
//         expect sale_datum: SaleDatum = data.input_datum(sale_input)
//         //
//         // oracle profit stuff
//         let (newm_profit_amt, cost_token): (Int, Token) =
//           if and {
//             ref_datum.profit_data.profit_margin == 0,
//             sale_datum.cost.pid != usd_policy_id,
//           } {
//             (0, sale_datum.cost)
//           } else {
//             let feed_addr: Address =
//               credential.from_script(ref_datum.profit_data.feed_vkh)
//             let feed_input: Input =
//               find.input_by_addr(reference_inputs, feed_addr)
//             expect feed_datum: OracleDatum = data.input_datum(feed_input)
//             let feed_price: Int = oracle.get_price(feed_datum)
//             let feed_moment: Moment = oracle.get_moment(feed_datum)
//             if and {
//               // oracle must have correct feed token
//               values.prove_exact_nft(
//                 feed_input.output.value,
//                 ref_datum.profit_data.feed_pid,
//                 ref_datum.profit_data.feed_tkn,
//               )?,
//               // oracle moment needs to be valid
//               moment.is_contained(feed_moment, validity_range)?,
//             } {
//               let amt: Int =
//                 oracle.calculate_profit(
//                   ref_datum.profit_data.profit_margin,
//                   feed_price,
//                 )
//               if sale_datum.cost.pid == usd_policy_id {
//                 let usd_amt: Int =
//                   oracle.calculate_profit(sale_datum.cost.amt, feed_price)
//                 (
//                   amt,
//                   Token {
//                     pid: ref_datum.profit_data.profit_pid,
//                     tkn: ref_datum.profit_data.profit_tkn,
//                     amt: usd_amt,
//                   },
//                 )
//               } else {
//                 (amt, sale_datum.cost)
//               }
//             } else {
//               fail @"Invalid Oracle"
//             }
//           }
//         //
//         // calculate the total cost for the number of bundles
//         let total_cost: Token =
//           token.multiply(cost_token, this_datum.number_of_bundles)
//         // current number of bundle tokens
//         let cur_bundle_tkn_amt: Int =
//           value.quantity_of(
//             sale_value,
//             sale_datum.bundle.pid,
//             sale_datum.bundle.tkn,
//           )
//         // check the state of the sale with a queue item.
//         let is_refund_allowed: Bool =
//           if
//           // Can the queue entry even pay for the token bundle if you removed 
//           // the incentive and what would be the profit?
//           value.quantity_of(
//             this_value
//               |> value.add(
//                   this_datum.incentive.pid,
//                   this_datum.incentive.tkn,
//                   -this_datum.incentive.amt,
//                 )
//               |> value.add(
//                   ref_datum.profit_data.profit_pid,
//                   ref_datum.profit_data.profit_tkn,
//                   -newm_profit_amt,
//                 ),
//             total_cost.pid,
//             total_cost.tkn,
//           ) >= total_cost.amt{
//             // The queue entry could pay for some amount of bundles if they exist.
//             //
//             // Does the current sale have enough tokens for at least 1 bundle
//             if cur_bundle_tkn_amt >= sale_datum.bundle.amt {
//               // the sale has at least one bundle
//               //
//               // Do Not Refund!
//               False
//             } else {
//               // the sale doesn't have any bundles for sale
//               //
//               // Refund!
//               True
//             }
//           } else {
//             // The validating value does not contain the cost value.
//             //
//             // Refund!
//             True
//           }
//         // the queue entry owner address
//         let owner_addr: Address = addresses.from_wallet(this_datum.owner)
//         // subtract the fee and the incentive
//         let that_value: Value =
//           value.merge(this_value, value.negate(fee))
//             |> value.add(
//                 this_datum.incentive.pid,
//                 this_datum.incentive.tkn,
//                 -this_datum.incentive.amt,
//               )
//         //
//         //
//         //
//         and {
//           // single script input
//           count.inputs_by_addr(inputs, this_addr, 1)?,
//           // prove correct reference datum
//           values.prove_exact_nft(
//             ref_input.output.value,
//             starter_pid,
//             starter_tkn,
//           )?,
//           // prove correct sale datum
//           values.prove_exact_nft(
//             sale_value,
//             ref_datum.pointer,
//             this_datum.pointer_tkn,
//           )?,
//           // number of bundles must be positive
//           (this_datum.number_of_bundles > 0)?,
//           // maximum number of bundles must be positive
//           (sale_datum.max_bundle_size > 0)?,
//           // the number of bundles can be more than max
//           (sale_datum.max_bundle_size >= this_datum.number_of_bundles)?,
//           // must be non-negative incentive
//           (this_datum.incentive.amt >= 0)?,
//           // can the queue entry be refunded
//           is_refund_allowed?,
//           // the fee for this transaction must be valid
//           reference.valid_tx_fee(fee, ref_datum.fees.refund_queue_bound)?,
//           // owner must get the utxo back
//           payout.exact(owner_addr, that_value, outputs)?,
//           // tx must be spending the certificate of batcher authenticity
//           queue.prove_existence_of_batcher(
//             ref_datum.batcher_data.batcher_pid,
//             inputs,
//             output_reference,
//             sale_out_ref,
//           )?,
//         }
//       }
//       // a buyer may always remove their queue item at any time
//       QueueCancel ->
//         //
//         //
//         //
//         and {
//           // the owner must sign it
//           signing.verify_sig(extra_signatories, this_datum.owner.pkh)?,
//           // single script input
//           count.inputs_by_addr(inputs, this_addr, 1)?,
//         }
//     }
//   }
// }
