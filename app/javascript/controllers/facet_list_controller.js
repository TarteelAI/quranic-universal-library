import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["items", "toggle"];
  static values = {
    collapsedLines: { type: Number, default: 2 }
  };

  connect() {
    this.expanded = false;
    this.boundMeasure = this.measure.bind(this);
    window.addEventListener("resize", this.boundMeasure);
    window.addEventListener("load", this.boundMeasure);
    this.scheduleMeasure();
  }

  disconnect() {
    window.removeEventListener("resize", this.boundMeasure);
    window.removeEventListener("load", this.boundMeasure);
  }

  toggle(event) {
    event.preventDefault();
    this.expanded = !this.expanded;
    this.applyState();
  }

  scheduleMeasure() {
    requestAnimationFrame(() => this.measure());
    setTimeout(() => this.measure(), 50);
    setTimeout(() => this.measure(), 250);
  }

  measure() {
    if (!this.hasItemsTarget || !this.hasToggleTarget) return;

    const children = Array.from(this.itemsTarget.children).filter(
      (element) => !element.classList.contains("tw-hidden")
    );

    if (children.length === 0) {
      this.resetCollapsedState();
      return;
    }

    const firstChildHeight = children[0].offsetHeight;
    const computedStyle = window.getComputedStyle(this.itemsTarget);
    const rowGap = parseFloat(computedStyle.rowGap || computedStyle.gap || "0");

    if (!firstChildHeight) {
      this.resetCollapsedState();
      return;
    }

    this.collapsedHeight = (firstChildHeight * this.collapsedLinesValue) + (rowGap * (this.collapsedLinesValue - 1));

    if (this.itemsTarget.scrollHeight <= this.collapsedHeight + 2) {
      this.resetCollapsedState();
      return;
    }

    this.toggleTarget.classList.remove("tw-hidden");
    this.applyState();
  }

  applyState() {
    if (!this.collapsedHeight) return;

    this.itemsTarget.style.overflow = "hidden";
    this.itemsTarget.style.maxHeight = this.expanded ? `${this.itemsTarget.scrollHeight}px` : `${this.collapsedHeight}px`;
    this.toggleTarget.textContent = this.expanded ? "Show less" : "Show more";
    this.toggleTarget.setAttribute("aria-expanded", String(this.expanded));
  }

  resetCollapsedState() {
    this.collapsedHeight = null;
    this.expanded = false;
    this.itemsTarget.style.maxHeight = "";
    this.itemsTarget.style.overflow = "";
    this.toggleTarget.classList.add("tw-hidden");
    this.toggleTarget.textContent = "Show more";
    this.toggleTarget.setAttribute("aria-expanded", "false");
  }
}
