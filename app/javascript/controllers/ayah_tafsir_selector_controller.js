import { Controller } from "@hotwired/stimulus";
import { getAyahModalPrefs, setAyahModalPrefs } from "../lib/ayah_modal_store";

export default class extends Controller {
  static targets = ["panel", "backdrop", "form"];

  connect() {
    const prefs = getAyahModalPrefs();
    if (prefs.tafsirPanelOpen) {
      this.backdropTarget.classList.remove("tw-hidden");
      this.backdropTarget.classList.add("tw-block");
      this.panelTarget.classList.remove("tw-hidden");
      this.panelTarget.classList.add("tw-flex");
    }
    if (prefs.tafsirIds && prefs.tafsirIds.length) {
      const current = this.currentTafsirIds();
      const desired = prefs.tafsirIds.map((x) => parseInt(x, 10)).filter((x) => Number.isInteger(x));
      if (!this.sameIds(current, desired)) {
        this.setTafsirIds(desired);
        if (this.formTarget) this.formTarget.requestSubmit();
      }
    }
  }

  open(e) {
    e.preventDefault();
    setAyahModalPrefs({ tafsirPanelOpen: true });
    this.backdropTarget.classList.remove("tw-hidden");
    this.backdropTarget.classList.add("tw-block");
    this.panelTarget.classList.remove("tw-hidden");
    this.panelTarget.classList.add("tw-flex");
  }

  close(e) {
    e.preventDefault();
    setAyahModalPrefs({ tafsirPanelOpen: false });
    this.panelTarget.classList.add("tw-hidden");
    this.panelTarget.classList.remove("tw-flex");
    this.backdropTarget.classList.add("tw-hidden");
    this.backdropTarget.classList.remove("tw-block");
  }

  change() {
    const ids = this.currentTafsirIds();
    setAyahModalPrefs({ tafsirIds: ids });
    if (this.formTarget) this.formTarget.requestSubmit();
  }

  currentTafsirIds() {
    if (!this.formTarget) return [];
    const inputs = this.formTarget.querySelectorAll('input[name="tafsir_ids[]"]:checked');
    return Array.from(inputs).map((i) => parseInt(i.value, 10)).filter((x) => Number.isInteger(x));
  }

  setTafsirIds(ids) {
    if (!this.formTarget) return;
    const set = new Set(ids.map((x) => x.toString()));
    const inputs = this.formTarget.querySelectorAll('input[name="tafsir_ids[]"]');
    inputs.forEach((i) => {
      i.checked = set.has(i.value);
    });
    setAyahModalPrefs({ tafsirIds: ids });
  }

  sameIds(a, b) {
    const as = [...new Set(a)].sort((x, y) => x - y);
    const bs = [...new Set(b)].sort((x, y) => x - y);
    if (as.length !== bs.length) return false;
    for (let i = 0; i < as.length; i++) {
      if (as[i] !== bs[i]) return false;
    }
    return true;
  }
}


