import gleeunit
import gleeunit/should

pub fn main() {
  let apa: String = "123"
  gleeunit.main()
}

// gleeunit test functions end in `_test`
pub fn hello_world_test() {
  1
  |> should.equal(1)
}
