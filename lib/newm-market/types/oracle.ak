use aiken/builtin
use aiken/cbor

pub type PriceMap =
  Pairs<Int, Data>

pub type PriceData {
  SharedData
  ExtendedData
  GenericData(PriceMap)
}

pub type OracleDatum {
  price_data: PriceData,
}

pub fn find_value(data: PriceMap, key: Int) -> Data {
  when data is {
    [] -> fail @"Value Not Found"
    [d, ..ds] ->
      if builtin.fst_pair(d) == key {
        builtin.snd_pair(d)
      } else {
        find_value(ds, key)
      }
  }
}

test oracle_datum_diagnostic() {
  let datum: OracleDatum =
    OracleDatum {
      price_data: GenericData(
        [
          Pair(0, builtin.i_data(2723)),
          Pair(1, builtin.i_data(1720056807332)),
          Pair(2, builtin.i_data(1720078407332)),
        ],
      ),
    }
  cbor.diagnostic(datum) == @""
}

test oracle_datum_serialise() {
  let datum: OracleDatum =
    OracleDatum {
      price_data: GenericData(
        [
          Pair(0, builtin.i_data(2723)),
          Pair(1, builtin.i_data(1720056807332)),
          Pair(2, builtin.i_data(1720078407332)),
        ],
      ),
    }
  cbor.serialise(datum) == #""
}
