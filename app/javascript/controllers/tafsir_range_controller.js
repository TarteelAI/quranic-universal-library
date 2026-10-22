import { Controller } from "@hotwired/stimulus";

// Reloads the before/after picture of a tafsir's ayah range when the first
// or last ayah changes
export default class extends Controller {
  static targets = ["start", "end", "frame"];
  static values = { url: String };

  refresh() {
    const url = new URL(this.urlValue, window.location.origin);
    url.searchParams.set("start_verse_id", this.startTarget.value);
    url.searchParams.set("end_verse_id", this.endTarget.value);
    this.frameTarget.src = url.toString();
  }
}
