import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  close() {
    this.element.style.transition = "opacity 300ms";
    this.element.style.opacity = "0";

    // Remove from DOM after animation completes
    setTimeout(() => {
      this.element.remove();
    }, 300);
  }
}
