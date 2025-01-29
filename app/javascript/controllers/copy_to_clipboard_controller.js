import { Controller } from "@hotwired/stimulus";
import copyToClipboard from "copy-to-clipboard";

export default class extends Controller {
  connect() {
    this.$el = $(this.element);
    this.$el.attr("title", "Copy").tooltip();
    this.$el.on("click", this.copy);
  }

  disconnect() {
    this.$el.off("click", this.copy);
    this.$el.tooltip("dispose");
  }

  copy = () => {
    const text = this.$el.data("text") || this.$el.text().trim();
    copyToClipboard(text);

    this.$el.attr("title", "Copied").tooltip("_fixTitle").tooltip("show");

    setTimeout(() => {
      this.$el.attr("title", "Copy").tooltip("_fixTitle");
    }, 1500);
  };
}
