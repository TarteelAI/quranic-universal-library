import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["fallback", "container", "mount", "template"];

  connect() {
    this.loaded = false;
    this.observer = null;
    this.boundHandleResize = this.handleResize.bind(this);
    this.boundBeforeCache = this.teardown.bind(this);

    if (this.isSmallScreen()) {
      this.showFallback();
    } else {
      this.lazyLoadSpline();
    }

    window.addEventListener("resize", this.boundHandleResize);

    // Turbo snapshots the page into its cache on navigation. A live <spline-viewer>
    // restored from that snapshot re-initializes its WebGL canvas and throws
    // "Canvas has an existing context of a different type" (issue #448), so tear the
    // viewer down before the snapshot is taken and rebuild it when we reconnect.
    document.addEventListener("turbo:before-cache", this.boundBeforeCache);
  }

  disconnect() {
    window.removeEventListener("resize", this.boundHandleResize);
    document.removeEventListener("turbo:before-cache", this.boundBeforeCache);
    if (this.observer) {
      this.observer.disconnect();
      this.observer = null;
    }
  }

  isSmallScreen() {
    return window.innerWidth < 1024;
  }

  showFallback() {
    if (this.hasFallbackTarget) {
      this.fallbackTarget.classList.remove("hidden");
    }
    if (this.hasContainerTarget) {
      this.containerTarget.classList.add("hidden");
    }
  }

  showSpline() {
    if (this.hasFallbackTarget) {
      this.fallbackTarget.classList.add("hidden");
    }
    if (this.hasContainerTarget) {
      this.containerTarget.classList.remove("hidden");
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
    this.renderViewer();

    if (!window.customElements.get("spline-viewer")) {
      const script = document.createElement("script");
      script.type = "module";
      script.src =
        "https://unpkg.com/@splinetool/viewer/build/spline-viewer.js";
      document.head.appendChild(script);
    }
  }

  // Build the <spline-viewer> from its template into the mount point.
  renderViewer() {
    if (!this.hasMountTarget || !this.hasTemplateTarget) return;
    if (this.mountTarget.querySelector("spline-viewer")) return;

    this.mountTarget.appendChild(this.templateTarget.content.cloneNode(true));
  }

  // Remove the live viewer (and its WebGL canvas) so it is not restored from the Turbo cache.
  teardown() {
    if (this.observer) {
      this.observer.disconnect();
      this.observer = null;
    }
    this.loaded = false;

    if (this.hasMountTarget) {
      this.mountTarget.replaceChildren();
    }

    this.showFallback();
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
