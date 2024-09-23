use aiken/crypto.{VerificationKeyHash}
use cardano/address.{Address}
use cardano/assets.{AssetName, PolicyId}
use cardano/datum
use cardano/transaction.{Input}
use cardano/tx
use cardano/value
use newm_market/types/reference.{ReferenceDatum}
use validation/find

/// This is our backup validation for no datum or bad datum structure UTxOs. If
/// a UTxO comes into any of our spend contracts then the default logic is a
/// signing verification via the hot key.
///
/// ```aiken
/// backup.logic(ref_hash, reference_inputs, extra_signatories, starter_pid, starter_tkn)
/// ```
pub fn logic(
  ref_data_addr: Address,
  reference_inputs: List<Input>,
  extra_signatories: List<VerificationKeyHash>,
  starter_pid: PolicyId,
  starter_tkn: AssetName,
) -> Bool {
  let ref_data_input: Input =
    find.input_by_addr(reference_inputs, ref_data_addr)
  expect ref_data_datum: ReferenceDatum = datum.input_datum(ref_data_input)
  // hot key must sign
  and {
    value.prove_exact_nft(ref_data_input.output.value, starter_pid, starter_tkn)?,
    tx.verify_signature(extra_signatories, ref_data_datum.hot_key)?,
  }
}
