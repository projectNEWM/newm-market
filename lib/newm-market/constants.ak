use aiken/bytearray

// batcher token
pub const batcher_token_name: ByteArray = #"affab1e0005e77ab1e"

// complete set token
pub const complete_set_token_name: ByteArray = #"c011ec7ed000a55e75"

// this will save us from doing the length check
pub const batcher_token_name_length: Int = 9

// Lovelace is just a wrapper around int
pub type Lovelace =
  Int

// 10 ADA is the default vault minimum
pub const vault_minimum_lovelace: Lovelace = 10_000_000

test is_batcher_length_correct() {
  and {
    bytearray.length(batcher_token_name) == bytearray.length(
      complete_set_token_name,
    ),
    bytearray.length(batcher_token_name) == batcher_token_name_length,
  }
}

test slice_batcher_token_name() {
  let tkn: ByteArray =
    #"affab1e0005e77ab1e0012906f64081c027cb43ef117fcfa89c5da8b90168006"
  let str: ByteArray = #"0012906f64081c027cb43ef117fcfa89c5da8b90168006"
  bytearray.slice(tkn, batcher_token_name_length, 32) == str
}

test take_batcher_token_name() {
  let tkn: ByteArray =
    #"affab1e0005e77ab1e0012906f64081c027cb43ef117fcfa89c5da8b90168006"
  bytearray.take(tkn, batcher_token_name_length) == batcher_token_name
}
