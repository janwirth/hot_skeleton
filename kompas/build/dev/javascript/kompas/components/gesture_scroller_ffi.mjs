let isThemeSyncInitialized = false;
let themeObserver = null;
let elementObserver = null;

function applyThemeClassToGestureScrollers() {
  if (typeof document === "undefined") return;
  const storedTheme = localStorage.theme;
  const isDark =
    storedTheme === "dark" ||
    (!("theme" in localStorage) &&
      window.matchMedia("(prefers-color-scheme: dark)").matches);
  for (const el of document.querySelectorAll("gesture-scroller")) {
    el.classList.toggle("dark", isDark);
  }
}

export function ensureThemeClassSync() {
  if (typeof window === "undefined" || typeof document === "undefined") return;
  if (isThemeSyncInitialized) {
    applyThemeClassToGestureScrollers();
    return;
  }

  isThemeSyncInitialized = true;
  applyThemeClassToGestureScrollers();

  themeObserver = new MutationObserver(() => {
    applyThemeClassToGestureScrollers();
  });
  themeObserver.observe(document.documentElement, {
    attributes: true,
    attributeFilter: ["class"],
  });

  const observeElementChanges = () => {
    if (!document.body) return;
    elementObserver = new MutationObserver(() => {
      applyThemeClassToGestureScrollers();
    });
    elementObserver.observe(document.body, {
      subtree: true,
      childList: true,
      attributes: true,
      attributeFilter: ["class"],
    });
  };

  if (document.body) {
    observeElementChanges();
  } else {
    window.addEventListener("DOMContentLoaded", observeElementChanges, {
      once: true,
    });
  }

  window.addEventListener("storage", applyThemeClassToGestureScrollers);
}
