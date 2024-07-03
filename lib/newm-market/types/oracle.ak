use aiken/builtin

pub type DataMap =
  Pairs<Int, Data>

pub type PriceData {
  SharedData(DataMap)
  ExtendedData(DataMap)
  GenericData(DataMap)
}

pub type OracleDatum {
  price_data: PriceData,
}

pub fn find_value(data: DataMap, key: Int) -> Data {
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
