import {Controller} from "@hotwired/stimulus";

export default class extends Controller {
  static values = {
    url: String,
    width: Number,
    height: Number,
    viewerClass: String,
  }

  connect() {
    this.mounted = false;

    if (!window.matchMedia("(min-width: 1024px)").matches) return;
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;

    this.observer = new IntersectionObserver(
      (entries) => {
        if (entries.some((e) => e.isIntersecting)) {
          this.mount();
          this.observer?.disconnect();
          this.observer = null;
        }
      },
      { root: null, rootMargin: "200px", threshold: 0.01 }
    );

    this.observer.observe(this.element);
  }

  disconnect() {
    this.observer?.disconnect();
    this.observer = null;
  }

  async mount() {
    if (this.mounted) return;
    this.mounted = true;

    await this.loadViewer();

    const el = document.createElement("spline-viewer");
    el.setAttribute("url", this.urlValue);

    if (this.hasWidthValue) el.setAttribute("width", String(this.widthValue));
    if (this.hasHeightValue) el.setAttribute("height", String(this.heightValue));
    if (this.hasViewerClassValue && this.viewerClassValue) el.setAttribute("class", this.viewerClassValue);

    this.element.replaceChildren(el);
  }

  loadViewer() {
    if (!window.__qulSplineViewerLoadPromise) {
      window.__qulSplineViewerLoadPromise = new Promise((resolve, reject) => {
        const script = document.createElement("script");
        script.type = "module";
        script.src = "https://unpkg.com/@splinetool/viewer/build/spline-viewer.js";
        script.async = true;
        script.defer = true;
        script.onload = resolve;
        script.onerror = reject;
        document.head.appendChild(script);
      });
    }

    return window.__qulSplineViewerLoadPromise;
  }
}