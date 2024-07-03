//// THIS IS A FAKE ORACLE TO MATCH C3 FOR TESTING PURPOSES ONLY

use aiken/transaction.{Input, ScriptContext, Spend, Transaction}
use aiken/transaction/credential.{Address}
use assist/find
use newm_market/types/oracle.{OracleDatum}

validator {
  fn params(
    _datum: OracleDatum,
    _redeemer: Void,
    context: ScriptContext,
  ) -> Bool {
    expect Spend(output_reference) = context.purpose
    let Transaction { inputs, outputs, .. } = context.transaction
    let this_input: Input = find.input_by_ref(inputs, output_reference)
    let this_addr: Address = this_input.output.address
    expect _: OracleDatum = find.output_datum_by_addr(outputs, this_addr)
    True
  }
}
