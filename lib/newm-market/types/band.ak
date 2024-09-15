use aiken/collection/dict
use aiken/collection/list
use aiken/primitive/bytearray
use cardano/assets.{AssetName, Value}
use types/token.{Tokens}

pub type BandLockUpRedeemer {
  RemoveBand
  AddToBand { members: Tokens }
  MintBand
  BurnBand(ByteArray)
}

/// Token names are from the value or total assets. Monster token names are the
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
    [] -> False
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

// this should be a good real world test
test destruct_value_into_two_lists() {
  let prefixes: List<ByteArray> =
    [
      #"4e45574d6f6e73746572444a", #"4e45574d6f6e73746572466c616d656e636f",
      #"4e45574d6f6e7374657248656176794d6574616c",
      #"4e45574d6f6e7374657248656c6c6f576f726c64",
      #"4e45574d6f6e73746572486970486f70", #"4e45574d6f6e737465724a617a7a",
      #"4e45574d6f6e737465724f70657261", #"4e45574d6f6e737465725069616e697374",
      #"4e45574d6f6e73746572526567676165", #"4e45574d6f6e73746572526f636b",
      #"4e45574d6f6e73746572436f6e647563746f72",
      #"4e45574d6f6e73746572436f756e747279", #"4e45574d6f6e73746572446973636f",
      #"4e45574d6f6e73746572446f75626c6542617373",
      #"4e45574d6f6e737465724472756d6d6572", #"4e45574d6f6e737465724b506f70",
      #"4e45574d6f6e7374657250657263757373696f6e",
      #"4e45574d6f6e7374657250756e6b", #"4e45574d6f6e7374657252616e6368657261",
      #"4e45574d6f6e73746572536f6e67777269746572",
      #"4e45574d6f6e7374657253776973734c616e646c6572",
    ]

  let this_value: Value =
    assets.from_asset_list(
      [
        Pair(
          #"7d878696b149b529807aa01b8e20785e0a0d470c32c13f53f08a55e3",
          [
            Pair(
              #"4e45574d6f6e73746572436f6e647563746f72ecafbeeffacecafeaabcbeeffa",
              1,
            ),
            Pair(
              #"4e45574d6f6e73746572444aaabcbeeffacecafeaabcbeeffacecafeaabcbeef",
              1,
            ),
            Pair(
              #"4e45574d6f6e73746572466c616d656e636fabacbeeffacecafeaabcbeefface",
              1,
            ),
            Pair(
              #"4e45574d6f6e7374657248656176794d6574616cabcabeeffacecafeaabcbeef",
              1,
            ),
            Pair(
              #"4e45574d6f6e7374657248656c6c6f576f726c64acabbeeffacecafeaabcbeef",
              1,
            ),
            Pair(
              #"4e45574d6f6e73746572486970486f70afecbeeffacecafeaabcbeeffaceacab",
              1,
            ),
            Pair(
              #"4e45574d6f6e737465724a617a7abacabeeffacecafeaabcbeeffaceacabface",
              1,
            ),
            Pair(
              #"4e45574d6f6e737465724f70657261bcaabeeffacecafeaabcbeeffaceacabfa",
              1,
            ),
            Pair(
              #"4e45574d6f6e737465725069616e697374caabbeeffacecafeaabcbeeffaceac",
              1,
            ),
            Pair(
              #"4e45574d6f6e73746572526567676165cababeeffacecafeaabcbeeffaceacab",
              1,
            ),
            Pair(
              #"4e45574d6f6e73746572526f636bcafebeeffacecafeaabcbeeffaceacabface",
              1,
            ),
          ],
        ),
        Pair(
          #"85510e059114a9dcdf7c1d842a1b8fdfd2438cd31ef1b3edcf6d5d67",
          [
            Pair(
              #"4e45574d6f6e73746572436f756e747279fecabeeffacecafeaabcbeeffaceab",
              1,
            ),
            Pair(
              #"4e45574d6f6e73746572446973636fadefacabbeeffaceadefacabbeeffacead",
              1,
            ),
            Pair(
              #"4e45574d6f6e73746572446f75626c6542617373adfeacabbeeffaceadefacab",
              1,
            ),
            Pair(
              #"4e45574d6f6e737465724472756d6d6572afcebeeffacecafeaabcbeeffaceab",
              1,
            ),
            Pair(
              #"4e45574d6f6e737465724b506f70ceafbeeffacecafeaabcbeeffaceacabface",
              1,
            ),
            Pair(
              #"4e45574d6f6e7374657250657263757373696f6edefaacabbeeffaceadefacab",
              1,
            ),
            Pair(
              #"4e45574d6f6e7374657250756e6beadfacabbeeffaceadefacabbeeffaceadef",
              1,
            ),
            Pair(
              #"4e45574d6f6e7374657252616e6368657261eafcbeeffacecafeaabcbeefface",
              1,
            ),
            Pair(
              #"4e45574d6f6e73746572536f6e67777269746572efadacabbeeffaceadefacab",
              1,
            ),
            Pair(
              #"4e45574d6f6e7374657253776973734c616e646c6572fadeacabbeeffaceadef",
              1,
            ),
          ],
        ),
      ],
    )
  let token_names1: List<AssetName> =
    this_value
      |> assets.tokens(#"7d878696b149b529807aa01b8e20785e0a0d470c32c13f53f08a55e3")
      |> dict.keys()
  let token_names2: List<AssetName> =
    this_value
      |> assets.tokens(#"85510e059114a9dcdf7c1d842a1b8fdfd2438cd31ef1b3edcf6d5d67")
      |> dict.keys()
  let token_names: List<AssetName> = list.concat(token_names1, token_names2)
  has_correct_tokens(token_names, prefixes)
}
