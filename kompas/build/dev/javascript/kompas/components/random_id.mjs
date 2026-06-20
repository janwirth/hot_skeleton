import * as $int from "../../gleam_stdlib/gleam/int.mjs";
import * as $string from "../../gleam_stdlib/gleam/string.mjs";

const charset = "abcdefghijklmnopqrstuvwxyz0123456789";

function char_at(s, i) {
  return $string.slice(s, i, i + 1);
}

function build(loop$acc, loop$n) {
  while (true) {
    let acc = loop$acc;
    let n = loop$n;
    let len = $string.length(charset);
    if (n === 0) {
      return acc;
    } else {
      let r = $int.random(len);
      let c = char_at(charset, r);
      loop$acc = acc + c;
      loop$n = n - 1;
    }
  }
}

export function random_id_5() {
  return build("", 5);
}
