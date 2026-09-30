// Entry point for the animated shard ring
import ShardRing from "./renderer";

const MOUNTED = new WeakMap();

function supportsWebGL() {
  try {
    const canvas = document.createElement("canvas");
    return !!(window.WebGLRenderingContext && (canvas.getContext("webgl2") || canvas.getContext("webgl")));
  } catch (error) {
    return false;
  }
}

function prefersReducedMotion() {
  return window.matchMedia("(prefers-reduced-motion: reduce)").matches;
}

function showFallback(root) {
  const fallback = root.querySelector("[data-qul-shards-fallback]");
  const canvas = root.querySelector("canvas");
  if (fallback) fallback.classList.remove("hidden");
  if (canvas) canvas.classList.add("hidden");
}

function mount(root) {
  if (MOUNTED.has(root)) return;

  const canvas = root.querySelector("canvas");
  if (!canvas) return;

  if (!supportsWebGL()) {
    showFallback(root);
    return;
  }

  // Unhide before constructing: the renderer sizes itself from the canvas's
  // client box, which is 0 while `hidden` applies `display: none`.
  canvas.classList.remove("hidden");

  let ring;
  try {
    ring = new ShardRing(canvas, root);
  } catch (error) {
    // A lost/blocked WebGL context shouldn't take the page down with it.
    console.error("[shards] failed to initialise", error);
    showFallback(root);
    return;
  }

  const still = prefersReducedMotion();
  const state = { ring, observer: null, onVisibility: null, still };
  MOUNTED.set(root, state);

  const resume = () => {
    if (state.still) {
      ring.renderStill();
    } else if (!document.hidden) {
      ring.start();
    }
  };

  // Only burn GPU while the ring is actually on screen and the tab is visible.
  if ("IntersectionObserver" in window) {
    state.observer = new IntersectionObserver(
      (entries) => {
        const visible = entries.some((entry) => entry.isIntersecting);
        state.visible = visible;
        if (visible) resume();
        else ring.stop();
      },
      { threshold: 0.05 },
    );
    state.observer.observe(root);
  } else {
    state.visible = true;
    resume();
  }

  state.onVisibility = () => {
    if (document.hidden) ring.stop();
    else if (state.visible !== false) resume();
  };
  document.addEventListener("visibilitychange", state.onVisibility);
}

function unmount(root) {
  const state = MOUNTED.get(root);
  if (!state) return;

  if (state.observer) state.observer.disconnect();
  if (state.onVisibility) document.removeEventListener("visibilitychange", state.onVisibility);
  state.ring.dispose();
  MOUNTED.delete(root);
}

function mountAll() {
  document.querySelectorAll("[data-qul-shards]").forEach(mount);
}

function unmountAll() {
  document.querySelectorAll("[data-qul-shards]").forEach(unmount);
}

// Turbo re-executes body scripts on every visit, so only wire the document
// listeners once; subsequent executions just mount whatever is on the new page.
if (!window.__qulShardsInstalled) {
  window.__qulShardsInstalled = true;
  document.addEventListener("turbo:load", mountAll);
  // Tear the WebGL context down before Turbo caches the page; turbo:load remounts.
  document.addEventListener("turbo:before-cache", unmountAll);
}

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", mountAll, { once: true });
} else {
  mountAll();
}
