import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["panel", "select"];
  static values = { tab: String };

  connect() {
    this.outsideClick = (e) => {
      if (!this.element.contains(e.target)) this.hide();
    };
    document.addEventListener("click", this.outsideClick);
  }

  disconnect() {
    document.removeEventListener("click", this.outsideClick);
  }

  toggle(e) {
    e.preventDefault();
    e.stopPropagation();
    if (this.panelTarget.classList.contains("tw-hidden")) {
      this.show();
    } else {
      this.hide();
    }
  }

  show() {
    this.panelTarget.classList.remove("tw-hidden");
  }

  hide() {
    this.panelTarget.classList.add("tw-hidden");
  }

  jump(e) {
    e.preventDefault();
    const key = this.selectTarget.value;
    if (!key) return;

    const tab = this.tabValue || "ayah";
    const url = `/ayah/${key}?tab=${encodeURIComponent(tab)}`;

    if (window.Turbo && Turbo.visit) {
      Turbo.visit(url, { frame: "ayah_info" });
    } else {
      window.location.href = url;
    }

    this.hide();
  }
}


