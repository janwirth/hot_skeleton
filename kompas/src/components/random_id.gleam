import gleam/string
import gleam/int

const charset = "abcdefghijklmnopqrstuvwxyz0123456789"

fn char_at(s: String, i: Int) -> String {
  string.slice(s, i, i + 1)
}

pub fn random_id_5() -> String {
  build("", 5)
}
fn build(acc: String, n: Int) {
  let len = string.length(charset)
    case n {
      0 -> acc
      _ -> {
        // int.random(len) returns 0..len-1
        let r = int.random(len)
        let c = char_at(charset, r)
        build(acc <> c, n - 1)
      }
    }
}
