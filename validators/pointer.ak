use aiken/crypto.{ScriptHash}
use cardano/address.{Address}
use cardano/assets.{AssetName, PolicyId}
use cardano/datum
use cardano/minting
use cardano/transaction.{Input, Transaction, TransactionId}
use cardano/tx
use cardano/value
use newm_market/types/pointer.{
  BurnPointerToken, MintPointerRedeemer, MintPointerToken,
}
use newm_market/types/reference.{ReferenceDatum}
use types/prefixes
use validation/find

validator contract(
  starter_pid: PolicyId,
  starter_tkn: AssetName,
  ref_hash: ScriptHash,
) {
  mint(
    redeemer: MintPointerRedeemer,
    currency_symbol: PolicyId,
    transaction: Transaction,
  ) {
    // the transaction being validated
    let Transaction { inputs, reference_inputs, extra_signatories, mint, .. } =
      transaction
    let mint_list: List<(PolicyId, AssetName, Int)> =
      mint
        |> assets.flatten()
    when redeemer is {
      // this can not have destination validation due to lexico cbor
      MintPointerToken -> {
        // data reference stuff
        let ref_addr: Address = address.from_script(ref_hash)
        let ref_input: Input = find.input_by_addr(reference_inputs, ref_addr)
        // Get the reference datum
        expect ref_datum: ReferenceDatum = datum.input_datum(ref_input)
        // get first utxo info
        let first_index: Int = find.first_input_index(inputs)
        let first_tx_hash: TransactionId = find.first_input_txid(inputs)
        // use the pointer prefix
        let pointer_tkn: AssetName =
          value.unique_token_name(first_tx_hash, first_index, prefixes.callable)
        and {
          // hot key must sign
          tx.verify_signature(extra_signatories, ref_datum.hot_key)?,
          // prevent roll over double nft attack
          (first_index < 256)?,
          // must mint 1 pointer token
          minting.exact(mint_list, currency_symbol, pointer_tkn, 1)?,
          // data reference must be holding correct token
          value.prove_exact_nft(
            ref_input.output.value,
            starter_pid,
            starter_tkn,
          )?,
        }
      }
      // burn a single pointer token
      BurnPointerToken ->
        minting.by_prefix(
          mint_list,
          currency_symbol,
          // non standard prefix
          prefixes.callable,
          -1,
        )?
    }
  }

  else(_) {
    fail
  }
}
