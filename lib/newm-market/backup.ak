use aiken/crypto.{ScriptHash, VerificationKeyHash}
use cardano/address.{Address}
use cardano/datum
use cardano/transaction.{Input}
use cardano/tx
use newm_market/types/reference.{ReferenceDatum}
use validation/find

/// This is our backup validation for no datum or bad datum structure UTxOs. If
/// a UTxO comes into any of our spend contracts then the default logic is a
/// signing verification via the hot key.
///
/// ```aiken
/// backup.logic(ref_hash, reference_inputs, extra_signatories)
/// ```
pub fn logic(
  ref_hash: ScriptHash,
  reference_inputs: List<Input>,
  extra_signatories: List<VerificationKeyHash>,
) -> Bool {
  let ref_data_addr: Address = address.from_script(ref_hash)
  let ref_data_input: Input =
    find.input_by_addr(reference_inputs, ref_data_addr)
  expect ref_data_datum: ReferenceDatum = datum.input_datum(ref_data_input)
  // hot key must sign
  tx.verify_signature(extra_signatories, ref_data_datum.hot_key)?
}
