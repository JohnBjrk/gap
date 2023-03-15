pub external type MutableMap(key, value)

pub external fn new() -> MutableMap(k, v) =
  "../gap_ffi.mjs" "new_mutable_map"

pub fn insert(map: MutableMap(k, v), key: k, value: v) -> MutableMap(k, v) {
  do_insert(key, value, map)
}

external fn do_insert(
  key: k,
  value: v,
  map: MutableMap(k, v),
) -> MutableMap(k, v) =
  "../gap_ffi.mjs" "mutable_map_insert"

pub external fn get(map: MutableMap(k, v), key: k) -> Result(v, Nil) =
  "../gap_ffi.mjs" "mutable_map_get"

pub external fn keys(map: MutableMap(k, v)) -> List(k) =
  "../gap_ffi.mjs" "keys"

pub external fn from_list(list: List(t)) -> MutableMap(k, v) =
  "../gap_ffi.mjs" "from_list"
