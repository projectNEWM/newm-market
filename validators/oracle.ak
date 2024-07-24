//// THIS IS A FAKE ORACLE TO MATCH C3 FOR TESTING PURPOSES ONLY

use aiken/transaction.{Input, ScriptContext, Spend, Transaction}
use aiken/transaction/credential.{Address}
use aiken/transaction/value.{AssetName, PolicyId}
use assist/data
use assist/find
use assist/types/hashes.{ValidatorHash}
use assist/values

pub type PriceMap =
  Pairs<Int, Data>

pub type PriceData {
  SharedData
  ExtendedData
  GenericData { price_map: PriceMap }
}

pub type OracleDatum {
  price_data: PriceData,
}

validator(feed_pid: PolicyId, feed_tkn: AssetName, feed_hash: ValidatorHash) {
  fn params(_datum: Void, _redeemer: Void, context: ScriptContext) -> Bool {
    expect Spend(_) = context.purpose
    let Transaction { reference_inputs, .. } = context.transaction
    // non staked address
    let feed_addr: Address = credential.from_script(feed_hash)
    // this fails with @"No Input Found By Address"
    let feed_input: Input = find.input_by_addr(reference_inputs, feed_addr)
    // this silent fail for bad destruturing
    expect _: OracleDatum = data.input_datum(feed_input)
    // the real oracle feed holds the feed token
    values.prove_exact_nft(feed_input.output.value, feed_pid, feed_tkn)?
  }
}
