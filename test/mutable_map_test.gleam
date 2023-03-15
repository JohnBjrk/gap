if javascript {
  import gleeunit/should
  import gleam/io
  import util/mutable_map

  pub fn new_mutable_map_test() {
    let mm = mutable_map.new()
    io.debug(mm)
  }

  pub fn insert_mutable_map_test() {
    let mm = mutable_map.new()
    mm
    |> mutable_map.insert("apa", "bepa")
    io.debug(mm)
  }

  pub fn get_mutable_map_test() {
    let mm = mutable_map.new()
    mm
    |> mutable_map.insert("apa", "bepa")
    |> mutable_map.get("apa")
    |> should.be_ok()
    |> should.equal("bepa")
  }

  pub fn keys_mutable_map_test() {
    let mm = mutable_map.new()
    mm
    |> mutable_map.insert("apa", "bepa")
    |> mutable_map.keys()
    |> should.equal(["apa"])
  }

  pub fn from_list_mutable_map_test() {
    mutable_map.from_list([#("apa", "bepa")])
    |> mutable_map.get("apa")
    |> should.be_ok()
    |> should.equal("bepa")
  }
}
