export function register() {
  if (
    typeof HTMLElement === "undefined" ||
    typeof customElements === "undefined"
  ) {
    return;
  }

  if (customElements.get("parent-resize-observer")) {
    return;
  }

  class ParentResizeObserver extends HTMLElement {
    #observer = null;
    #parent = null;
    #pollInterval = null;

    #measureRowHeight() {
      const slot = this.querySelector("slot");
      const assigned = slot?.assignedElements?.({ flatten: true }) ?? [];
      const rowEl = assigned[0];
      if (rowEl && rowEl.offsetHeight > 0) {
        return rowEl.offsetHeight;
      }
      const firstChild = this.firstElementChild;
      return firstChild?.offsetHeight ?? null;
    }

    #emitParentResized() {
      this.dispatchEvent(new CustomEvent("parentresized", { bubbles: true }));
    }

    connectedCallback() {
      this.#parent = this.parentElement;
      if (!this.#parent) return;
      this.#observer = new ResizeObserver(() => {
        this.#emitParentResized();
      });
      this.#observer.observe(this.#parent);
      this.#emitParentResized();

      // Row height may be unavailable on first paint; poll until it appears.
      this.#pollInterval = setInterval(() => {
        const rowHeight = this.#measureRowHeight();
        this.#emitParentResized();
        if (typeof rowHeight === "number" && rowHeight > 0) {
          clearInterval(this.#pollInterval);
          this.#pollInterval = null;
        }
      }, 150);
    }

    disconnectedCallback() {
      this.#observer?.disconnect();
      this.#observer = null;
      this.#parent = null;
      if (this.#pollInterval) {
        clearInterval(this.#pollInterval);
        this.#pollInterval = null;
      }
    }
  }

  customElements.define("parent-resize-observer", ParentResizeObserver);
}

export function getBoundingClientRect(event) {
  const target = event?.target;
  const el = target?.parentElement;
  if (!el) return null;
  const r = el.getBoundingClientRect();
  const slot = target?.querySelector?.("slot");
  const assigned = slot?.assignedElements?.({ flatten: true }) ?? [];
  const rowEl = assigned[0];
  const rowHeight = rowEl?.offsetHeight ?? target?.firstElementChild?.offsetHeight ?? null;
  return { width: r.width, height: r.height, x: r.left, y: r.top, rowHeight };
}
