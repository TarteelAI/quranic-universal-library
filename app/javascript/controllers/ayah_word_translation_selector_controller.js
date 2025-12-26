import { Controller } from "@hotwired/stimulus";
import { getAyahModalPrefs, setAyahModalPrefs } from "../lib/ayah_modal_store";

export default class extends Controller {
  static targets = ["panel", "backdrop", "form"];

  connect() {
    const prefs = getAyahModalPrefs();
    if (Number.isInteger(prefs.wordTranslationId)) {
      const current = this.currentWordTranslationId();
      if (current !== prefs.wordTranslationId) {
        this.setWordTranslationId(prefs.wordTranslationId);
        if (this.formTarget) this.formTarget.requestSubmit();
      }
    }
  }

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
    const id = this.currentWordTranslationId();
    if (Number.isInteger(id)) setAyahModalPrefs({ wordTranslationId: id });
    if (this.formTarget) this.formTarget.requestSubmit();
  }

  currentWordTranslationId() {
    if (!this.formTarget) return null;
    const input = this.formTarget.querySelector('input[name="word_translation_id"]:checked');
    if (!input) return null;
    const v = parseInt(input.value, 10);
    return Number.isInteger(v) ? v : null;
  }

  setWordTranslationId(id) {
    if (!this.formTarget) return;
    const inputs = this.formTarget.querySelectorAll('input[name="word_translation_id"]');
    inputs.forEach((i) => {
      i.checked = parseInt(i.value, 10) === id;
    });
    setAyahModalPrefs({ wordTranslationId: id });
  }
}


