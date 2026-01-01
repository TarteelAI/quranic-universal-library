import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["header", "spacer"];
  static values = {
    offset: { type: Number, default: 40 },
    transparent: { type: Boolean, default: false }
  };

  connect() {
    this.isStuck = false;
    this.lastY = window.scrollY || 0;
    this.headerHeight = this.headerTarget.offsetHeight || 0;
    this.spacerTarget.style.height = `${this.headerHeight}px`;

    this.onScroll = this.onScroll.bind(this);
    this.onResize = this.onResize.bind(this);

    window.addEventListener("scroll", this.onScroll, { passive: true });
    window.addEventListener("resize", this.onResize, { passive: true });

    this.apply(window.scrollY || 0, true);
  }

  disconnect() {
    window.removeEventListener("scroll", this.onScroll);
    window.removeEventListener("resize", this.onResize);
  }

  onResize() {
    this.headerHeight = this.headerTarget.offsetHeight || 0;
    this.spacerTarget.style.height = `${this.headerHeight}px`;
    if (this.isStuck) this.showSpacer();
  }

  onScroll() {
    const y = window.scrollY || 0;
    this.apply(y, false);
    this.lastY = y;
  }

  apply(y, immediate) {
    const shouldStick = y > this.offsetValue;
    if (shouldStick === this.isStuck) return;
    this.isStuck = shouldStick;

    if (shouldStick) {
      this.showSpacer();
      this.headerTarget.classList.add("tw-fixed", "tw-top-0", "tw-start-0", "tw-w-full", "tw-z-50", "tw-shadow-lg");
      this.headerTarget.classList.add("tw-bg-white", "tw-backdrop-blur", "tw-border-b", "tw-border-black/10");
      this.headerTarget.style.transform = "translateY(-12px)";
      this.headerTarget.style.opacity = "0";
      if (immediate) {
        this.headerTarget.style.transform = "";
        this.headerTarget.style.opacity = "";
      } else {
        requestAnimationFrame(() => {
          this.headerTarget.style.transform = "translateY(0)";
          this.headerTarget.style.opacity = "1";
        });
        clearTimeout(this.clearStylesTimeout);
        this.clearStylesTimeout = setTimeout(() => {
          if (!this.isStuck) return;
          this.headerTarget.style.transform = "";
          this.headerTarget.style.opacity = "";
        }, 260);
      }
    } else {
      this.hideSpacer();
      this.headerTarget.classList.remove("tw-fixed", "tw-top-0", "tw-start-0", "tw-w-full", "tw-z-50", "tw-shadow-lg");
      this.headerTarget.classList.remove("tw-bg-white", "tw-backdrop-blur", "tw-border-b", "tw-border-black/10");
      clearTimeout(this.clearStylesTimeout);
      this.headerTarget.style.transform = "";
      this.headerTarget.style.opacity = "";
    }
  }

  showSpacer() {
    this.spacerTarget.classList.remove("tw-hidden");
  }

  hideSpacer() {
    this.spacerTarget.classList.add("tw-hidden");
  }
}


