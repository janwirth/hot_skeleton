import gleeunit
import tailwind_wrapper

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn default_config_output_is_priv_test() {
  let c = tailwind_wrapper.default_config()
  assert c.output_css == "priv/tailwind.css"
}
