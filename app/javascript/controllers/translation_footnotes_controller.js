import { Controller } from "@hotwired/stimulus";

// Footnotes in the translation proofreading form. The text links a footnote
// with {{n}}, and each footnote has a box with its text.
//
// - Add footnote puts the next {{n}} at the cursor and adds its box
// - Remove takes the box and its {{n}} out
// - Typing a {{n}} that has no box adds one, a box whose {{n}} is gone is flagged
export default class extends Controller {
  static targets = ["text", "list", "template", "empty"];

  connect() {
    this.cursorMoved = false;
    this.refresh();
  }

  // Before the user clicks into the text, a new footnote goes at the end
  track() {
    this.cursorMoved = true;
  }

  add() {
    const key = this.nextKey();
    const marker = `{{${key}}}`;
    const textarea = this.textTarget;
    const at = this.cursorMoved ? textarea.selectionEnd : textarea.value.length;
    // A footnote follows the word before it: "worlds {{2}} and"
    const before = textarea.value.slice(0, at).trimEnd();
    const after = textarea.value.slice(at);
    const spacer = after && !/^\s/.test(after) ? " " : "";

    textarea.value = `${before}${before ? " " : ""}${marker}${spacer}${after}`;
    const box = this.addBox(key);
    this.refresh();
    box.querySelector("textarea").focus();
  }

  remove(event) {
    const box = event.target.closest("[data-key]");
    const pattern = new RegExp(`\\s*\\{\\{\\s*${box.dataset.key}\\s*\\}\\}`, "g");

    this.textTarget.value = this.textTarget.value.replace(pattern, "");
    box.remove();
    this.refresh();
  }

  refresh() {
    const keys = this.markerKeys();

    keys.forEach((key) => {
      if (!this.box(key)) this.addBox(key);
    });

    this.boxes().forEach((box) => {
      const used = keys.includes(box.dataset.key);
      box.querySelector("[data-unused]").classList.toggle("hidden", used);
      box.classList.toggle("border-amber-400", !used);
    });

    this.emptyTarget.classList.toggle("hidden", this.boxes().length > 0);
  }

  addBox(key) {
    const html = this.templateTarget.innerHTML.replace(/KEY/g, key);
    this.listTarget.insertAdjacentHTML("beforeend", html);
    return this.box(key);
  }

  markerKeys() {
    return [...this.textTarget.value.matchAll(/\{\{\s*(\d+)\s*\}\}/g)].map((match) => match[1]);
  }

  nextKey() {
    const keys = [...this.markerKeys(), ...this.boxes().map((box) => box.dataset.key)].map(Number);
    return keys.length ? Math.max(...keys) + 1 : 1;
  }

  boxes() {
    return [...this.listTarget.querySelectorAll("[data-key]")];
  }

  box(key) {
    return this.listTarget.querySelector(`[data-key="${key}"]`);
  }
}
