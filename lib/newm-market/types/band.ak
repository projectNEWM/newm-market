use aiken/bytearray
use aiken/cbor
use aiken/dict
use aiken/list
use aiken/transaction/value.{AssetName, Value}
use assist/types/token.{Tokens}

pub type BandLockUpRedeemer {
  RemoveBand
  AddToBand { members: Tokens }
  MintBand
  BurnBand(ByteArray)
}

/// Token names are from the value or total value. Monster token names are the
/// official prefixes for the monster nfts.
///
pub fn has_correct_tokens(
  tkns_from_value: List<AssetName>,
  tkn_prefixes: List<ByteArray>,
) -> Bool {
  when tkn_prefixes is {
    // found all of them in the value
    [] -> True
    // go through all the prefixes from the set
    [prefix, ..prefixes] ->
      if do_has_correct_tokens(tkns_from_value, prefix) {
        // found something so go to the next one
        has_correct_tokens(tkns_from_value, prefixes)
      } else {
        // missing something from the set
        trace cbor.diagnostic(prefix)
        False
      }
  }
}

fn do_has_correct_tokens(
  tkns_from_value: List<AssetName>,
  prefix: ByteArray,
) -> Bool {
  when tkns_from_value is {
    // something wasn't found
    [] -> {
      trace cbor.diagnostic(tkns_from_value)
      False
    }
    [tkn, ..tkns] ->
      if prefix_in_token_name(prefix, tkn) {
        // found it
        True
      } else {
        // keep searching
        do_has_correct_tokens(tkns, prefix)
      }
  }
}

/// Check if some known prefix exists within some token name.
fn prefix_in_token_name(prefix: ByteArray, token_name: AssetName) -> Bool {
  // the length of the prefix counting from 0
  let length_of_prefix = bytearray.length(prefix) - 1
  // does teh prefix exist in the token name
  bytearray.slice(token_name, start: 0, end: length_of_prefix) == prefix
}

test prefix_does_exists_in_token_name() {
  let tkn: ByteArray = #"acabbeeffacecafe"
  let pfx: ByteArray = #"acab"
  prefix_in_token_name(pfx, tkn)
}

test prefix_doesnt_exists_in_token_name() fail {
  let tkn: ByteArray = #"acabbeeffacecafe"
  let pfx: ByteArray = #"fade"
  prefix_in_token_name(pfx, tkn)
}

test empty_token_names_empty_prefixes() {
  let prefixes: List<ByteArray> =
    []
  let token_names: List<ByteArray> =
    []
  has_correct_tokens(token_names, prefixes)
}

