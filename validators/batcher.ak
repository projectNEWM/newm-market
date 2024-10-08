use aiken/crypto.{ScriptHash}
use cardano/address.{Address}
use cardano/addresses
use cardano/assets.{PolicyId}
use cardano/datum
use cardano/transaction.{Input, OutputReference, Transaction}
use newm_market/types/band.{BandLockUpRedeemer, BurnBand, MintBand}
use newm_market/types/batcher.{
  BatcherTokenRedeemer, BurnBatcherToken, MintBatcherToken,
}
use newm_market/types/reference.{ReferenceDatum}
use validation/find

validator contract(ref_hash: ScriptHash) {
  mint(
    redeemer: BatcherTokenRedeemer,
    _currency_symbol: PolicyId,
    transaction: Transaction,
  ) {
    // the transaction being validated
    let Transaction { inputs, reference_inputs, redeemers, .. } = transaction
    // data reference stuff
    let ref_addr: Address = address.from_script(ref_hash)
    let ref_input: Input = find.input_by_addr(reference_inputs, ref_addr)
    // Get the reference datum
    expect ref_datum: ReferenceDatum = datum.input_datum(ref_input)
    // create the band lock address
    let band_addr: Address =
      addresses.create_script_address(
        ref_datum.contracts.band,
        ref_datum.contracts.stake,
      )
    // find the first band input
    let band_input: Input = find.input_by_addr(inputs, band_addr)
    // get the reference
    let band_out_ref: OutputReference = band_input.output_reference
    when redeemer is {
      // must spend 1 thing from the band contract and use the mint band redeemer
      MintBatcherToken -> {
        expect that_redeemer: BandLockUpRedeemer =
          find.redeemer_by_ref(redeemers, band_out_ref)
        expect MintBand = that_redeemer
        True
      }
      // must spend 1 thing from the band contract and use the burn band redeemer
      BurnBatcherToken -> {
        expect that_redeemer: BandLockUpRedeemer =
          find.redeemer_by_ref(redeemers, band_out_ref)
        expect BurnBand(_) = that_redeemer
        True
      }
    }
  }

  else(_) {
    fail
  }
}
