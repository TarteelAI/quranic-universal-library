import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["panel", "backdrop", "form"];

  open(e) {
    e.preventDefault();
    this.backdropTarget.classList.remove("tw-hidden");
    this.backdropTarget.classList.add("tw-block");
    this.panelTarget.classList.remove("tw-hidden");
    this.panelTarget.classList.add("tw-flex");
  }

  close(e) {
    e.preventDefault();
    this.panelTarget.classList.add("tw-hidden");
    this.panelTarget.classList.remove("tw-flex");
    this.backdropTarget.classList.add("tw-hidden");
    this.backdropTarget.classList.remove("tw-block");
  }

  change() {
    if (this.formTarget) this.formTarget.requestSubmit();
    this.panelTarget.classList.add("tw-hidden");
    this.panelTarget.classList.remove("tw-flex");
    this.backdropTarget.classList.add("tw-hidden");
    this.backdropTarget.classList.remove("tw-block");
  }
}


