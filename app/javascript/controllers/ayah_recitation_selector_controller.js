import { Controller } from "@hotwired/stimulus";
import { getAyahModalPrefs, setAyahModalPrefs } from "../lib/ayah_modal_store";

export default class extends Controller {
  static targets = ["panel", "backdrop", "form"];

  connect() {
    const prefs = getAyahModalPrefs();
    if (prefs.recitationPanelOpen) {
      this.backdropTarget.classList.remove("tw-hidden");
      this.backdropTarget.classList.add("tw-block");
      this.panelTarget.classList.remove("tw-hidden");
      this.panelTarget.classList.add("tw-flex");
    }
    if (Number.isInteger(prefs.recitationResourceId)) {
      const current = this.currentRecitationResourceId();
      if (current !== prefs.recitationResourceId) {
        this.setRecitationResourceId(prefs.recitationResourceId);
        if (this.formTarget) this.formTarget.requestSubmit();
      }
    }
  }

  open(e) {
    e.preventDefault();
    setAyahModalPrefs({ recitationPanelOpen: true });
    this.backdropTarget.classList.remove("tw-hidden");
    this.backdropTarget.classList.add("tw-block");
    this.panelTarget.classList.remove("tw-hidden");
    this.panelTarget.classList.add("tw-flex");
  }

  close(e) {
    e.preventDefault();
    setAyahModalPrefs({ recitationPanelOpen: false });
    this.panelTarget.classList.add("tw-hidden");
    this.panelTarget.classList.remove("tw-flex");
    this.backdropTarget.classList.add("tw-hidden");
    this.backdropTarget.classList.remove("tw-block");
  }

  change() {
    const id = this.currentRecitationResourceId();
    if (Number.isInteger(id)) setAyahModalPrefs({ recitationResourceId: id });
    if (this.formTarget) this.formTarget.requestSubmit();
  }

  currentRecitationResourceId() {
    if (!this.formTarget) return null;
    const input = this.formTarget.querySelector('input[name="recitation_resource_id"]:checked');
    if (!input) return null;
    const v = parseInt(input.value, 10);
    return Number.isInteger(v) ? v : null;
  }

  setRecitationResourceId(id) {
    if (!this.formTarget) return;
    const inputs = this.formTarget.querySelectorAll('input[name="recitation_resource_id"]');
    inputs.forEach((i) => {
      i.checked = parseInt(i.value, 10) === id;
    });
    setAyahModalPrefs({ recitationResourceId: id });
  }
}


