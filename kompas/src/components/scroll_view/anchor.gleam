import lustre/attribute.{class, type Attribute}
import lustre/element.{element, type Element}

@external(javascript, "./anchor_ffi.mjs", "register")
fn register_anchor_element() -> Nil

pub fn register() {
  register_anchor_element()
}

pub fn view(attrs: List(Attribute(msg))) -> Element(msg) {
  element(
    "scroll-view-anchor",
    [
      class("block h-0 min-h-0 m-0 p-0 overflow-hidden opacity-0 pointer-events-none"),
      ..attrs,
    ],
    [],
  )
}
