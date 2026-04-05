import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["fallback", "container", "viewer"];

  connect() {
    this.loaded = false;
    this.observer = null;

    if (this.isSmallScreen()) {
      this.showFallback();
    } else {
      this.lazyLoadSpline();
    }

    window.addEventListener("resize", this.handleResize.bind(this));
  }

  disconnect() {
    window.removeEventListener("resize", this.handleResize.bind(this));
    if (this.observer) {
      this.observer.disconnect();
    }
  }

  isSmallScreen() {
    return window.innerWidth < 1024;
  }

  showFallback() {
    if (this.hasFallbackTarget) {
      this.fallbackTarget.classList.remove("tw-hidden");
    }
    if (this.hasContainerTarget) {
      this.containerTarget.classList.add("tw-hidden");
    }
  }

  showSpline() {
    if (this.hasFallbackTarget) {
      this.fallbackTarget.classList.add("tw-hidden");
    }
    if (this.hasContainerTarget) {
      this.containerTarget.classList.remove("tw-hidden");
    }
  }

  lazyLoadSpline() {
    if (this.loaded) return;

    if ("IntersectionObserver" in window) {
      this.observer = new IntersectionObserver(
        (entries) => {
          entries.forEach((entry) => {
            if (entry.isIntersecting) {
              this.loadSpline();
              this.observer.disconnect();
            }
          });
        },
        { threshold: 0.1 },
      );
      this.observer.observe(this.containerTarget);
    } else {
      this.loadSpline();
    }
  }

  loadSpline() {
    this.loaded = true;
    this.showSpline();

    if (!window.customElements.get("spline-viewer")) {
      const script = document.createElement("script");
      script.type = "module";
      script.src =
        "https://unpkg.com/@splinetool/viewer/build/spline-viewer.js";
      document.head.appendChild(script);
    }
  }

  handleResize() {
    if (this.isSmallScreen()) {
      this.showFallback();
    } else if (!this.loaded) {
      this.lazyLoadSpline();
    } else {
      this.showSpline();
    }
  }
}
