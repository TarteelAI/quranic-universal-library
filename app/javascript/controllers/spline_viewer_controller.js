import { Controller } from "@hotwired/stimulus";

// Renders the landing hero background. Originally a heavy <spline-viewer> WebGL
// scene; now a lazy-loaded autoplaying video. The video keeps a subtle
// mouse-follow tilt (via a CSS 3D transform) to echo the interactivity the
// Spline scene had, while being far cheaper to render.
export default class extends Controller {
  static targets = ["fallback", "container", "video"];

  static values = {
    maxTilt: { type: Number, default: 14 },
    restScale: { type: Number, default: 0.92 },
    hoverScale: { type: Number, default: 0.82 },
    // When disabled (default), the video is used on every screen size. Enable
    // to fall back to the static image on small screens instead.
    fallback: { type: Boolean, default: false },
  };

  connect() {
    this.loaded = false;
    this.tiltEnabled = false;
    this.observer = null;
    this.frame = null;
    this.pendingTilt = { nx: 0, ny: 0 };

    this.boundHandleResize = this.handleResize.bind(this);
    this.boundBeforeCache = this.teardown.bind(this);
    this.boundPointerMove = this.handlePointerMove.bind(this);
    this.boundResetTilt = this.resetTilt.bind(this);

    if (this.shouldUseFallback()) {
      this.showFallback();
    } else {
      this.lazyLoadVideo();
      this.enableTilt();
    }

    window.addEventListener("resize", this.boundHandleResize);

    // Pause/clean up before Turbo snapshots the page so the cached snapshot
    // isn't restored mid-playback. We rebuild on reconnect.
    document.addEventListener("turbo:before-cache", this.boundBeforeCache);
  }

  disconnect() {
    window.removeEventListener("resize", this.boundHandleResize);
    document.removeEventListener("turbo:before-cache", this.boundBeforeCache);
    this.disableTilt();
    if (this.observer) {
      this.observer.disconnect();
      this.observer = null;
    }
  }

  isSmallScreen() {
    return window.innerWidth < 1024;
  }

  // Only fall back to the static image when the fallback setting is enabled
  // and we're on a small screen; otherwise the video plays everywhere.
  shouldUseFallback() {
    return this.fallbackValue && this.isSmallScreen();
  }

  showFallback() {
    if (this.hasFallbackTarget) {
      this.fallbackTarget.classList.remove("hidden");
    }
    if (this.hasContainerTarget) {
      this.containerTarget.classList.add("hidden");
    }
  }

  showVideo() {
    if (this.hasFallbackTarget) {
      this.fallbackTarget.classList.add("hidden");
    }
    if (this.hasContainerTarget) {
      this.containerTarget.classList.remove("hidden");
    }
  }

  lazyLoadVideo() {
    if (this.loaded) return;

    // The poster (same image as the fallback) shows immediately, so revealing
    // the container before the source loads is seamless.
    this.showVideo();

    if ("IntersectionObserver" in window) {
      this.observer = new IntersectionObserver(
        (entries) => {
          entries.forEach((entry) => {
            if (entry.isIntersecting) {
              this.loadVideo();
              this.observer.disconnect();
              this.observer = null;
            }
          });
        },
        { threshold: 0.1 },
      );
      this.observer.observe(this.containerTarget);
    } else {
      this.loadVideo();
    }
  }

  loadVideo() {
    this.loaded = true;
    if (!this.hasVideoTarget) return;

    const source = this.videoTarget.querySelector("source[data-src]");
    if (source && !source.src) {
      source.src = source.dataset.src;
      this.videoTarget.load();
    }

    this.playVideo();
  }

  playVideo() {
    if (!this.hasVideoTarget) return;
    const playback = this.videoTarget.play();
    // Autoplay can be rejected (e.g. low-power mode); the poster stays visible.
    if (playback && typeof playback.catch === "function") {
      playback.catch(() => {});
    }
  }

  // --- Mouse-follow tilt -----------------------------------------------------

  enableTilt() {
    if (this.tiltEnabled) return;
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;
    if (window.matchMedia("(hover: none)").matches) return;

    if (!this.hasContainerTarget) return;

    this.tiltEnabled = true;
    this.resetTilt();
    this.containerTarget.addEventListener("pointermove", this.boundPointerMove);
    this.containerTarget.addEventListener("pointerleave", this.boundResetTilt);
  }

  disableTilt() {
    if (!this.tiltEnabled) return;
    this.tiltEnabled = false;
    if (this.hasContainerTarget) {
      this.containerTarget.removeEventListener("pointermove", this.boundPointerMove);
      this.containerTarget.removeEventListener("pointerleave", this.boundResetTilt);
    }
    if (this.frame) {
      cancelAnimationFrame(this.frame);
      this.frame = null;
    }
    this.resetTilt();
  }

  handlePointerMove(event) {
    if (!this.hasContainerTarget) return;

    const rect = this.containerTarget.getBoundingClientRect();
    if (rect.width === 0 || rect.height === 0) return;

    const cx = rect.left + rect.width / 2;
    const cy = rect.top + rect.height / 2;
    // Normalized -1..1 distance from the container's center, clamped so the
    // tilt saturates when the pointer is far away (e.g. over the hero text).
    const nx = clamp((event.clientX - cx) / (rect.width / 2), -1, 1);
    const ny = clamp((event.clientY - cy) / (rect.height / 2), -1, 1);

    this.pendingTilt = { nx, ny };
    if (this.frame) return;
    this.frame = requestAnimationFrame(() => {
      this.frame = null;
      this.applyTilt(this.pendingTilt.nx, this.pendingTilt.ny);
    });
  }

  applyTilt(nx, ny) {
    if (!this.hasVideoTarget) return;
    const max = this.maxTiltValue;
    // Horizontal movement tilts a little harder than vertical so the
    // left/right follow reads clearly.
    const rotateY = nx * max * 1.3;
    const rotateX = -ny * max;
    this.videoTarget.style.transform =
      `rotateX(${rotateX.toFixed(2)}deg) rotateY(${rotateY.toFixed(2)}deg) scale(${this.hoverScaleValue})`;
  }

  resetTilt() {
    if (this.hasVideoTarget) {
      this.videoTarget.style.transform =
        `rotateX(0deg) rotateY(0deg) scale(${this.restScaleValue})`;
    }
  }

  // --- Lifecycle -------------------------------------------------------------

  // Pause and reset for the Turbo cache snapshot; connect() rebuilds it.
  teardown() {
    if (this.observer) {
      this.observer.disconnect();
      this.observer = null;
    }
    this.loaded = false;
    if (this.hasVideoTarget) {
      this.videoTarget.pause();
    }
    // Keep the video (with its poster) in the snapshot unless we'd genuinely
    // fall back; connect() reloads/replays on reconnect.
    if (this.shouldUseFallback()) {
      this.showFallback();
    }
  }

  handleResize() {
    if (this.shouldUseFallback()) {
      this.disableTilt();
      this.showFallback();
      if (this.hasVideoTarget) this.videoTarget.pause();
    } else {
      this.enableTilt();
      if (!this.loaded) {
        this.lazyLoadVideo();
      } else {
        this.showVideo();
        this.playVideo();
      }
    }
  }
}

function clamp(value, min, max) {
  return Math.max(min, Math.min(max, value));
}
