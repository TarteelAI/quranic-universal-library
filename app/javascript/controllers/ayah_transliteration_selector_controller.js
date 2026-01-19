import { Controller } from "@hotwired/stimulus";
import { getAyahModalPrefs, setAyahModalPrefs } from "../lib/ayah_modal_store";

export default class extends Controller {
  static targets = ["panel", "backdrop", "form"];

  connect() {
    const prefs = getAyahModalPrefs();
    if (prefs.transliterationPanelOpen) {
      this.backdropTarget.classList.remove("tw-hidden");
      this.backdropTarget.classList.add("tw-block");
      this.panelTarget.classList.remove("tw-hidden");
      this.panelTarget.classList.add("tw-flex");
    }
    if (Number.isInteger(prefs.transliterationId)) {
      const current = this.currentTransliterationId();
      if (current !== prefs.transliterationId) {
        this.setTransliterationId(prefs.transliterationId);
        if (this.formTarget) this.formTarget.requestSubmit();
      }
    }
  }

  open(e) {
    e.preventDefault();
    setAyahModalPrefs({ transliterationPanelOpen: true });
    this.backdropTarget.classList.remove("tw-hidden");
    this.backdropTarget.classList.add("tw-block");
    this.panelTarget.classList.remove("tw-hidden");
    this.panelTarget.classList.add("tw-flex");
  }

  close(e) {
    e.preventDefault();
    setAyahModalPrefs({ transliterationPanelOpen: false });
    this.panelTarget.classList.add("tw-hidden");
    this.panelTarget.classList.remove("tw-flex");
    this.backdropTarget.classList.add("tw-hidden");
    this.backdropTarget.classList.remove("tw-block");
  }

  change() {
    const id = this.currentTransliterationId();
    if (Number.isInteger(id)) setAyahModalPrefs({ transliterationId: id });
    if (this.formTarget) this.formTarget.requestSubmit();
  }

  currentTransliterationId() {
    if (!this.formTarget) return null;
    const input = this.formTarget.querySelector('input[name="transliteration_id"]:checked');
    if (!input) return null;
    const v = parseInt(input.value, 10);
    return Number.isInteger(v) ? v : null;
  }

  setTransliterationId(id) {
    if (!this.formTarget) return;
    const inputs = this.formTarget.querySelectorAll('input[name="transliteration_id"]');
    inputs.forEach((i) => {
      i.checked = parseInt(i.value, 10) === id;
    });
    setAyahModalPrefs({ transliterationId: id });
  }
}


