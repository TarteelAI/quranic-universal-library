import { Controller } from "@hotwired/stimulus";
import { getAyahModalPrefs, setAyahModalPrefs } from "../lib/ayah_modal_store";

export default class extends Controller {
  static targets = ["panel", "backdrop", "form"];

  connect() {
    const prefs = getAyahModalPrefs();
    if (prefs.script) {
      const current = this.currentScript();
      if (current !== prefs.script) {
        this.setScript(prefs.script);
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
    const script = this.currentScript();
    if (script) setAyahModalPrefs({ script });
    if (this.formTarget) this.formTarget.requestSubmit();
  }

  currentScript() {
    if (!this.formTarget) return null;
    const input = this.formTarget.querySelector('input[name="script"]:checked');
    return input ? input.value : null;
  }

  setScript(value) {
    if (!this.formTarget) return;
    const inputs = this.formTarget.querySelectorAll('input[name="script"]');
    inputs.forEach((i) => {
      i.checked = i.value === value;
    });
    setAyahModalPrefs({ script: value });
  }
}


