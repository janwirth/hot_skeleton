export function register() {
  if (
    typeof HTMLElement === "undefined" ||
    typeof customElements === "undefined"
  ) {
    return;
  }

  if (customElements.get("scroll-view-anchor")) {
    return;
  }

  class ScrollViewAnchor extends HTMLElement {
    #parentResizeObserver = null;
    #rowResizeObserver = null;
    #parentMutationObserver = null;
    #observedRow = null;
    #pollTimer = null;

    #findMeasuredRow() {
      const parent = this.parentElement;
      if (!parent) return null;
      const children = parent.children ?? [];
      for (let i = 0; i < children.length; i += 1) {
        const child = children[i];
        if (child === this) continue;
        if (child.offsetHeight > 0) return child;
      }
      return null;
    }

    #emitMeasurement() {
      const parent = this.parentElement;
      if (!parent) return;
      const rect = parent.getBoundingClientRect();
      const row = this.#findMeasuredRow();
      const rowHeight = row?.offsetHeight ?? 0;
      this.dispatchEvent(
        new CustomEvent("anchormeasured", {
          bubbles: true,
          detail: {
            containerHeight: rect.height,
            rowHeight,
          },
        }),
      );
    }

    #observeRowSibling() {
      const row = this.#findMeasuredRow();
      if (row === this.#observedRow) return;

      if (this.#rowResizeObserver) {
        this.#rowResizeObserver.disconnect();
      }
      this.#rowResizeObserver = null;
      this.#observedRow = row;

      if (!row) return;

      this.#rowResizeObserver = new ResizeObserver(() => {
        this.#emitMeasurement();
      });
      this.#rowResizeObserver.observe(row);
    }

    connectedCallback() {
      const parent = this.parentElement;
      if (!parent) return;

      this.#parentResizeObserver = new ResizeObserver(() => {
        this.#emitMeasurement();
      });
      this.#parentResizeObserver.observe(parent);

      this.#parentMutationObserver = new MutationObserver(() => {
        this.#observeRowSibling();
        this.#emitMeasurement();
      });
      this.#parentMutationObserver.observe(parent, {
        childList: true,
        subtree: false,
      });

      this.#observeRowSibling();
      this.#emitMeasurement();

      this.#pollTimer = setInterval(() => {
        this.#observeRowSibling();
        this.#emitMeasurement();
        if (this.#observedRow && this.#observedRow.offsetHeight > 0) {
          clearInterval(this.#pollTimer);
          this.#pollTimer = null;
        }
      }, 150);
    }

    disconnectedCallback() {
      this.#parentResizeObserver?.disconnect();
      this.#parentResizeObserver = null;
      this.#rowResizeObserver?.disconnect();
      this.#rowResizeObserver = null;
      this.#parentMutationObserver?.disconnect();
      this.#parentMutationObserver = null;
      this.#observedRow = null;
      if (this.#pollTimer) {
        clearInterval(this.#pollTimer);
        this.#pollTimer = null;
      }
    }
  }

  customElements.define("scroll-view-anchor", ScrollViewAnchor);
}