test empty_token_names_single_prefixes() fail {
  let prefixes: List<ByteArray> =
    [#"acab"]
  let token_names: List<ByteArray> =
    []
  has_correct_tokens(token_names, prefixes)
}

test eight_token_names_have_eight_prefixes() {
  let prefixes: List<ByteArray> =
    [#"acab", #"baca", #"abac", #"caba", #"caab", #"bcaa", #"abca", #"aabc"]
  let token_names: List<ByteArray> =
    [
      #"acabbeeffacecafe", #"bacabeeffacecafe", #"abacbeeffacecafe",
      #"cababeeffacecafe", #"caabbeeffacecafe", #"bcaabeeffacecafe",
      #"abcabeeffacecafe", #"aabcbeeffacecafe",
    ]
  has_correct_tokens(token_names, prefixes)
}

test sixteen_token_names_sixteen_have_prefixes() {
  let prefixes: List<ByteArray> =
    [
      #"acab", #"baca", #"abac", #"caba", #"caab", #"bcaa", #"abca", #"aabc",
      #"fade", #"efad", #"defa", #"adef", #"adfe", #"eadf", #"fead", #"dfea",
    ]
  let token_names: List<ByteArray> =
    [
      #"acabbeeffacecafe", #"bacabeeffacecafe", #"abacbeeffacecafe",
      #"cababeeffacecafe", #"caabbeeffacecafe", #"bcaabeeffacecafe",
      #"abcabeeffacecafe", #"aabcbeeffacecafe", #"fadeacabbeefface",
      #"efadacabbeefface", #"defaacabbeefface", #"adefacabbeefface",
      #"adfeacabbeefface", #"eadfacabbeefface", #"feadacabbeefface",
      #"dfeaacabbeefface",
    ]
  has_correct_tokens(token_names, prefixes)
}

test destruct_value_into_two_lists() {
  let prefixes: List<ByteArray> =
    [
      #"acab", #"baca", #"abac", #"caba", #"caab", #"bcaa", #"abca", #"aabc",
      #"fade", #"efad", #"defa", #"adef", #"adfe", #"eadf", #"fead", #"dfea",
      #"cafe", #"ecaf", #"feca", #"afec", #"afce", #"eafc", #"ceaf", #"fcea",
    ]
  let this_value: Value =
    value.from_asset_list(
      [
        Pair(#"7d878696b149b529807aa01b8e20785e0a0d470c32c13f53f08a55e3",
        [
          Pair(#"aabcbeeffacecafeaabcbeeffacecafeaabcbeeffacecafeaabcbeeffacecafe",
          1),
          Pair(#"abacbeeffacecafeaabcbeeffacecafeaabcbeeffacecafeaabcbeeffacecafe",
          1),
          Pair(#"abcabeeffacecafeaabcbeeffacecafeaabcbeeffacecafeaabcbeeffacecafe",
          1),
          Pair(#"acabbeeffacecafeaabcbeeffacecafeaabcbeeffacecafeaabcbeeffacecafe",
          1),
          Pair(#"afecbeeffacecafeaabcbeeffacecafeaabcbeeffacecafeaabcbeeffacecafe",
          1),
          Pair(#"bacabeeffacecafeaabcbeeffacecafeaabcbeeffacecafeaabcbeeffacecafe",
          1),
          Pair(#"bcaabeeffacecafeaabcbeeffacecafeaabcbeeffacecafeaabcbeeffacecafe",
          1),
          Pair(#"caabbeeffacecafeaabcbeeffacecafeaabcbeeffacecafeaabcbeeffacecafe",
          1),
          Pair(#"cababeeffacecafeaabcbeeffacecafeaabcbeeffacecafeaabcbeeffacecafe",
          1),
          Pair(#"cafebeeffacecafeaabcbeeffacecafeaabcbeeffacecafeaabcbeeffacecafe",
          1),
          Pair(#"ecafbeeffacecafeaabcbeeffacecafeaabcbeeffacecafeaabcbeeffacecafe",
          1),
          Pair(#"fecabeeffacecafeaabcbeeffacecafeaabcbeeffacecafeaabcbeeffacecafe",
          1),
        ]),
        Pair(#"85510e059114a9dcdf7c1d842a1b8fdfd2438cd31ef1b3edcf6d5d67",
        [
          Pair(#"adefacabbeeffaceadefacabbeeffaceadefacabbeeffaceadefacabbeefface",
          1),
          Pair(#"adfeacabbeeffaceadefacabbeeffaceadefacabbeeffaceadefacabbeefface",
          1),
          Pair(#"afcebeeffacecafeaabcbeeffacecafeaabcbeeffacecafeaabcbeeffacecafe",
          1),
          Pair(#"ceafbeeffacecafeaabcbeeffacecafeaabcbeeffacecafeaabcbeeffacecafe",
          1),
          Pair(#"defaacabbeeffaceadefacabbeeffaceadefacabbeeffaceadefacabbeefface",
          1),
          Pair(#"dfeaacabbeeffaceadefacabbeeffaceadefacabbeeffaceadefacabbeefface",
          1),
          Pair(#"eadfacabbeeffaceadefacabbeeffaceadefacabbeeffaceadefacabbeefface",
          1),
          Pair(#"eafcbeeffacecafeaabcbeeffacecafeaabcbeeffacecafeaabcbeeffacecafe",
          1),
          Pair(#"efadacabbeeffaceadefacabbeeffaceadefacabbeeffaceadefacabbeefface",
          1),
          Pair(#"fadeacabbeeffaceadefacabbeeffaceadefacabbeeffaceadefacabbeefface",
          1),
          Pair(#"fceabeeffacecafeaabcbeeffacecafeaabcbeeffacecafeaabcbeeffacecafe",
          1),
          Pair(#"feadacabbeeffaceadefacabbeeffaceadefacabbeeffaceadefacabbeefface",
          1),
        ]),
      ],
    )
  let token_names1: List<AssetName> =
    this_value
      |> value.tokens(#"7d878696b149b529807aa01b8e20785e0a0d470c32c13f53f08a55e3")
      |> dict.keys()
  let token_names2: List<AssetName> =
    this_value
      |> value.tokens(#"85510e059114a9dcdf7c1d842a1b8fdfd2438cd31ef1b3edcf6d5d67")
      |> dict.keys()
  let token_names: List<AssetName> = list.concat(token_names1, token_names2)
  has_correct_tokens(token_names, prefixes)
}
