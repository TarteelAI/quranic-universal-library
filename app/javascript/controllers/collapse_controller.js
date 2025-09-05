import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["collapsible"];

  connect() {
    // Initialize collapsed state
    this.collapsed = true;
  }

  toggle(event) {
    event.preventDefault();

    const targetSelector = event.currentTarget.dataset.collapseTargetParam;
    const target = targetSelector
      ? document.querySelector(targetSelector)
      : this.collapsibleTarget;

    if (!target) return;

    if (this.collapsed) {
      this.show(target);
    } else {
      this.hide(target);
    }

    this.collapsed = !this.collapsed;

    // Update aria-expanded attribute
    const button = event.currentTarget;
    button.setAttribute("aria-expanded", !this.collapsed);
  }

  show(target) {
    target.classList.remove("collapse");
    target.classList.add("collapse", "show");
  }

  hide(target) {
    target.classList.remove("show");
    target.classList.add("collapse");
  }
}
