import { Controller } from "@hotwired/stimulus";
import copyToClipboard from "copy-to-clipboard";

export default class extends Controller {
  copy = () => {
    const text =
      this.element.dataset.text ||
      this.element.textContent.trim();

    copyToClipboard(text);

    this.element.dispatchEvent(
      new CustomEvent("tooltip:update", {
        detail: {
          text: "Copied",
          temporary: true
        }
      })
    );
  };

  connect() {
    this.element.addEventListener("click", this.copy);
  }

  disconnect() {
    this.element.removeEventListener("click", this.copy);
  }
}