export function arraySize(arr) {
  return arr.length;
}

export function arraySlice(arr, from, to) {
  return arr.slice(from, to);
}

export function getBoundingClientRect(event) {
  const r = event.target.getBoundingClientRect();
  return { top: r.top, height: r.height };
}

export function getBoundingClientRectCurrentTarget(event) {
  const el = event.currentTarget;
  if (!el) return null;
  const r = el.getBoundingClientRect();
  return { top: r.top, height: r.height };
}

export function getBoundingClientRectById(id) {
  const el = document.getElementById(id);
  if (!el) return null;
  const r = el.getBoundingClientRect();
  return { top: r.top, height: r.height };
}

export function performanceNow() {
  return performance.now();
}

export function measureScrollView(root, containerId, rowClass) {
  const container = root?.querySelector?.("#" + containerId) ?? document.getElementById(containerId);
  if (!container) return null;
  const r = container.getBoundingClientRect();
  const firstRow = container.querySelector?.(`.${rowClass}`) ?? container.firstElementChild;
  const rowHeight = firstRow?.offsetHeight ?? 0;
  return { containerHeight: r.height, rowHeight };
}

export function addPointerUpListener(callback) {
  const handler = () => {
    document.removeEventListener("pointerup", handler);
    callback();
  };
  document.addEventListener("pointerup", handler);
}
