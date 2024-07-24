use aiken/builtin
use assist/types/moment.{Moment}

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

pub fn get_moment(datum: OracleDatum) -> Moment {
  when datum.price_data is {
    GenericData { price_map } -> {
      expect start: Int = find_value(price_map, 1)
      expect end: Int = find_value(price_map, 2)
      let m: Moment = Moment { start, end }
      if moment.is_logical(m) {
        m
      } else {
        fail @"Illogical Moment Data"
      }
    }
    _ -> fail @"Price Data Not Generic Data"
  }
}

pub fn get_price(datum: OracleDatum) -> Int {
  when datum.price_data is {
    GenericData { price_map } -> {
      expect price: Int = find_value(price_map, 0)
      price
    }
    _ -> fail @"Price Data Not Generic Data"
  }
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

test get_oracle_price() {
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
  let price: Int = get_price(datum)
  price == 2723
}

test get_oracle_moment() {
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
  let time_window: Moment = get_moment(datum)
  and {
    time_window.start == 1720056807332,
    time_window.end == 1720078407332,
  }
}
