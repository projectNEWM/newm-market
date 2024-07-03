use aiken/builtin

pub type PriceMap =
  Pairs<Int, Int>

pub type PriceData {
  SharedData
  ExtendedData
  GenericData(PriceMap)
}

pub type OracleDatum {
  price_data: PriceData,
}

pub fn find_value(data: PriceMap, key: Int) -> Int {
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
