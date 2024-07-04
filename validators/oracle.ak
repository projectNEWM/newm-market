//// THIS IS A FAKE ORACLE TO MATCH C3 FOR TESTING PURPOSES ONLY

use aiken/transaction.{Input, ScriptContext, Spend, Transaction}
use aiken/transaction/credential.{Address}
use aiken/transaction/value.{AssetName, PolicyId}
use assist/data
use assist/find
use assist/types/hashes.{ValidatorHash}
use assist/values
use newm_market/types/oracle.{OracleDatum}

validator(feed_pid: PolicyId, feed_tkn: AssetName, feed_hash: ValidatorHash) {
  fn params(
    _datum: OracleDatum,
    _redeemer: Void,
    context: ScriptContext,
  ) -> Bool {
    expect Spend(output_reference) = context.purpose
    let Transaction { inputs, outputs, reference_inputs, .. } =
      context.transaction
    let this_input: Input = find.input_by_ref(inputs, output_reference)
    let this_addr: Address = this_input.output.address
    let feed_addr: Address = credential.from_script(feed_hash)
    let feed_input: Input = find.input_by_addr(reference_inputs, feed_addr)
    // expect _: OracleDatum = data.input_datum(feed_input)
    // expect _: OracleDatum = find.output_datum_by_addr(outputs, this_addr)
    values.prove_exact_nft(feed_input.output.value, feed_pid, feed_tkn)?
  }
}
