import { Controller } from "@hotwired/stimulus";
import copyToClipboard from "copy-to-clipboard";
import toastr from "toastr";

toastr.options = {
  closeButton: true,
  debug: false,
  newestOnTop: true,
  progressBar: true,
  positionClass: "toast-top-right",
  preventDuplicates: true,
  onclick: null,
  showDuration: 300,
  hideDuration: 100,
  timeOut: 5000,
  extendedTimeOut: 0,
  showEasing: "swing",
  hideEasing: "linear",
  showMethod: "fadeIn",
  hideMethod: "fadeOut",
  tapToDismiss: true
};

export default class extends Controller {
  copy = (event) => {
    const isolate = this.element.dataset.stopPropagation !== undefined;

    if (isolate) {
      if (event.button !== 0) return;
      if (event.ctrlKey || event.metaKey || event.shiftKey || event.altKey) return;
      event.preventDefault();
      event.stopPropagation();
    }

    const text =
      this.element.dataset.text ||
      this.element.textContent.trim();

    copyToClipboard(text);

    const toastMessage = this.element.dataset.toastMessage;
    if (toastMessage) {
      toastr.success(toastMessage);
    } else {
      this.element.dispatchEvent(
        new CustomEvent("tooltip:update", {
          detail: {
            text: "Copied",
            temporary: true
          }
        })
      );
    }
  };

  connect() {
    this.element.addEventListener("click", this.copy);
  }

  disconnect() {
    this.element.removeEventListener("click", this.copy);
  }
}
