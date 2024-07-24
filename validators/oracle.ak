//// THIS IS A FAKE ORACLE TO MATCH C3 FOR TESTING PURPOSES ONLY

use aiken/transaction.{Input, ScriptContext, Spend, Transaction}
use aiken/transaction/credential.{Address}
use aiken/transaction/value.{AssetName, PolicyId}
use assist/data
use assist/find
use assist/types/hashes.{ValidatorHash}
use assist/types/moment.{Moment}
use assist/values
use newm_market/types/oracle.{OracleDatum}

validator(feed_pid: PolicyId, feed_tkn: AssetName, feed_hash: ValidatorHash) {
  fn params(_datum: Void, _redeemer: Void, context: ScriptContext) -> Bool {
    expect Spend(_) = context.purpose
    let Transaction { reference_inputs, validity_range, .. } =
      context.transaction
    // non staked address
    let feed_addr: Address = credential.from_script(feed_hash)
    // this fails with @"No Input Found By Address"
    let feed_input: Input = find.input_by_addr(reference_inputs, feed_addr)
    // this silent fail for bad destruturing
    expect feed_datum: OracleDatum = data.input_datum(feed_input)
    // get the current price
    let feed_price: Int = oracle.get_price(feed_datum)
    // the moment of the oracle
    let feed_moment: Moment = oracle.get_moment(feed_datum)
    //
    // Prove that the oracle holds the feed token, that the price is positive,
    // and that the moment of time that the oracle is valid is contained within
    // the validity range of the transaction.
    //
    and {
      // the real oracle feed holds the feed token
      values.prove_exact_nft(feed_input.output.value, feed_pid, feed_tkn)?,
      // price is positive
      (feed_price > 0)?,
      // is the valdiity range of the tx contained in the oracle moment
      moment.is_contained(feed_moment, validity_range)?,
    }
  }
}
